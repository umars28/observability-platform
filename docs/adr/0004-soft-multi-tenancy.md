# ADR-0004: Soft multi-tenancy via X-Scope-OrgID

- **Status**: Accepted
- **Date**: 2026-07-19

## Context

The platform must host multiple projects on shared infrastructure without letting one project impact another (storage bloat, ingest floods, expensive queries) or see another's data. Options range from label-based conventions (weakest) to per-tenant clusters (strongest, most expensive).

## Decision

Use each LGTMP component's built-in **soft multi-tenancy** driven by the `X-Scope-OrgID` HTTP header. Alloy attaches the header per-tenant during ingest; Grafana attaches it per-datasource during query. Per-tenant limits, retention, and RBAC are enforced at the component level.

## Alternatives considered

- **Label-based only (no tenant header)**
  - Pros: simplest
  - Cons: users can query across tenants; no per-tenant retention; no ingest isolation
- **Namespace-per-tenant deployments**
  - Pros: cleaner isolation, RBAC via K8s
  - Cons: 5× resource footprint per tenant; onboarding is expensive; kills the shared-infrastructure economy
- **Fully separate clusters per tenant**
  - Pros: hardest possible isolation
  - Cons: only justified for regulatory needs; not our scale

## Consequences

- **Positive**: single set of LGTMP components serves N tenants; storage prefixed per tenant (easy delete); per-tenant limits enforced; costs scale sub-linearly with tenants.
- **Negative**: query performance is shared — one tenant's expensive query can queue behind another's. No cryptographic isolation of data at rest.
- **Neutral**: same model used by Grafana Cloud and Grafana Labs' own deployments; scales to thousands of tenants at Grafana Labs scale.

## Follow-ups

- If a tenant with compliance requirements shows up: promote them to a dedicated namespace deployment; keep the shared platform for everyone else.
- Document the tenant onboarding lifecycle in `docs/onboarding-tenant.md`.
