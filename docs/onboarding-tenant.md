# Onboarding a new tenant

This document walks you through adding a new project ("tenant") to the platform.

Time required: **~10 minutes**.

## Prerequisites

- Access to this repo
- `kubectl` context pointing at the platform cluster
- A tenant name that fits: lowercase alphanumeric + hyphens, RFC 1123 compliant (`my-project`, `payments-api`, `foo123`)

## Step 1 — Scaffold the tenant

```bash
./scripts/onboard-tenant.sh <tenant-name>
```

This creates `kubernetes/tenants/<tenant-name>/` from the template and substitutes `__TENANT__` placeholders.

## Step 2 — Fill in metadata

Open `kubernetes/tenants/<tenant-name>/tenant.yaml` and set:

- `spec.owner` — who owns this tenant (team or individual)
- `spec.purpose` — one-liner
- `spec.environment` — production / staging / dev
- `spec.retention` — override defaults if needed
- `spec.quotas` — override defaults if needed

## Step 3 — Commit and let ArgoCD sync

```bash
git add kubernetes/tenants/<tenant-name>
git commit -m "onboard tenant: <tenant-name>"
git push
```

ArgoCD picks up the change and creates:

- Grafana datasources scoped to this tenant
- Baseline alert rules
- Grafana folder for dashboards

For a manual sync (no ArgoCD):

```bash
kubectl apply -k kubernetes/tenants/<tenant-name>/
```

## Step 4 — Wire the application

Your application needs to attach `X-Scope-OrgID: <tenant-name>` to every signal it sends.

### Option A — OTel SDK sets the header

Most OTel SDKs let you set OTLP headers via env vars:

```bash
OTEL_EXPORTER_OTLP_ENDPOINT=http://alloy.observability.svc:4317
OTEL_EXPORTER_OTLP_HEADERS=X-Scope-OrgID=<tenant-name>
OTEL_SERVICE_NAME=<your-service-name>
OTEL_RESOURCE_ATTRIBUTES=deployment.environment=<env>,service.namespace=<tenant-name>
```

That is it — signals flow to the platform, isolated to your tenant.

### Option B — Alloy sidecar in your namespace

If your framework can't set OTLP headers (older gRPC clients, some log shippers), deploy an Alloy sidecar in your tenant namespace with the header baked into config. Example manifest lives in `kubernetes/tenants/_template/sidecar-alloy.yaml.example` (uncomment to use).

Apps then send OTLP to `alloy.<tenant-namespace>.svc:4317` and never worry about tenant routing.

## Step 5 — Verify

Log in to Grafana. Switch datasource to `Mimir (<tenant-name>)`. You should see your service's metrics within 60 seconds of the first request.

If not:
- Check Alloy logs: `kubectl logs -n observability -l app=alloy`
- Verify the header is present: `kubectl exec ... -- env | grep OTEL_EXPORTER_OTLP_HEADERS`
- Check Mimir ingester logs for rejected tenant IDs

## Deleting a tenant

```bash
./scripts/offboard-tenant.sh <tenant-name>              # remove config, keep data
./scripts/offboard-tenant.sh <tenant-name> --purge-data # also delete objects in bucket
```

## What isolation you get

Full details in [`ARCHITECTURE.md`](../ARCHITECTURE.md#multi-tenancy-model). Summary:

- ✅ Your data is not visible to other tenants
- ✅ Your retention / quotas do not affect other tenants
- ✅ Your Grafana folder is scoped
- ⚠️ Query performance is shared — a very heavy query still contends for querier CPU across tenants
- ⚠️ Storage credentials are shared (one bucket, per-tenant prefix)
