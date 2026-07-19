# Bootstrap layer

Cluster prerequisites that must exist before the LGTMP platform can be deployed. Installed once per cluster by `scripts/bootstrap.sh <cluster>`.

## Components

| Component | Purpose | Required | Local | Production |
|---|---|---|---|---|
| **ArgoCD** | GitOps controller — reconciles `kubernetes/` from this repo | Yes | ✅ | ✅ |
| **cert-manager** | Automates TLS certificate lifecycle (Let's Encrypt) | Yes | Optional | ✅ |
| **ingress-nginx** | HTTP ingress for Grafana and Alloy OTLP receivers | Yes | ✅ | ✅ |
| **external-secrets** | Pulls secrets from external secret stores (Vault, AWS SM, etc.) | Production only | ❌ | ✅ |
| **MinIO** | S3-compatible storage for local dev (kind) | Local only | ✅ | ❌ |

## Layout convention

Each component directory contains:

- `values.yaml` — base values shared across environments
- `values-local.yaml` — kind cluster overrides (small resources, no persistence, no TLS)
- `values-live.yaml` — production overrides (real domains, TLS, larger resources)

`bootstrap.sh` picks the correct overlay based on the `CLUSTER` argument.

## Bootstrap order

1. ArgoCD — installed first so it can adopt everything else afterwards
2. cert-manager — needed before any ingress with TLS
3. ingress-nginx — needed by any HTTP-exposed service
4. external-secrets — needed to pull object-storage credentials (production)
5. MinIO — installed only for local development

## Idempotency

All Helm releases use `helm upgrade --install`. Rerunning `bootstrap.sh` is safe.
