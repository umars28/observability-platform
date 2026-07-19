#!/usr/bin/env bash
# check-tools.sh — verify required CLI tools are installed
set -euo pipefail

REQUIRED=(
  "kubectl:kubernetes/kubectl"
  "helm:helm.sh/docs/intro/install"
  "kind:kind.sigs.k8s.io/docs/user/quick-start"
  "terraform:terraform.io/downloads"
  "yq:github.com/mikefarah/yq"
  "jq:jqlang.github.io/jq"
)

OPTIONAL=(
  "trivy:aquasecurity/trivy"
  "sops:getsops/sops"
  "argocd:argo-cd.readthedocs.io"
)

MISSING=0

check() {
  local tool="${1%%:*}"
  local hint="${1#*:}"
  if command -v "$tool" >/dev/null 2>&1; then
    printf "  \033[0;32m✓\033[0m %s\n" "$tool"
  else
    printf "  \033[0;31m✗\033[0m %s — install: %s\n" "$tool" "$hint"
    MISSING=$((MISSING + 1))
  fi
}

echo "Required tools:"
for t in "${REQUIRED[@]}"; do check "$t"; done

echo ""
echo "Optional tools:"
for t in "${OPTIONAL[@]}"; do check "$t" || true; done

if [ "$MISSING" -gt 0 ]; then
  echo ""
  echo -e "\033[0;31m$MISSING required tool(s) missing. Install them and re-run.\033[0m"
  exit 1
fi
