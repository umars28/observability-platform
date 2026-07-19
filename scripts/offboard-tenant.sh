#!/usr/bin/env bash
# offboard-tenant.sh — remove a tenant from the platform.
# Usage: ./offboard-tenant.sh <tenant-name> [--purge-data]
set -euo pipefail

TENANT="${1:-}"
PURGE_DATA="${2:-}"

if [ -z "$TENANT" ]; then
  echo "Usage: $0 <tenant-name> [--purge-data]"
  exit 1
fi

# Prevent removal of reserved tenants
case "$TENANT" in
  _meta|_default)
    echo "✗ Reserved tenant '$TENANT' cannot be offboarded."
    exit 1 ;;
esac

TENANT_DIR="kubernetes/tenants/${TENANT}"

if [ ! -d "$TENANT_DIR" ]; then
  echo "✗ Tenant '$TENANT' does not exist at $TENANT_DIR"
  exit 1
fi

echo "▶ Removing tenant '$TENANT'"
echo "  - directory: $TENANT_DIR"
echo "  - purge data: ${PURGE_DATA:-no}"
echo ""
read -r -p "Are you sure? Type the tenant name to confirm: " CONFIRM
if [ "$CONFIRM" != "$TENANT" ]; then
  echo "Aborted."
  exit 1
fi

# 1. Remove K8s resources (Kustomize) — safe to run even if never applied
if kubectl kustomize "$TENANT_DIR" >/dev/null 2>&1; then
  echo "▶ Deleting K8s resources for tenant..."
  kubectl delete -k "$TENANT_DIR" --ignore-not-found=true || true
fi

# 2. Remove tenant directory
echo "▶ Removing tenant directory..."
rm -rf "$TENANT_DIR"

# 3. Optionally purge object storage
if [ "$PURGE_DATA" = "--purge-data" ]; then
  echo "▶ Purging object storage for tenant '$TENANT'..."
  echo "  NOTE: this uses awscli against the configured S3 endpoint."
  echo "  Set AWS_* env vars beforehand."
  for component in mimir loki tempo pyroscope; do
    bucket_var="OBJECT_STORE_BUCKET_$(echo $component | tr '[:lower:]' '[:upper:]')"
    bucket="${!bucket_var:-obs-${component}}"
    prefix="${TENANT}/"
    echo "  aws s3 rm s3://${bucket}/${prefix} --recursive"
    aws s3 rm "s3://${bucket}/${prefix}" --recursive || true
  done
fi

echo "✓ Offboarding complete for tenant: $TENANT"
echo ""
echo "Next: git add -A && git commit -m 'offboard tenant: $TENANT'"
