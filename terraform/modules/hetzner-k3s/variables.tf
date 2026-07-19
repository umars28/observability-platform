variable "hcloud_token" {
  description = "Hetzner Cloud API token"
  type        = string
  sensitive   = true
}

variable "cluster_name" {
  description = "Prefix used to name all resources"
  type        = string
  default     = "observability"
}

variable "location" {
  description = "Hetzner datacenter location (nbg1, fsn1, hel1, ash, hil, sin)"
  type        = string
  default     = "fsn1"
}

variable "server_type" {
  description = "Hetzner server type for cluster nodes"
  type        = string
  default     = "cx22"
}

variable "node_count" {
  description = "Number of cluster nodes. Must be odd for etcd quorum. Minimum 3 for HA."
  type        = number
  default     = 3
  validation {
    condition     = var.node_count % 2 == 1 && var.node_count >= 1
    error_message = "node_count must be odd (etcd quorum requirement)."
  }
}

variable "image" {
  description = "Base OS image"
  type        = string
  default     = "ubuntu-24.04"
}

variable "ssh_key_names" {
  description = "Names of pre-existing hcloud_ssh_key resources to attach"
  type        = list(string)
}

variable "ssh_allow_cidrs" {
  description = "CIDRs allowed to SSH to the nodes"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "k3s_version" {
  description = "Pin the k3s release. Empty for latest stable."
  type        = string
  default     = "v1.31.4+k3s1"
}

variable "private_network_cidr" {
  description = "CIDR for the internal cluster network"
  type        = string
  default     = "10.0.0.0/16"
}
