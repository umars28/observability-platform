# Dashboards

Grafana dashboards as code. Provisioned automatically via the `grafana-dashboards-*` ConfigMaps referenced in `kubernetes/platform/grafana/values.yaml`.

## Layout

```
dashboards/
├── default/               # Cross-tenant dashboards shown in Grafana root
│   ├── golden-signals.json
│   └── request-flow.json
├── meta/                  # Platform self-monitoring (tenant _meta)
│   ├── platform-health.json
│   └── ingest-rate-per-tenant.json
└── template/              # Tenant-scoped template — copied per tenant
    └── service-overview.json
```

## How dashboards land in Grafana

1. A dashboard JSON is committed here.
2. A ConfigMap is generated (see `../scripts/render-dashboards.sh`) with the JSON contents, labelled `grafana_dashboard=1`.
3. Grafana's sidecar picks it up and drops it in the right folder (default / meta / <tenant>).

## Editing workflow

1. Edit a dashboard in Grafana's UI.
2. **Share → Export → Save to file** (unchecked "Export for sharing externally").
3. Overwrite the JSON in this directory.
4. Commit — ArgoCD syncs the ConfigMap; Grafana reloads within ~30s.

Never edit in-place in Grafana without exporting back — the change will vanish on next reconciliation.

## Naming convention

- `folder = default`: dashboards useful across every project (RED metrics, node health, etc.)
- `folder = _meta`: only the platform team should touch these
- `folder = <tenant>`: per-project dashboards; live in the tenant's subdirectory
