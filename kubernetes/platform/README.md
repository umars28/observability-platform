# Platform: LGTMP core

Helm values for the five observability components. Deployed by `scripts/platform-up.sh` after the bootstrap layer.

## Components

| Directory | Chart | Purpose |
|---|---|---|
| `mimir/`     | `grafana/mimir-distributed`     | Metrics store (Prometheus-compatible, S3-backed) |
| `loki/`      | `grafana/loki`                  | Logs store (LogQL, S3-backed) |
| `tempo/`     | `grafana/tempo`                 | Traces store (OTLP-compatible, S3-backed) |
| `pyroscope/` | `grafana/pyroscope`             | Continuous profiling |
| `grafana/`   | `grafana/grafana`               | Query UI, dashboard host |
| `alloy/`     | `grafana/alloy`                 | Node-level collector, OTLP receiver |

Each directory contains:

- `values.yaml` — shared defaults
- `values-local.yaml` — kind overrides (small resources, MinIO endpoint, no TLS)
- `values-live.yaml` — production overrides (R2/S3 endpoint, real domains, retention)

## Storage configuration

All components read the same environment variables for object storage:

| Variable | Meaning | Local (MinIO) | Live (Cloudflare R2 example) |
|---|---|---|---|
| `OBJECT_STORE_ENDPOINT` | S3 API endpoint URL | `http://minio.minio.svc:9000` | `https://<accountid>.r2.cloudflarestorage.com` |
| `OBJECT_STORE_REGION`   | Region name          | `us-east-1` (dummy) | `auto` (R2) or `us-east-1` (S3) |
| `OBJECT_STORE_ACCESS_KEY` | Access key ID     | `minio` | R2 access key |
| `OBJECT_STORE_SECRET_KEY` | Secret access key | `minio-local-secret` | R2 secret key |
| `OBJECT_STORE_BUCKET_MIMIR` | Bucket for Mimir | `mimir-metrics` | e.g. `obs-mimir-prod` |
| `OBJECT_STORE_BUCKET_LOKI`  | Bucket for Loki  | `loki-logs`     | e.g. `obs-loki-prod`  |
| `OBJECT_STORE_BUCKET_TEMPO` | Bucket for Tempo | `tempo-traces`  | e.g. `obs-tempo-prod` |
| `OBJECT_STORE_BUCKET_PYROSCOPE` | Bucket for Pyroscope | `pyroscope-profiles` | e.g. `obs-pyroscope-prod` |

Locally these come from `values-local.yaml` (plaintext). In production they come from a `Secret` sourced by external-secrets from your secret store.

## Deployment order

`platform-up.sh` deploys in this order:

1. Mimir (metrics arrive earliest during onboarding, needed by other components' self-monitoring)
2. Loki
3. Tempo
4. Pyroscope
5. Grafana (needs the four data sources reachable)
6. Alloy (needs the four receivers reachable)

Each `helm upgrade --install` waits for readiness before proceeding.

## Version pinning

Chart versions are pinned in `versions.yaml`. Bump one line, PR, deploy — no surprise upgrades.

## Multi-tenancy config

Every component here has multi-tenancy enabled. Onboarding a new tenant does NOT require redeploying platform components; it only adds a `Tenant` config (see `../tenants/`).
