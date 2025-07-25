output "volumes" {
  value = {
    for key, val in hcloud_volume.this : key => {
      id     = val.id
      device = val.linux_device
    }
  }
  sensitive   = false
  description = "Cluster Volumes"
}

output "servers" {
  value = {
    for key, val in terraform_data.this : key => {
      groups     = var.servers[key].groups
      connection = val.output
    }
  }
  sensitive   = false
  description = "Cluster Servers"
}

output "balancers" {
  value = {
    for key, val in hcloud_load_balancer.this : key => {
      public_ipv4 = val.ipv4
      public_ipv6 = val.ipv6
      private_ip  = try(hcloud_load_balancer_network.this[key].ip, null)
    }
  }
  sensitive   = false
  description = "Cluster Balancers"
}
