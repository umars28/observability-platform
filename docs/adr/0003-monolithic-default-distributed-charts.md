# ADR-0003: Monolithic mode by default, distributed Helm charts

- **Status**: Accepted
- **Date**: 2026-07-19

## Context

Mimir, Loki, Tempo, and Pyroscope each ship in three deployment modes: monolithic (single binary), read/write-separated, and microservices. Microservices mode is powerful (independent scaling per role) but requires 10+ replicas per component. For our target scale (multiple small projects, <1M active series total), microservices mode is overkill and would consume most of our VPS budget on idle replicas.

## Decision

Deploy each component in **monolithic mode** via the `-distributed` Helm charts, with all internal roles collapsed into a single replica set. This keeps resource use low today but preserves the ability to switch to distributed mode later by flipping Helm values, without rewriting manifests.

## Alternatives considered

- **Monolithic charts (`grafana/mimir`, etc.) — the non-distributed charts**
  - Pros: simpler values file
  - Cons: switching to distributed later requires re-installing under a new chart name, disrupting state
- **Distributed mode from day one**
  - Pros: no migration later
  - Cons: 3–5× resource footprint for a workload that doesn't need it; portfolio project cannot justify the cost
- **Read/write split**
  - Pros: middle ground
  - Cons: added operational surface without a driving need

## Consequences

- **Positive**: same chart works for future scale-up; minimal footprint today; clear growth path.
- **Negative**: values files are slightly more complex than a pure monolithic chart would be. Some distributed-only knobs must be explicitly set to `0` or single-replica.
- **Neutral**: no data migration needed when scaling up — object storage is the source of truth.

## Follow-ups

- Document the specific values to flip when moving to distributed mode (per component).
- Set up alerts to signal when scaling up is warranted (see [`alerts/`](../../alerts/)).
