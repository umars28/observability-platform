variable "hcloud_token" {
  description = "Hetzner Cloud API token. Set via HCLOUD_TOKEN env var or terraform.tfvars."
  type        = string
  sensitive   = true
}

variable "cluster_name" {
  type    = string
  default = "observability"
}

variable "location" {
  type    = string
  default = "fsn1"
}

variable "server_type" {
  type    = string
  default = "cx22"
}

variable "node_count" {
  type    = number
  default = 3
}

variable "ssh_key_names" {
  type = list(string)
}

variable "ssh_allow_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable "k3s_version" {
  type    = string
  default = "v1.31.4+k3s1"
}
