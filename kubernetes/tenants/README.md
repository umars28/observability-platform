# Tenants

Each subdirectory here is a **tenant**: an isolated project that ships signals to the platform. Tenants share the LGTMP components but keep their data logically separated (`X-Scope-OrgID`), and physically separated in the object store (per-tenant bucket prefix).

## What a tenant owns

- Its own `X-Scope-OrgID` value
- Its own retention policy, ingest rate limits, active-series cap
- Its own Grafana folder (dashboards, alerts, alert receivers)
- Its own alerting rules
- Optional: a dedicated Alloy sidecar in its namespace with the tenant header hardcoded

## What a tenant does NOT own

- The LGTMP components themselves — those live in `../platform/`
- Cluster-wide bootstrap layer
- Meta-observability data

## Onboarding a new tenant

```bash
./scripts/onboard-tenant.sh <tenant-name>
```

This copies `_template/` into `<tenant-name>/`, substitutes placeholders, and prints next steps.

## Directory layout of a tenant

```
kubernetes/tenants/<name>/
├── README.md            # Notes for humans (owner, contact, purpose)
├── tenant.yaml          # Declarative tenant metadata
├── limits.yaml          # Per-tenant Mimir/Loki/Tempo limits overrides
├── datasources.yaml     # Grafana datasources scoped to this tenant
├── alerts/              # Prometheus/Mimir alerting rules for this tenant
├── dashboards/          # Grafana dashboards for this tenant
└── kustomization.yaml   # Kustomize entrypoint (referenced by ArgoCD)
```

## Reserved tenant names

- `_meta` — the platform's own signals; cannot be deleted by onboarding tooling
- `_default` — used by Alloy when no tenant header is present; do not treat as a real tenant

## Deletion

```bash
./scripts/offboard-tenant.sh <tenant-name>
```

This:
1. Deletes the tenant directory
2. Removes the tenant's Grafana folder and datasources
3. Optionally purges the tenant's object-store prefix (`--purge-data`)
4. Removes per-tenant alert rules

Data purge is not automatic — you must pass `--purge-data` explicitly.
