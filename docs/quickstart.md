# Quickstart — Local kind cluster

Get the platform running on your laptop in ~15 minutes. No cloud cost.

## Prerequisites

Install these CLI tools (Homebrew on macOS shown; any package manager works):

```bash
brew install kubectl helm kind terraform yq jq
```

Optional:

```bash
brew install trivy sops argocd
```

Verify:

```bash
make check-tools
```

## Bring it up

```bash
make local-up
```

This will:

1. Create a 3-node kind cluster named `observability`
2. Install cluster prerequisites — ArgoCD, cert-manager, ingress-nginx, MinIO
3. Deploy LGTMP core — Mimir, Loki, Tempo, Pyroscope, Grafana, Alloy

Total time: ~10 minutes on first run (Docker image pulls dominate).

## Open Grafana

```bash
make local-open
```

Then visit **<http://localhost:3000>**. Anonymous access is enabled locally (Viewer role); no login required for browsing.

Admin credentials (if you need write access):

```bash
kubectl get secret -n observability grafana-admin -o jsonpath='{.data.admin-password}' | base64 -d
```

## Deploy demo apps

```bash
make local-demo
```

This deploys the two demo microservices (`demo-shop-api`, `demo-blog-web`) plus a load generator. Within 60 seconds, you should see:

- Metrics in `Mimir (_default)`
- Logs in `Loki (_default)`
- Traces in `Tempo (_default)`
- Profiles in `Pyroscope (_default)`

## Try onboarding a tenant

```bash
./scripts/onboard-tenant.sh my-first-project
kubectl apply -k kubernetes/tenants/my-first-project
```

Reload Grafana → new datasources appear under `Mimir (my-first-project)` etc. Point a workload at Alloy with header `X-Scope-OrgID: my-first-project` and its signals appear in that scope.

## Tear it all down

```bash
make local-down
```

Deletes the kind cluster. Nothing persists on your host beyond `~/.kube/kind-observability`.

## Troubleshooting

### `make local-up` fails at bootstrap

Check pod status:

```bash
export KUBECONFIG=~/.kube/kind-observability
kubectl get pods -A
```

Common issues:

- **Docker running out of RAM** — kind needs ~6 GB free. Increase Docker Desktop's memory limit.
- **Image pulls timing out** — try `docker system prune` then rerun.
- **`OOMKilled` on ingester pods** — bump limits in `kubernetes/platform/mimir/values-local.yaml` if your laptop can spare it.

### Grafana shows "No data"

The datasource is scoped to a tenant. Locally, apps use `_default`. Check:

- Is Alloy running? `kubectl logs -n observability -l app=alloy`
- Is your app sending to Alloy? Port `4317` (OTLP gRPC) or `4318` (OTLP HTTP)
- Is the datasource selecting the right tenant? Change from `_meta` → `_default` in Grafana's datasource dropdown

## Next

- Explore the [architecture](../ARCHITECTURE.md)
- [Onboard your own project](./onboarding-tenant.md)
- Deploy to a real cluster: [production deployment](./production-deployment.md)
