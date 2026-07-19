# Terraform

Reference infrastructure for provisioning the platform. **Optional** — the LGTMP charts don't care which K8s distribution runs them. This module is provided so anyone can go from zero to a running cluster in ~15 minutes.

## Layout

```
terraform/
├── modules/
│   └── hetzner-k3s/       # Reusable module: 3-node k3s HA on Hetzner
└── environments/
    └── live/              # Wire the module for the production environment
```

## Why Hetzner as the reference

- **Cheapest node-hours** for observability-shaped workloads (write-heavy, moderate compute).
- **Zero egress fee** within Hetzner and to Cloudflare R2 (paired storage backend).
- **Private networking** included in every project — cluster nodes talk on private IPs.

## Swapping providers

The `hetzner-k3s` module is intentionally small (~200 lines). To adapt for another provider:

1. Copy the module directory (`modules/hetzner-k3s` → `modules/aws-k3s`, etc).
2. Replace the `hcloud_server`, `hcloud_network`, `hcloud_firewall` resources with their equivalents (`aws_instance`, `aws_vpc`, `aws_security_group`).
3. Keep the same `k3s_install.sh` cloud-init script — it's provider-agnostic.
4. Adjust the outputs to expose the new provider's IPs.

## First-time setup

```bash
cd terraform/environments/live
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars               # fill in your values

terraform init
terraform plan
terraform apply
```

Outputs:

- `kubeconfig` — copy to `~/.kube/config-observability` or set `KUBECONFIG=`
- `control_plane_ips` — public IPs (SSH via `ssh root@<ip>`)
- `private_network_id` — for wiring other Hetzner resources in later

## Costs

3 × CX22 nodes + private network + volumes: **~€13/month** (see [`docs/cost-analysis.md`](../docs/cost-analysis.md)).

## Not-included

- DNS records — configure separately at Cloudflare/Route53 (see production-deployment.md).
- Object storage buckets — the module deliberately does not manage R2/S3 buckets because you may want those to outlive the cluster.
- Backups — Hetzner snapshots are optional and off by default in this module.
