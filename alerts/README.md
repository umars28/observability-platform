# Alerts

Prometheus/Mimir alerting rules. Loaded into Mimir's ruler via ConfigMaps.

## Layout

```
alerts/
├── platform/          # Alerts for the LGTMP platform itself (tenant _meta)
│   ├── ingester.yaml
│   ├── storage.yaml
│   └── quotas.yaml
└── default/           # Alerts every tenant inherits (also seeded in tenant _template)
    └── golden-signals.yaml
```

## Naming

- Groups are named `<scope>.<domain>` — e.g. `_meta.mimir_ingester` or `<tenant>.golden_signals`.
- Alert names are `PascalCase` verbs — `HighErrorRate`, `IngesterOutOfMemory`.

## Severity

Every alert must carry a `severity` label with one of:

- `critical` — page on-call immediately
- `warning`  — notify channel; investigate during business hours
- `info`     — informational; not paged

## Adding an alert

1. Drop the rule in the appropriate file.
2. Add or link a **runbook** entry in `docs/runbook.md` describing what to check.
3. If it's tenant-scoped, also update the tenant template so future tenants inherit it.
