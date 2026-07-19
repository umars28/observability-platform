// Package server exposes the shop HTTP API with OTel middleware.
package server

import (
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"strconv"
	"time"

	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/metric"
	"go.opentelemetry.io/otel/trace"

	"github.com/umars28/observability-platform/apps/demo-shop-api/internal/catalog"
	"github.com/umars28/observability-platform/apps/demo-shop-api/internal/client"
)

type BlogClient interface {
	PostsFor(ctx context.Context, productID string) ([]client.BlogPost, error)
}

type Server struct {
	http    *http.Server
	catalog *catalog.Store
	blog    BlogClient
	log     *slog.Logger
	tracer  trace.Tracer
	// metrics
	requests metric.Int64Counter
	latency  metric.Float64Histogram
}

func New(addr, serviceName string, blog BlogClient, logger *slog.Logger) *Server {
	meter := otel.Meter(serviceName)
	tracer := otel.Tracer(serviceName)

	reqs, _ := meter.Int64Counter("http_requests_total",
		metric.WithDescription("HTTP requests received"),
	)
	lat, _ := meter.Float64Histogram("http_request_duration_seconds",
		metric.WithDescription("HTTP request duration in seconds"),
		metric.WithUnit("s"),
	)

	s := &Server{
		catalog:  catalog.NewStore(),
		blog:     blog,
		log:      logger,
		tracer:   tracer,
		requests: reqs,
		latency:  lat,
	}
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", s.health)
	mux.HandleFunc("GET /products", s.wrap("list_products", s.listProducts))
	mux.HandleFunc("GET /products/{id}", s.wrap("get_product", s.getProduct))
	mux.HandleFunc("POST /orders", s.wrap("create_order", s.createOrder))

	// otelhttp captures each request as a span + adds baseline metrics.
	handler := otelhttp.NewHandler(mux, "http.server",
		otelhttp.WithSpanNameFormatter(func(_ string, r *http.Request) string {
			return r.Method + " " + r.URL.Path
		}),
	)

	s.http = &http.Server{
		Addr:              addr,
		Handler:           handler,
		ReadHeaderTimeout: 5 * time.Second,
	}
	return s
}

func (s *Server) Run() error {
	return s.http.ListenAndServe()
}

func (s *Server) Shutdown(ctx context.Context) error {
	return s.http.Shutdown(ctx)
}

// ─── Middleware ─────────────────────────────────────────────────────────
type handlerFn func(w http.ResponseWriter, r *http.Request)

func (s *Server) wrap(name string, h handlerFn) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		rw := &statusRecorder{ResponseWriter: w, status: 200}
		h(rw, r)
		dur := time.Since(start).Seconds()

		attrs := []attribute.KeyValue{
			attribute.String("route", name),
			attribute.String("method", r.Method),
			attribute.String("status", strconv.Itoa(rw.status)),
		}
		s.requests.Add(r.Context(), 1, metric.WithAttributes(attrs...))
		s.latency.Record(r.Context(), dur, metric.WithAttributes(attrs...))

		span := trace.SpanFromContext(r.Context())
		if traceID := span.SpanContext().TraceID().String(); traceID != "" {
			s.log.InfoContext(r.Context(), "request",
				"route", name,
				"method", r.Method,
				"status", rw.status,
				"duration_ms", int(dur*1000),
				"trace_id", traceID,
			)
		}
	}
}

// ─── Handlers ───────────────────────────────────────────────────────────
func (s *Server) health(w http.ResponseWriter, _ *http.Request) {
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte("ok"))
}

func (s *Server) listProducts(w http.ResponseWriter, r *http.Request) {
	ctx, span := s.tracer.Start(r.Context(), "catalog.List")
	defer span.End()

	items, err := s.catalog.List(ctx)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, items)
}

func (s *Server) getProduct(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")

	ctx, span := s.tracer.Start(r.Context(), "catalog.Get",
		trace.WithAttributes(attribute.String("product.id", id)),
	)
	defer span.End()

	p, err := s.catalog.Get(ctx, id)
	if err != nil {
		if errors.Is(err, catalog.ErrNotFound) {
			writeErr(w, http.StatusNotFound, err)
			return
		}
		writeErr(w, http.StatusInternalServerError, err)
		return
	}

	// Enrich with blog posts — this creates a child span for the outgoing HTTP call.
	posts, err := s.blog.PostsFor(ctx, id)
	if err != nil {
		s.log.WarnContext(ctx, "blog enrichment failed", "err", err, "product_id", id)
		posts = []client.BlogPost{}
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"product": p,
		"posts":   posts,
	})
}

type orderRequest struct {
	ProductID string `json:"product_id"`
	Quantity  int    `json:"quantity"`
}

func (s *Server) createOrder(w http.ResponseWriter, r *http.Request) {
	var req orderRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeErr(w, http.StatusBadRequest, err)
		return
	}
	ctx, span := s.tracer.Start(r.Context(), "catalog.Order",
		trace.WithAttributes(
			attribute.String("product.id", req.ProductID),
			attribute.Int("order.quantity", req.Quantity),
		),
	)
	defer span.End()

	if err := s.catalog.Order(ctx, req.ProductID, req.Quantity); err != nil {
		if errors.Is(err, catalog.ErrNotFound) {
			writeErr(w, http.StatusNotFound, err)
			return
		}
		span.RecordError(err)
		writeErr(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"status": "ok", "product_id": req.ProductID, "quantity": req.Quantity})
}

// ─── Helpers ────────────────────────────────────────────────────────────
type statusRecorder struct {
	http.ResponseWriter
	status int
}

func (s *statusRecorder) WriteHeader(code int) {
	s.status = code
	s.ResponseWriter.WriteHeader(code)
}

func writeJSON(w http.ResponseWriter, code int, body any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	_ = json.NewEncoder(w).Encode(body)
}

func writeErr(w http.ResponseWriter, code int, err error) {
	writeJSON(w, code, map[string]string{"error": err.Error()})
}
