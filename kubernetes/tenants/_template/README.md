# Tenant: __TENANT__

Populated by `scripts/onboard-tenant.sh __TENANT__`.

## Owner & contact

- Owner: TBD
- Slack / email: TBD

## Purpose

TBD — one line on why this tenant exists.

## What sends signals here

List the services / repos that report to this tenant with `X-Scope-OrgID: __TENANT__`.

## Retention & quotas

Configured in [`tenant.yaml`](./tenant.yaml) and [`limits.yaml`](./limits.yaml). Edit those files; do not tune platform-wide values.

## Dashboards

Any JSON dropped in [`dashboards/`](./dashboards/) will land in the Grafana folder `__TENANT__` at next ArgoCD sync.

## Alerts

Baseline alerts in [`alerts/basic.yaml`](./alerts/basic.yaml). Add tenant-specific rules as separate files in the same directory.

## How the tenant's app connects

Point the OTel SDK at the platform Alloy endpoint and set the tenant header:

```
OTEL_EXPORTER_OTLP_ENDPOINT=http://alloy.observability.svc:4317
OTEL_EXPORTER_OTLP_HEADERS=X-Scope-OrgID=__TENANT__
```

Or if the SDK cannot send OTLP headers, deploy the Alloy sidecar in the tenant namespace — see [`docs/onboarding-tenant.md`](../../../docs/onboarding-tenant.md).
