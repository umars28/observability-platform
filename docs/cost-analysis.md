# Cost analysis

Real-money numbers for running this platform. Two tiers documented: a hobby-scale reference deployment and a small-production deployment. Update as pricing changes.

Last updated: 2026-07-19.

## Assumptions

- 5 tenants, ~30 services total
- 100k active metric series
- 15 GB/day of logs (compressed)
- 500 spans/sec at 10% trace sampling
- Retention: metrics 90d, logs 30d, traces 7d, profiles 14d

## Tier 1 — Reference "hobby" deployment (~$25/mo)

3-node k3s cluster on Hetzner + Cloudflare R2 + Cloudflare DNS. Suitable for a personal project, portfolio demo, or small startup with <5 engineers.

| Item | Provider | Spec | Monthly |
|---|---|---|---|
| Node 1 (control-plane + worker) | Hetzner Cloud | CX22 (2 vCPU, 4 GB, 40 GB) | €4.15 |
| Node 2 (control-plane + worker) | Hetzner Cloud | CX22 (2 vCPU, 4 GB, 40 GB) | €4.15 |
| Node 3 (control-plane + worker) | Hetzner Cloud | CX22 (2 vCPU, 4 GB, 40 GB) | €4.15 |
| Private network                 | Hetzner Cloud | 10.0.0.0/24               | €0    |
| Object storage — 500 GB stored  | Cloudflare R2 | Standard                  | $7.50 |
| Object storage — Class A ops    | Cloudflare R2 | ~1M/mo                    | $4.50 |
| Object storage — Class B ops    | Cloudflare R2 | ~10M/mo                   | $3.60 |
| Egress                          | Cloudflare R2 | included                  | $0    |
| DNS                             | Cloudflare    | free tier                 | $0    |
| Domain (`.dev`)                 | Namecheap     |                           | $1.00 |
| **Total** |  |  | **~$25/mo** |

Notes:
- Hetzner prices in EUR excl. VAT (~€12.50 total).
- Cloudflare R2 has **zero egress fees**, which for observability data (heavy write, moderate read) is the killer feature.
- No monitored uptime provider included; add UptimeRobot free tier for external health checks.

### What this tier gives up

- No HA control plane in a real sense: 3-node k3s is HA, but if the whole Hetzner datacentre goes down, so does everything.
- Small ingester replicas (RF=1) — one node down = short data gap.
- No dedicated Grafana database backup infrastructure.

## Tier 2 — Small production (~$120/mo)

3-node k3s cluster, larger nodes, more replicas, external Postgres for Grafana.

| Item | Provider | Spec | Monthly |
|---|---|---|---|
| Node 1 | Hetzner Cloud | CX42 (4 vCPU, 16 GB, 160 GB NVMe) | €17.20 |
| Node 2 | Hetzner Cloud | CX42 (4 vCPU, 16 GB, 160 GB NVMe) | €17.20 |
| Node 3 | Hetzner Cloud | CX42 (4 vCPU, 16 GB, 160 GB NVMe) | €17.20 |
| Load balancer                   | Hetzner Cloud | LB11                       | €5.40 |
| Object storage — 2 TB stored    | Cloudflare R2 |                            | $30 |
| Object storage — ops            | Cloudflare R2 | scaled                     | $12 |
| Postgres — Grafana database     | Neon          | Launch (0.25 CU)           | $19 |
| Domain + TLS                    | Namecheap + LE|                            | $1 |
| **Total** |  |  | **~$120/mo** |

Notes:
- RF=3 on ingesters becomes feasible.
- Load balancer allows exposing Grafana + Alloy externally with TLS termination.
- Grafana Postgres externalized so laptop crash != dashboards loss.

## How each pillar consumes storage

Rough shapes so you can predict where costs go as you grow:

| Pillar | Cost driver | Typical dominance |
|---|---|---|
| Mimir  | Active series (labels) | Cardinality accidents dominate — a label with high uniqueness (user_id, trace_id) can 10× cost |
| Loki   | Bytes ingested         | Structured logs at high verbosity are the biggest single line item |
| Tempo  | Bytes ingested (traces)| Sampling rate is the primary knob |
| Pyroscope | Bytes ingested (profiles) | Cheapest of the four; ~5% overhead on top of the app |

## Costs that don't show up in the table

- **Engineering time**: 1–2 hours/month is realistic operational overhead at this scale. Do factor this in against SaaS pricing.
- **Learning curve**: first setup takes 1–2 days. Amortizes fast if used across projects.
- **Bandwidth for ingest** (from apps to cluster): free within Hetzner's private network; would be egress-charged on AWS.

## Comparison — SaaS at the same scale

Rough monthly numbers for the same workload on managed services:

| Service | Monthly |
|---|---|
| **Grafana Cloud** — Pro | ~$110 (metrics/logs/traces free tiers help) |
| **Datadog** — Pro | ~$700+ (host-based pricing, ingest-heavy) |
| **New Relic** — Pro | ~$300+ (100 GB free, then $0.35/GB) |
| **This platform** (Tier 2 self-hosted) | ~$120 + ops time |

The break-even against Datadog is roughly 3–6 months of engineering time. Against Grafana Cloud, the platform mostly buys you data sovereignty and no seat pricing.

## Growth math

If you add a new tenant and it doubles metric cardinality:

- Mimir ingester memory usage roughly doubles.
- Object storage grows proportionally to bytes ingested (linear).
- Query CPU competes for the same querier — first thing to feel it.

Trigger for tier-up: sustained >70% ingester memory or CPU on any component for a week.
