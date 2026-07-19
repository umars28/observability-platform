# Architecture Decision Records

Decisions worth keeping around, in the order they were made.

| ID | Title | Status |
|---|---|---|
| [0001](./0001-choose-lgtmp-stack.md) | Choose LGTMP stack over alternatives | Accepted |
| [0002](./0002-alloy-as-collector.md) | Grafana Alloy as the single collector | Accepted |
| [0003](./0003-monolithic-default-distributed-charts.md) | Monolithic mode by default, distributed charts | Accepted |
| [0004](./0004-soft-multi-tenancy.md) | Soft multi-tenancy via X-Scope-OrgID | Accepted |
| [0005](./0005-argocd-over-flux.md) | ArgoCD as the GitOps controller | Accepted |
| [0006](./0006-s3-compatible-storage-only.md) | S3-compatible object storage as the only backend | Accepted |

New ADRs go in numerical order using [`0000-adr-template.md`](./0000-adr-template.md) as the starting point.

## Format

An ADR is short. It captures a decision, the context around it, the alternatives considered, and the consequences. If you find yourself writing a design document, that goes elsewhere; ADRs are the record of *what we chose and why*, not *how it works*.
