# Production deployment

End-to-end guide to standing up the platform on a real cluster. Reference target is 3× Hetzner CX22 with k3s + Cloudflare R2, but any Kubernetes cluster with S3-compatible storage works.

Time budget: **~90 minutes** for a first-time deploy.

## What you'll end up with

- 3-node HA k3s cluster
- LGTMP platform on real domains with TLS via Let's Encrypt
- One demo tenant sending signals
- Grafana reachable at `https://grafana.<your-domain>`
- ArgoCD keeping the cluster in sync with this repo

## Prerequisites

- A domain you control (via Cloudflare, Route53, or any DNS provider that supports A records)
- Hetzner Cloud account (or another provider — adapt the Terraform module)
- Cloudflare R2 account with 4 buckets: `obs-mimir-prod`, `obs-loki-prod`, `obs-tempo-prod`, `obs-pyroscope-prod`
- CLI: `terraform`, `kubectl`, `helm`, `argocd`, `sops` (or another secret tool)

## 1 — Provision infrastructure

```bash
cd terraform/environments/live
cp terraform.tfvars.example terraform.tfvars   # fill in your values
terraform init
terraform apply
```

This creates:

- 3 VPS in Hetzner Cloud (Ubuntu 24.04)
- A private network for cluster communication
- A firewall (SSH from your IP; 80/443 from anywhere; nothing else public)
- k3s installed in HA mode on the 3 nodes
- Outputs the kubeconfig to `./kubeconfig`

```bash
export KUBECONFIG=$(pwd)/kubeconfig
kubectl get nodes
# expect: 3 nodes Ready
```

## 2 — Point DNS

Create A records for each subdomain, all pointing at any node's public IP (or the LB IP if you provisioned one):

- `grafana.<your-domain>`
- `argocd.<your-domain>` (optional; skip if you prefer port-forward)

Cloudflare proxy: **off** for now (Let's Encrypt HTTP-01 needs direct access on port 80). Turn on later once certs are issued if you want DDoS protection.

## 3 — Store secrets

Create the object storage credentials as a Kubernetes Secret. Two options:

### Option A — Static Secret (simple, less secure)

```bash
kubectl create namespace observability
for pillar in mimir loki tempo pyroscope; do
  kubectl -n observability create secret generic ${pillar}-object-storage \
    --from-literal=AWS_ACCESS_KEY_ID=<your-r2-access-key> \
    --from-literal=AWS_SECRET_ACCESS_KEY=<your-r2-secret> \
    --from-literal=OBJECT_STORE_ENDPOINT=<your-r2-endpoint> \
    --from-literal=OBJECT_STORE_REGION=auto \
    --from-literal=OBJECT_STORE_BUCKET_MIMIR=obs-mimir-prod \
    --from-literal=OBJECT_STORE_BUCKET_LOKI=obs-loki-prod \
    --from-literal=OBJECT_STORE_BUCKET_TEMPO=obs-tempo-prod \
    --from-literal=OBJECT_STORE_BUCKET_PYROSCOPE=obs-pyroscope-prod
done
```

### Option B — External Secrets (recommended)

If you use Bitwarden Secrets Manager, Vault, or a cloud secret manager:

1. Store credentials there.
2. Deploy a `ClusterSecretStore` pointing at your provider (examples in `kubernetes/bootstrap/external-secrets/`).
3. Create `ExternalSecret` objects — they'll materialise into the same Secret names as Option A.

## 4 — Substitute placeholders

Values files use `__PLATFORM_DOMAIN__` and `__ACME_EMAIL__` placeholders. Fill them in before deploying:

```bash
export PLATFORM_DOMAIN=your-domain.dev
export ACME_EMAIL=you@example.com

find kubernetes/ -name 'values-live.yaml' -o -name 'cluster-issuers.yaml' | while read f; do
  sed -i.bak \
    -e "s/__PLATFORM_DOMAIN__/${PLATFORM_DOMAIN}/g" \
    -e "s/__ACME_EMAIL__/${ACME_EMAIL}/g" \
    "$f"
done
find kubernetes/ -name '*.bak' -delete
```

Commit the substituted values only if this is a private repo. For a public repo, keep placeholders and use an ArgoCD ApplicationSet with an inline generator instead — see [`kubernetes/bootstrap/argocd/apps.yaml`](../kubernetes/bootstrap/argocd/apps.yaml) when it lands.

## 5 — Bootstrap the cluster

```bash
make bootstrap CLUSTER=live
```

Installs ArgoCD, cert-manager, ingress-nginx, external-secrets. Takes ~3 minutes.

Apply cluster issuers for cert-manager:

```bash
kubectl apply -f kubernetes/bootstrap/cert-manager/cluster-issuers.yaml
```

## 6 — Deploy the platform

```bash
make platform-up CLUSTER=live
```

Takes ~5–10 minutes. Watch progress:

```bash
kubectl -n observability get pods -w
```

Expected end-state: every pod `Running`, `READY 1/1` (or 2/2 for Grafana).

## 7 — Onboard the first real tenant

```bash
./scripts/onboard-tenant.sh <your-project>
git add kubernetes/tenants/<your-project>
git commit -m "onboard tenant: <your-project>"
git push
```

Wait ~30s for ArgoCD to sync.

Point your application at the platform:

```bash
OTEL_EXPORTER_OTLP_ENDPOINT=https://alloy.<your-domain>:4317
OTEL_EXPORTER_OTLP_HEADERS=X-Scope-OrgID=<your-project>
```

## 8 — Verify

Visit `https://grafana.<your-domain>`. Log in with:

- Username: `admin`
- Password: `kubectl -n observability get secret grafana-admin -o jsonpath='{.data.admin-password}' | base64 -d`

Change the password on first login.

Switch datasource to `Mimir (<your-project>)`. Metrics should appear within 60 seconds of the first request from your app.

## 9 — Enable ArgoCD auto-sync (optional but recommended)

After the initial deploy, let ArgoCD take over reconciliation:

```bash
kubectl apply -f kubernetes/bootstrap/argocd/apps.yaml
```

From then on, changes to `kubernetes/` in git are picked up automatically. To pause auto-sync temporarily, use the ArgoCD UI or `argocd app set <name> --sync-policy none`.

## 10 — Set up meta-observability

The platform must monitor itself. Deploy the meta layer:

```bash
kubectl apply -k kubernetes/observability-meta/
```

This deploys:

- kube-prometheus-stack (ships to Mimir tenant `_meta`)
- Meta dashboards in Grafana
- Platform alerts (see [`alerts/platform/`](../alerts/platform/))

## Post-deploy checklist

- [ ] Change Grafana admin password
- [ ] Configure alert receivers (Slack, PagerDuty, Discord) in Alertmanager
- [ ] Verify TLS cert issued (`kubectl -n observability get certificate`)
- [ ] Add external uptime check for `grafana.<your-domain>`
- [ ] Configure Grafana database backup (see runbook)
- [ ] Document your tenant onboarding procedure for your team

## Troubleshooting

**Cert not issued**: check cert-manager order — `kubectl -n observability get orders`. Usually DNS not propagated or Cloudflare proxy enabled too early.

**ArgoCD stuck syncing**: `argocd app get <name>` — look at `Health` and `Status` messages. Often a missing Secret; check external-secrets logs.

**Ingester CrashLoopBackOff**: check object storage credentials. Direct probe with `aws-cli` in a debug pod.

Full alert-driven runbooks: [`docs/runbook.md`](./runbook.md).
