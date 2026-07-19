# ADR-0002: Grafana Alloy as the single collector

- **Status**: Accepted
- **Date**: 2026-07-19

## Context

Applications need to send metrics, logs, traces, and profiles to the platform. Each pillar has its own ingest protocol; deploying separate agents (Prometheus scraper + Promtail + OTel Collector + Pyroscope agent) creates operational overhead and inconsistent configuration.

## Decision

Deploy **Grafana Alloy** as a DaemonSet on every node. Alloy accepts OTLP (gRPC + HTTP) from applications, receives Prometheus-format metrics via service discovery, and fans out to Mimir/Loki/Tempo/Pyroscope with the correct tenant header attached.

## Alternatives considered

- **OpenTelemetry Collector directly**
  - Pros: vendor-neutral, huge community
  - Cons: no Pyroscope profile pipeline yet (as of 2026-07), needs separate configuration for Prometheus scraping semantics
- **Per-pillar agents (Promtail + node-exporter + OTel Collector + Pyroscope agent)**
  - Pros: each is best-in-class at its job
  - Cons: four DaemonSets, four config sources, four upgrade paths
- **Grafana Agent (predecessor of Alloy)**
  - Pros: proven
  - Cons: superseded by Alloy in 2024; End-of-Life scheduled

## Consequences

- **Positive**: one binary, one config language (River), one lifecycle. Alloy has first-class Pyroscope receiver. Grafana Labs maintains it in step with the LGTMP components.
- **Negative**: less community reach than OTel Collector; a Grafana-labs-specific config language to learn. Alloy is newer, so fewer runbooks in the wild.
- **Neutral**: Alloy is a superset of OTel Collector in most respects — if we hit a limitation, we can switch back to OTel Collector for a subset of the pipeline.

## Follow-ups

- Document Alloy config templates for common instrumentation patterns.
- Reassess if OpenTelemetry Collector adds a native Pyroscope exporter and matures its profiling story.
