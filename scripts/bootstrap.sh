#!/usr/bin/env bash
# bootstrap.sh — install cluster prerequisites (ArgoCD, cert-manager, ingress, external-secrets)
# Usage: ./bootstrap.sh <cluster-name>
set -euo pipefail

CLUSTER="${1:-local}"
NAMESPACE_ARGOCD="argocd"
NAMESPACE_CERT="cert-manager"
NAMESPACE_INGRESS="ingress-nginx"
NAMESPACE_ES="external-secrets"

echo "▶ Bootstrapping cluster: $CLUSTER"

# ─── ArgoCD ─────────────────────────────────────────────────────────────
echo "▶ Installing ArgoCD..."
kubectl create namespace "$NAMESPACE_ARGOCD" --dry-run=client -o yaml | kubectl apply -f -
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
helm repo update >/dev/null
helm upgrade --install argocd argo/argo-cd \
  --namespace "$NAMESPACE_ARGOCD" \
  --values "kubernetes/bootstrap/argocd/values-${CLUSTER}.yaml" \
  --wait --timeout 5m

# ─── cert-manager ───────────────────────────────────────────────────────
echo "▶ Installing cert-manager..."
kubectl create namespace "$NAMESPACE_CERT" --dry-run=client -o yaml | kubectl apply -f -
helm repo add jetstack https://charts.jetstack.io >/dev/null 2>&1 || true
helm repo update >/dev/null
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace "$NAMESPACE_CERT" \
  --values "kubernetes/bootstrap/cert-manager/values.yaml" \
  --wait --timeout 5m

# ─── ingress-nginx ──────────────────────────────────────────────────────
echo "▶ Installing ingress-nginx..."
kubectl create namespace "$NAMESPACE_INGRESS" --dry-run=client -o yaml | kubectl apply -f -
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx >/dev/null 2>&1 || true
helm repo update >/dev/null
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace "$NAMESPACE_INGRESS" \
  --values "kubernetes/bootstrap/ingress-nginx/values-${CLUSTER}.yaml" \
  --wait --timeout 5m

# ─── external-secrets (skipped for local) ───────────────────────────────
if [ "$CLUSTER" != "local" ]; then
  echo "▶ Installing external-secrets..."
  kubectl create namespace "$NAMESPACE_ES" --dry-run=client -o yaml | kubectl apply -f -
  helm repo add external-secrets https://charts.external-secrets.io >/dev/null 2>&1 || true
  helm repo update >/dev/null
  helm upgrade --install external-secrets external-secrets/external-secrets \
    --namespace "$NAMESPACE_ES" \
    --values "kubernetes/bootstrap/external-secrets/values.yaml" \
    --wait --timeout 5m
fi

# ─── MinIO (local only) ─────────────────────────────────────────────────
if [ "$CLUSTER" = "local" ]; then
  echo "▶ Installing MinIO for local S3-compatible storage..."
  kubectl create namespace minio --dry-run=client -o yaml | kubectl apply -f -
  helm repo add minio https://charts.min.io >/dev/null 2>&1 || true
  helm repo update >/dev/null
  helm upgrade --install minio minio/minio \
    --namespace minio \
    --values "kubernetes/bootstrap/minio/values-local.yaml" \
    --wait --timeout 5m
fi

echo "✓ Bootstrap complete for cluster: $CLUSTER"
