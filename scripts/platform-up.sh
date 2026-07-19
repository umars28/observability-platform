#!/usr/bin/env bash
# platform-up.sh — deploy LGTMP components via Helm
# Usage: ./platform-up.sh <cluster-name>
set -euo pipefail

CLUSTER="${1:-local}"
NAMESPACE="observability"

echo "▶ Deploying platform to: $CLUSTER"

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Repos
helm repo add grafana https://grafana.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update >/dev/null

# Deploy order matters: storage-backed components first, then Grafana, then Alloy
declare -a COMPONENTS=(mimir loki tempo pyroscope grafana alloy)

for c in "${COMPONENTS[@]}"; do
  base="kubernetes/platform/${c}/values.yaml"
  overlay="kubernetes/platform/${c}/values-${CLUSTER}.yaml"

  args=(--namespace "$NAMESPACE" --values "$base")
  [ -f "$overlay" ] && args+=(--values "$overlay")

  # Chart name mapping: some charts have a "-distributed" suffix
  case "$c" in
    mimir)     chart="grafana/mimir-distributed" ;;
    loki)      chart="grafana/loki" ;;
    tempo)     chart="grafana/tempo" ;;
    pyroscope) chart="grafana/pyroscope" ;;
    grafana)   chart="grafana/grafana" ;;
    alloy)     chart="grafana/alloy" ;;
  esac

  echo "▶ Deploying $c ($chart)..."
  helm upgrade --install "$c" "$chart" "${args[@]}" --wait --timeout 10m
done

echo "✓ Platform deployment complete."
echo ""
echo "Next steps:"
echo "  - kubectl get pods -n $NAMESPACE"
echo "  - make local-open  # if local, open Grafana"
