terraform {
  required_version = ">= 1.6"
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = ">= 1.48"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6"
    }
  }
}

provider "hcloud" {
  token = var.hcloud_token
}

# ─── Cluster token (bootstrap token for k3s HA join) ───────────────────
resource "random_password" "k3s_token" {
  length  = 48
  special = false
}

# ─── Private network ───────────────────────────────────────────────────
resource "hcloud_network" "cluster" {
  name     = "${var.cluster_name}-net"
  ip_range = var.private_network_cidr
}

resource "hcloud_network_subnet" "cluster" {
  network_id   = hcloud_network.cluster.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = cidrsubnet(var.private_network_cidr, 8, 0)
}

# ─── Firewall (public interface only) ──────────────────────────────────
resource "hcloud_firewall" "cluster" {
  name = "${var.cluster_name}-fw"

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "22"
    source_ips = var.ssh_allow_cidrs
  }

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "80"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "443"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction = "in"
    protocol  = "icmp"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
}

# ─── SSH keys ──────────────────────────────────────────────────────────
data "hcloud_ssh_keys" "provided" {
  with_selector = "name in (${join(",", var.ssh_key_names)})"
}

# ─── Nodes ─────────────────────────────────────────────────────────────
locals {
  node_private_ips = [for i in range(var.node_count) : cidrhost(cidrsubnet(var.private_network_cidr, 8, 0), i + 10)]
}

resource "hcloud_server" "node" {
  count = var.node_count

  name        = "${var.cluster_name}-${count.index + 1}"
  image       = var.image
  server_type = var.server_type
  location    = var.location

  ssh_keys      = [for k in data.hcloud_ssh_keys.provided.ssh_keys : k.id]
  firewall_ids  = [hcloud_firewall.cluster.id]

  network {
    network_id = hcloud_network.cluster.id
    ip         = local.node_private_ips[count.index]
  }

  user_data = templatefile("${path.module}/k3s_install.sh", {
    is_first      = count.index == 0
    node_index    = count.index
    private_ip    = local.node_private_ips[count.index]
    first_node_ip = local.node_private_ips[0]
    k3s_version   = var.k3s_version
    k3s_token     = random_password.k3s_token.result
    hostname      = "${var.cluster_name}-${count.index + 1}"
    tls_sans      = [] # TODO: expose a variable for LB IPs / vip domains
  })

  labels = {
    cluster = var.cluster_name
    role    = "control-plane-and-worker"
  }

  depends_on = [hcloud_network_subnet.cluster]
}
