# Observability Platform

A production-grade, multi-tenant observability platform built on the LGTMP stack (Loki, Grafana, Tempo, Mimir, Pyroscope). Portable across any Kubernetes cluster, S3-compatible object storage, and cloud provider.

> **Portfolio project** — this repo is designed to be reusable across real projects, not a one-off demo. The same platform can host observability for multiple applications with isolated tenants, per-tenant limits, and independent retention policies.

## What this platform gives you

- **Four pillars in one platform** — metrics, logs, traces, and continuous profiling, correlated in a single Grafana UI
- **Multi-tenant by default** — onboard a new project with one command; data isolation via `X-Scope-OrgID`
- **Portable** — runs on any Kubernetes ≥1.28 (k3s, EKS, GKE, DOKS, kind); storage on any S3-compatible object store (R2, MinIO, S3, GCS via S3 API)
- **GitOps-driven** — ArgoCD reconciles the entire platform from this repo
- **Cost-efficient** — object storage backend, single-binary components, resource-conscious defaults (~$20/mo live)
- **Documented** — architecture decisions, runbooks, cost analysis, onboarding guides

## Architecture at a glance

```
                    Application signals (OTLP)
                              │
                    ┌─────────▼─────────┐
                    │  Grafana Alloy    │  ← single collector per node
                    │  (per tenant tag) │
                    └────┬─────┬────┬───┘
                         │     │    │
              ┌──────────┘     │    └──────────┐
              │                │               │
         ┌────▼───┐       ┌────▼───┐      ┌────▼─────┐
         │ Mimir  │       │  Loki  │      │  Tempo   │       ┌───────────┐
         │metrics │       │  logs  │      │  traces  │       │ Pyroscope │
         └────┬───┘       └────┬───┘      └────┬─────┘       │ profiles  │
              │                │               │             └─────┬─────┘
              └────────────────┴───────────────┴───────────────────┘
                                    │
                          ┌─────────▼──────────┐
                          │  Object storage    │
                          │  (S3-compatible)   │
                          └────────────────────┘
                                    │
                          ┌─────────▼──────────┐
                          │      Grafana       │  ← single UI, per-tenant folders
                          └────────────────────┘
```

See [ARCHITECTURE.md](./ARCHITECTURE.md) for the full design.

## Quickstart

### Try it locally (kind cluster, no cloud cost)

```bash
make local-up          # spin up kind cluster + MinIO + platform
make local-demo        # deploy demo apps + load generator
make local-open        # open Grafana in browser
```

Full local walkthrough: [docs/quickstart.md](./docs/quickstart.md)

### Deploy to your own cluster

```bash
# 1. Provision infra (or use your existing cluster)
cd terraform/environments/live
terraform init && terraform apply

# 2. Bootstrap the platform
make bootstrap CLUSTER=live

# 3. Deploy LGTMP
make platform-up CLUSTER=live

# 4. Onboard your first project
./scripts/onboard-tenant.sh my-project
```

Full production walkthrough: [docs/production-deployment.md](./docs/production-deployment.md)

## Onboarding a new project

1. Copy the tenant template: `cp -r kubernetes/tenants/_template kubernetes/tenants/my-project`
2. Edit `tenant.yaml` — set project name, retention, quotas
3. Commit and push — ArgoCD syncs the rest
4. Point your app's OTel exporter to `alloy.observability.svc:4317` with header `X-Scope-OrgID: my-project`

Details: [docs/onboarding-tenant.md](./docs/onboarding-tenant.md)

## Repository layout

```
.
├── terraform/            # Reference infra provisioning (Hetzner k3s)
├── kubernetes/
│   ├── bootstrap/        # ArgoCD, cert-manager, external-secrets, ingress
│   ├── platform/         # LGTMP core (Helm values)
│   ├── tenants/          # Per-project isolation configs
│   └── observability-meta/  # Monitor the platform itself
├── apps/                 # Demo applications (Go + Node.js)
├── dashboards/           # Grafana dashboards as code
├── alerts/               # Alerting rules
├── scripts/              # Bootstrap + onboarding automation
├── docs/                 # Architecture, runbooks, ADRs
└── .github/workflows/    # CI/CD
```

## Documentation

- **[ARCHITECTURE.md](./ARCHITECTURE.md)** — Design decisions and data flow
- **[docs/quickstart.md](./docs/quickstart.md)** — Local setup in 15 minutes
- **[docs/production-deployment.md](./docs/production-deployment.md)** — Real cluster deployment
- **[docs/onboarding-tenant.md](./docs/onboarding-tenant.md)** — Add a new project
- **[docs/runbook.md](./docs/runbook.md)** — Ops playbook (incidents, upgrades, backups)
- **[docs/cost-analysis.md](./docs/cost-analysis.md)** — Real cost breakdown
- **[docs/adr/](./docs/adr/)** — Architecture Decision Records

## Design principles

1. **Portable over convenient** — no vendor-specific APIs; every dependency has a documented alternative
2. **Multi-tenant from day one** — isolation is not bolted on later
3. **Reproducible** — anyone can `git clone && make local-up` and see the same thing
4. **Observable-observability** — the platform monitors itself; failures are visible
5. **Cost-aware** — object storage first, tunable retention, resource limits enforced

## License

MIT — see [LICENSE](./LICENSE)
