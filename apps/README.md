# Demo applications

Two intentionally instrumented microservices that exercise every pillar of the platform.

```
       ┌───────────────┐   HTTP    ┌───────────────┐
load → │ demo-shop-api │ ───────▶  │ demo-blog-web │
       │    (Go)       │           │  (Node.js)    │
       └───────┬───────┘           └───────┬───────┘
               │ OTLP                       │ OTLP
               └────────────┬───────────────┘
                            ▼
                 alloy.observability.svc:4317
```

## Services

| Service | Language | Port | What it does | Instrumentation |
|---|---|---|---|---|
| `demo-shop-api` | Go 1.22 | 8080 | Product catalog + order endpoint | otel-go SDK (metrics/traces/logs) + net/http/pprof |
| `demo-blog-web` | Node.js 20 | 3000 | Product blog posts / reviews | @opentelemetry/api + @pyroscope/nodejs |
| `load-generator` | k6 | — | Hits `demo-shop-api` on a loop | k6 native metrics via Prometheus |

`demo-shop-api` fans out to `demo-blog-web` on the product-detail path — this creates a cross-service trace with two spans.

## Signals produced

- **Metrics**: HTTP request rate/latency (histogram), in-flight requests, cache hit ratio, Go GC stats
- **Logs**: structured JSON with `trace_id` field for trace↔log correlation
- **Traces**: OTLP spans, propagated between services via W3C traceparent header
- **Profiles**: CPU + heap + goroutines, sampled at 100Hz

## Tenant

By default, demo apps ship to tenant `_default`. To send them to a real tenant instead:

```bash
# Onboard a tenant first
./scripts/onboard-tenant.sh demo

# Redeploy apps pointing at the tenant
DEMO_TENANT=demo make local-demo
```

## Building locally

```bash
make -C apps/demo-shop-api build
make -C apps/demo-blog-web build
```

Images tagged as `demo-shop-api:local` / `demo-blog-web:local`. `make local-demo` loads them into the kind cluster automatically.

## Deploying

```bash
kubectl apply -k apps/
```

The Kustomize entrypoint creates the `_default` namespace and deploys all three components.
