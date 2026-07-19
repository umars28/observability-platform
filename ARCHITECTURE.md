# Architecture

This document describes the design of the observability platform: what it does, why the pieces exist, and where the boundaries are.

## Goals

1. **Four pillars, one platform.** Metrics, logs, traces, and continuous profiling, correlated in a single UI, backed by a single object store.
2. **Reusable across projects.** Onboard a new project by adding a directory; isolation via multi-tenancy is built in, not bolted on.
3. **Portable.** No cloud-specific APIs. Works on any Kubernetes ≥1.28. Any S3-compatible object storage.
4. **Cost-aware.** Object storage first; single-binary components in defaults; per-tenant quotas prevent noisy-neighbor blowups.
5. **Reproducible.** Anyone with the tools installed can `git clone && make local-up` and see the same platform.

## Non-goals

- Replacing per-app instrumentation SDKs. This platform stores and queries; it does not instrument your code.
- Being a SIEM. Security event correlation is out of scope.
- Supporting every possible storage backend. S3-compatible only. GCS via S3 interop; Azure Blob users can front with MinIO.
- Multi-cluster federation on day one. Single-cluster platform; federation is a future ADR.

## The four pillars

| Pillar | Component | Answers |
|---|---|---|
| Metrics | **Mimir** | *What is happening?* Rates, saturation, errors, latency percentiles. |
| Logs | **Loki** | *Why did it happen?* Contextual detail per event. |
| Traces | **Tempo** | *Where did it happen?* Which service, which call, which downstream. |
| Profiles | **Pyroscope** | *Which line of code caused it?* CPU / memory hotspots. |

All four are queried through **Grafana**. All four store data in the **same object bucket** (different prefixes). All four accept the `X-Scope-OrgID` header for tenant isolation.

## Data flow

```
┌──────────────────────────────────────────────────────────────┐
│                      Application Layer                        │
│                                                                │
│  ┌─────────────┐          ┌─────────────┐                     │
│  │ demo-shop   │  ◀───▶   │ demo-blog   │  ← OTel SDKs        │
│  │  (Go)       │  HTTP    │  (Node.js)  │                     │
│  └──────┬──────┘          └──────┬──────┘                     │
│         │ OTLP/gRPC              │ OTLP/gRPC                  │
└─────────┼────────────────────────┼─────────────────────────────┘
          │                        │
          └────────────┬───────────┘
                       ▼
       ┌───────────────────────────────┐
       │      Grafana Alloy            │  ← DaemonSet per node
       │  - receives OTLP              │    + tenant tagging
       │  - fans out per pillar        │    + basic transformation
       │  - adds X-Scope-OrgID         │
       └───┬────────┬────────┬─────┬───┘
           │        │        │     │
           ▼        ▼        ▼     ▼
      ┌────────┐┌──────┐┌───────┐┌──────────┐
      │ Mimir  ││ Loki ││ Tempo ││Pyroscope │
      │        ││      ││       ││          │
      │write:  ││ ..   ││  ..   ││   ..     │
      │ dist → ││      ││       ││          │
      │ ingest ││      ││       ││          │
      │read:   ││      ││       ││          │
      │ qfe →  ││      ││       ││          │
      │ query  ││      ││       ││          │
      └───┬────┘└──┬───┘└───┬───┘└────┬─────┘
          │       │        │         │
          └───────┴────┬───┴─────────┘
                       ▼
              ┌────────────────┐
              │ Object storage │  ← s3://<bucket>/<pillar>/<tenant>/…
              │ (S3/R2/MinIO)  │
              └────────────────┘
                       ▲
                       │ read
              ┌────────┴───────┐
              │    Grafana     │  ← single UI
              │ multi-tenant   │
              │ RBAC + folders │
              └────────────────┘
```

## Multi-tenancy model

**Soft multi-tenancy** using each component's built-in `X-Scope-OrgID` header. Every write and read carries a tenant ID. Storage is prefixed per tenant in the object bucket.

### How isolation works

- **Ingest**: Alloy attaches `X-Scope-OrgID: <tenant>` on every outgoing request to Mimir/Loki/Tempo/Pyroscope.
- **Storage**: Each component writes to `s3://<bucket>/<component>/<tenant>/…`. Deleting a tenant is a bucket prefix deletion.
- **Query**: Grafana datasources are configured per tenant, each with its own auth header. Users only see their tenant's data (or a superuser view via Grafana orgs).
- **Limits**: Per-tenant limits enforced at Mimir/Loki/Tempo config — ingestion rate, active series, max query length, retention.

### What tenant separation buys you

- One project can't fill up storage or blow up ingest for another.
- Retention can differ per tenant (e.g., production 90d, staging 7d).
- Deleting a project's data is a single bucket-prefix operation.
- Grafana dashboards and alerts can be scoped per tenant folder.

### What it does *not* buy you

