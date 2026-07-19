output "control_plane_ips" {
  description = "Public IPv4 addresses of the cluster nodes"
  value       = hcloud_server.node[*].ipv4_address
}

output "control_plane_private_ips" {
  description = "Private network IPs of the cluster nodes"
  value       = local.node_private_ips
}

output "private_network_id" {
  description = "ID of the Hetzner private network; use to attach additional resources"
  value       = hcloud_network.cluster.id
}

output "k3s_token" {
  description = "Bootstrap token; store securely"
  value       = random_password.k3s_token.result
  sensitive   = true
}

output "kubeconfig_command" {
  description = "SCP command to fetch the kubeconfig from the first node"
  value       = "scp root@${hcloud_server.node[0].ipv4_address}:/etc/rancher/k3s/k3s.yaml ./kubeconfig && sed -i.bak 's/127.0.0.1/${hcloud_server.node[0].ipv4_address}/' ./kubeconfig && rm -f ./kubeconfig.bak"
}
