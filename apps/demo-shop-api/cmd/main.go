package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	_ "net/http/pprof" // exposes /debug/pprof for Pyroscope scrape
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/grafana/pyroscope-go"

	"github.com/umars28/observability-platform/apps/demo-shop-api/internal/client"
	"github.com/umars28/observability-platform/apps/demo-shop-api/internal/server"
	"github.com/umars28/observability-platform/apps/demo-shop-api/internal/telemetry"
)

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	cfg := loadConfig()
	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo}))
	slog.SetDefault(logger)

	// OpenTelemetry setup — metrics, traces, logs via OTLP to Alloy.
	shutdownOtel, err := telemetry.Setup(ctx, cfg.ServiceName, cfg.OTLPEndpoint, cfg.Tenant)
	if err != nil {
		logger.Error("otel setup failed", "err", err)
		os.Exit(1)
	}
	defer func() { _ = shutdownOtel(context.Background()) }()

	// Pyroscope — push profiles to platform.
	if cfg.PyroscopeEndpoint != "" {
		_, err = pyroscope.Start(pyroscope.Config{
			ApplicationName: cfg.ServiceName,
			ServerAddress:   cfg.PyroscopeEndpoint,
			TenantID:        cfg.Tenant,
			Logger:          nil,
			Tags:            map[string]string{"env": cfg.Environment},
			ProfileTypes: []pyroscope.ProfileType{
				pyroscope.ProfileCPU,
				pyroscope.ProfileAllocObjects,
				pyroscope.ProfileAllocSpace,
				pyroscope.ProfileInuseObjects,
				pyroscope.ProfileInuseSpace,
				pyroscope.ProfileGoroutines,
			},
		})
		if err != nil {
			logger.Warn("pyroscope start failed (continuing without profiles)", "err", err)
		}
	}

	// pprof endpoint for Alloy scrape mode (if push mode unavailable).
	go func() {
		_ = http.ListenAndServe(":6060", nil)
	}()

	blogClient := client.NewBlogClient(cfg.BlogWebURL)
	srv := server.New(cfg.ListenAddr, cfg.ServiceName, blogClient, logger)

	logger.Info("demo-shop-api starting",
		"listen", cfg.ListenAddr,
		"blog_upstream", cfg.BlogWebURL,
		"otlp", cfg.OTLPEndpoint,
		"tenant", cfg.Tenant,
	)

	errCh := make(chan error, 1)
	go func() { errCh <- srv.Run() }()

	select {
	case err := <-errCh:
		if err != nil && !errors.Is(err, http.ErrServerClosed) {
			logger.Error("server exited with error", "err", err)
			os.Exit(1)
		}
	case <-ctx.Done():
		logger.Info("shutdown signal received")
		shutCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		if err := srv.Shutdown(shutCtx); err != nil {
			logger.Warn("graceful shutdown returned error", "err", err)
		}
	}

	logger.Info("demo-shop-api stopped")
}

type config struct {
	ServiceName       string
	ListenAddr        string
	OTLPEndpoint      string
	PyroscopeEndpoint string
	BlogWebURL        string
	Tenant            string
	Environment       string
}

func loadConfig() config {
	return config{
		ServiceName:       getenv("OTEL_SERVICE_NAME", "demo-shop-api"),
		ListenAddr:        getenv("LISTEN_ADDR", ":8080"),
		OTLPEndpoint:      getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "alloy.observability.svc:4317"),
		PyroscopeEndpoint: getenv("PYROSCOPE_ENDPOINT", "http://pyroscope.observability.svc:4040"),
		BlogWebURL:        getenv("BLOG_WEB_URL", "http://demo-blog-web.demo.svc:3000"),
		Tenant:            getenv("TENANT", "_default"),
		Environment:       getenv("APP_ENV", "local"),
	}
}

func getenv(k, def string) string {
	if v, ok := os.LookupEnv(k); ok && v != "" {
		return v
	}
	return def
}