- Query performance isolation. A very expensive query still contends for querier CPU. Hard isolation would require separate deployments per tenant (Tier-3 scale).
- Compliance-grade isolation (PII segregation, per-tenant encryption keys). Add these when needed via storage-layer controls.

## Component modes

Every LGTMP component has three deployment modes:

| Mode | When | This platform default |
|---|---|---|
| Monolithic | Small–mid scale (<1M series, <100 GB/day logs) | ✅ |
| Read/write split | Growing (1M–10M series) | opt-in via overlay |
| Microservices | Enterprise (>10M series) | future ADR |

We start with monolithic mode. The distributed Helm charts (`mimir-distributed`, `tempo-distributed`, `pyroscope-distributed`) are used because they support future scaling without a full rewrite — but by default they deploy in a single-binary configuration.

## Portability

### Kubernetes portability

The platform assumes only the following K8s capabilities:

- Kubernetes ≥ 1.28
- A default `StorageClass` (used only for small stateful cache — the *data* lives in object storage)
- `LoadBalancer` service type OR an `IngressController` (nginx-ingress default)
- RBAC enabled

Tested on: kind, k3s, EKS, GKE, DOKS.

### Storage portability

All data goes to an S3-compatible bucket via env-configured credentials:

```yaml
storage:
  endpoint: ${OBJECT_STORE_ENDPOINT}
  bucket: ${OBJECT_STORE_BUCKET}
  access_key: ${OBJECT_STORE_ACCESS_KEY}
  secret_key: ${OBJECT_STORE_SECRET_KEY}
  region: ${OBJECT_STORE_REGION}
```

Verified backends: AWS S3, Cloudflare R2, Backblaze B2, MinIO, GCS (via S3-compat mode).

### DNS / TLS portability

Ingress hostnames are templated. cert-manager issues Let's Encrypt certs by default; can be swapped for internal CA or manual certs by editing one values file.

## Bootstrap layer

Before the platform can be deployed, the cluster needs:

- **ArgoCD** — GitOps controller; syncs `kubernetes/` from this repo
- **cert-manager** — TLS certificate lifecycle (Let's Encrypt HTTP-01)
- **ingress-nginx** — HTTP routing to Grafana + Alloy OTLP receivers
- **external-secrets-operator** — pull secrets from a real secret store (not needed locally)
- **MinIO** (local only) — S3-compatible storage inside the cluster for local dev

These are one-time installs per cluster. See `kubernetes/bootstrap/`.

## Observability of the observability platform

The platform monitors itself. `kubernetes/observability-meta/` deploys:

- `kube-prometheus-stack` — cluster + node metrics scraped into Mimir tenant `_meta`
- Health dashboards for each LGTMP component
- Alerts on: ingester saturation, querier latency, object storage write failures, tenant quota approaching limits

Meta-observability data goes to the `_meta` tenant, which cannot be deleted through the onboarding tooling.

## Failure modes and blast radius

| Failure | Impact | Recovery |
|---|---|---|
| Grafana pod dies | Query UI unavailable; ingest unaffected | Auto-restart, <1min |
| One Mimir ingester dies | Recent writes buffered by other ingesters (RF=3) | Auto-restart; ingester quorum tolerates 1 loss |
| Loki compactor lag | Query paths still work; storage grows slowly | Alert on lag > 30min |
| Object storage outage | Writes fail; recent reads served from ingester memory | External dependency — accept and alert |
| ArgoCD out of sync | Config drift, no immediate impact | Investigate, resync manually |
| Cluster-wide network partition | Alloy buffers locally then drops | Increase Alloy WAL retention if this is common |

## Decisions with alternatives considered

Full context in [`docs/adr/`](./docs/adr/). Summary:

- **ADR-001** — Grafana LGTMP over ELK, SigNoz, Datadog (rationale: OSS, object-storage native, single vendor for four pillars).
- **ADR-002** — Alloy over OTel Collector directly (rationale: Grafana Labs-maintained, single agent per node, tighter LGTMP integration).
- **ADR-003** — Monolithic mode default, distributed charts (rationale: scale-later without rewrite).
- **ADR-004** — Soft multi-tenancy via `X-Scope-OrgID` (rationale: sufficient isolation, simpler ops than per-tenant deployments).
- **ADR-005** — ArgoCD over Flux (rationale: better UI for portfolio demo; both are valid).
- **ADR-006** — S3-compatible only (rationale: covers 95% of providers via one interface).

## Growth path

| Trigger | Action |
|---|---|
| Mimir ingester OOM or ingest rate limit hit | Split write path — add distributor + ingester replicas |
| Query timeouts at P95 | Split read path — add querier + store-gateway |
| Compactor lag | Isolate compactor as its own Deployment |
| Regulatory need for hard tenant isolation | Deploy separate LGTMP stack per tenant (or upgrade to per-tenant namespaces) |
| >10M active series | Migrate to microservices mode via Helm value flip |
| Multi-region reads | Federate via Grafana datasource per region |
