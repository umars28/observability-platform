#!/usr/bin/env bash
# onboard-tenant.sh — bootstrap a new tenant/project in the platform
# Usage: ./onboard-tenant.sh <tenant-name>
set -euo pipefail

TENANT="${1:-}"
if [ -z "$TENANT" ]; then
  echo "Usage: $0 <tenant-name>"
  echo "Example: $0 my-project"
  exit 1
fi

# Validate tenant name (lowercase alphanumeric + hyphens, RFC 1123)
if ! [[ "$TENANT" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ ]]; then
  echo "✗ Tenant name must be RFC 1123 compliant (lowercase alphanumeric + hyphens)."
  exit 1
fi

TEMPLATE_DIR="kubernetes/tenants/_template"
TENANT_DIR="kubernetes/tenants/${TENANT}"

if [ -d "$TENANT_DIR" ]; then
  echo "✗ Tenant '$TENANT' already exists at $TENANT_DIR"
  exit 1
fi

if [ ! -d "$TEMPLATE_DIR" ]; then
  echo "✗ Template directory not found: $TEMPLATE_DIR"
  exit 1
fi

echo "▶ Creating tenant '$TENANT'..."
cp -r "$TEMPLATE_DIR" "$TENANT_DIR"

# Substitute placeholders in all files
find "$TENANT_DIR" -type f \( -name "*.yaml" -o -name "*.md" \) -print0 |
  xargs -0 sed -i.bak "s/__TENANT__/${TENANT}/g"
find "$TENANT_DIR" -name "*.bak" -delete

echo "✓ Tenant scaffolding created at: $TENANT_DIR"
echo ""
echo "Next steps:"
echo "  1. Review and edit $TENANT_DIR/tenant.yaml (retention, quotas)"
echo "  2. Commit: git add $TENANT_DIR && git commit -m \"onboard tenant: $TENANT\""
echo "  3. ArgoCD will sync automatically, or run: kubectl apply -k $TENANT_DIR"
echo ""
echo "In your application, set the OTel exporter to send with header:"
echo "  X-Scope-OrgID: $TENANT"
