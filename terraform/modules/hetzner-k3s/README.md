# hetzner-k3s module

Provisions a 3-node (or configurable) k3s HA cluster on Hetzner Cloud. Every node is both control-plane and worker.

## What it creates

- N `hcloud_server` resources (Ubuntu 24.04)
- Private network with a subnet in `eu-central`
- Firewall: SSH from allowed CIDRs, 80/443 from anywhere, ICMP
- Bootstrap token for k3s HA join
- Cloud-init script that installs k3s in HA mode

## What it doesn't create

- SSH keys — bring your own via `ssh_key_names`
- DNS records
- Load balancer (add one manually or extend the module)
- Object storage buckets

## Usage

```hcl
module "cluster" {
  source = "../../modules/hetzner-k3s"

  hcloud_token    = var.hcloud_token
  cluster_name    = "observability"
  location        = "fsn1"
  server_type     = "cx22"
  node_count      = 3
  ssh_key_names   = ["laptop-2026"]
  ssh_allow_cidrs = ["203.0.113.10/32"]
  k3s_version     = "v1.31.4+k3s1"
}
```

## After apply

Get the kubeconfig from the first node:

```bash
eval "$(terraform output -raw kubeconfig_command)"
export KUBECONFIG=$(pwd)/kubeconfig
kubectl get nodes
```

Should show `NodeCount` nodes in `Ready` state.

## Node sizing guidance

| Server type | vCPU | RAM  | ~€/mo | Suitable for                     |
|-------------|------|------|-------|----------------------------------|
| cx22        | 2    | 4 GB | 4.15  | Portfolio, low ingest            |
| cx32        | 4    | 8 GB | 7.05  | Small production                 |
| cx42        | 4    | 16 GB| 17.20 | Small–mid production             |
| cx52        | 8    | 32 GB| 33.50 | Ingester-heavy, many tenants     |

RAM is usually the constraint (Mimir ingesters + query nodes). CPU headroom for compaction bursts.

## Odd node count

`node_count` is validated to be odd. etcd needs a majority quorum: 1, 3, 5, 7… A 2-node cluster loses HA (a single failure loses quorum).
