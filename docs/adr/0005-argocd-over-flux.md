# ADR-0005: ArgoCD as the GitOps controller

- **Status**: Accepted
- **Date**: 2026-07-19

## Context

The platform is declared entirely in this repo. To keep the cluster in sync with the repo, we need a GitOps controller. The two credible options are ArgoCD and FluxCD.

## Decision

Use **ArgoCD**.

## Alternatives considered

- **FluxCD**
  - Pros: modular (source + kustomize + helm controllers separate), CLI-first, first-class Kustomize
  - Cons: no built-in UI (Weave GitOps is separate), steeper for newcomers
- **No controller (plain `helm upgrade` from CI)**
  - Pros: simplest
  - Cons: no drift detection, no self-healing, no visualisation

## Consequences

- **Positive**: ArgoCD's UI is a strong portfolio artefact — visitors see sync state, drift, and health at a glance. Application-of-Applications pattern maps cleanly to `bootstrap → platform → tenants`.
- **Negative**: ArgoCD itself becomes a component to operate. Slightly heavier than Flux.
- **Neutral**: both are CNCF graduated; either is defensible in interviews.

## Follow-ups

- Provide an App-of-Apps definition under `kubernetes/bootstrap/argocd/` so a single `kubectl apply` bootstraps everything else.
