#!/bin/bash
# cloud-init bootstrap for a k3s HA node.
# Rendered per-node from Terraform templatefile().
set -euo pipefail

# ─── Prep ──────────────────────────────────────────────────────────────
hostnamectl set-hostname "${hostname}"

# Kernel modules + sysctl
cat > /etc/modules-load.d/k3s.conf <<EOF
br_netfilter
overlay
EOF
modprobe br_netfilter overlay

cat > /etc/sysctl.d/99-k3s.conf <<EOF
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF
sysctl --system >/dev/null

# Disable swap
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# ─── Install k3s ───────────────────────────────────────────────────────
INSTALL_ARGS=(
  server
  --node-ip="${private_ip}"
  --advertise-address="${private_ip}"
  --flannel-iface=enp7s0
  --disable=traefik
  --disable=servicelb
  --write-kubeconfig-mode=0644
)

%{ if is_first ~}
# First node: initialise the cluster (etcd).
INSTALL_ARGS+=(--cluster-init)
%{ else ~}
# Subsequent nodes: join the existing cluster.
INSTALL_ARGS+=(--server="https://${first_node_ip}:6443")
%{ endif ~}

curl -sfL https://get.k3s.io | \
  INSTALL_K3S_VERSION="${k3s_version}" \
  K3S_TOKEN="${k3s_token}" \
  sh -s - "$${INSTALL_ARGS[@]}"

# Wait for k3s to be ready
until k3s kubectl get nodes >/dev/null 2>&1; do
  sleep 2
done

echo "k3s bootstrap complete on ${hostname}"
