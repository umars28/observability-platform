# ADR-0001: Choose LGTMP stack over alternatives

- **Status**: Accepted
- **Date**: 2026-07-19

## Context

We need a self-hostable, open-source observability platform covering four pillars — metrics, logs, traces, profiling — for multiple projects on a shared infrastructure. Constraints:

- Open source, no vendor lock-in
- S3-compatible storage backend (cost-efficient at scale)
- Multi-tenancy support without per-project deployments
- Reasonable operational overhead for a small team
- Portable across Kubernetes distributions

## Decision

Use the Grafana **LGTMP stack**: Loki (logs), Grafana (UI), Tempo (traces), Mimir (metrics), Pyroscope (profiles). All accept OpenTelemetry input; all store data in S3-compatible object storage; all support tenant isolation via `X-Scope-OrgID`.

## Alternatives considered

- **ELK / OpenSearch stack**
  - Pros: mature, best-in-class log search
  - Cons: RAM-hungry, expensive at scale, metrics/profiling not first-class citizens, Elastic License drama
- **SigNoz (OTel + ClickHouse)**
  - Pros: all-in-one, modern UI, single database
  - Cons: vendor-driven single company, no profiling, smaller ecosystem
- **VictoriaMetrics + Loki + Tempo + Pyroscope**
  - Pros: much lower resource footprint (3–5× less RAM)
  - Cons: MetricsQL differs slightly from PromQL, smaller vendor
- **Datadog / New Relic (SaaS)**
  - Pros: zero ops, best UX
  - Cons: cost scales badly, data leaves our infrastructure, vendor lock-in

## Consequences

- **Positive**: single vendor for all four pillars; tight integration (traces↔logs↔profiles jumps in Grafana); object-storage native; well-documented Helm charts.
- **Negative**: higher resource baseline than VictoriaMetrics equivalent; five components to operate instead of one.
- **Neutral**: PromQL/LogQL are industry standard; skills transfer.

## Follow-ups

- Reconsider VictoriaMetrics if hosting costs become the primary bottleneck. See ADR-0003 for scaling posture.
