terraform {
  required_version = ">= 1.6"
  # Uncomment to store state in Hetzner Storage Box, S3, GCS, etc.
  # backend "s3" {
  #   bucket = "..."
  #   key    = "observability-platform/live.tfstate"
  #   region = "auto"
  #   endpoints = { s3 = "https://<acct>.r2.cloudflarestorage.com" }
  #   skip_credentials_validation = true
  #   skip_region_validation      = true
  #   skip_metadata_api_check     = true
  # }
}

module "cluster" {
  source = "../../modules/hetzner-k3s"

  hcloud_token    = var.hcloud_token
  cluster_name    = var.cluster_name
  location        = var.location
  server_type     = var.server_type
  node_count      = var.node_count
  ssh_key_names   = var.ssh_key_names
  ssh_allow_cidrs = var.ssh_allow_cidrs
  k3s_version     = var.k3s_version
}

output "control_plane_ips" {
  value = module.cluster.control_plane_ips
}

output "control_plane_private_ips" {
  value = module.cluster.control_plane_private_ips
}

output "kubeconfig_command" {
  value = module.cluster.kubeconfig_command
}
