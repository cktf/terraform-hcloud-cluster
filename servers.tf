resource "hcloud_placement_group" "this" {
  count = var.spread ? 1 : 0

  name = var.name
  type = "spread"
}

resource "hcloud_server" "this" {
  lifecycle {
    ignore_changes = [image, user_data]
  }

  for_each = var.servers

  name                       = coalesce(each.value.name, "${var.name}-${each.key}")
  server_type                = coalesce(each.value.type, "cpx21")
  image                      = each.value.image
  location                   = each.value.location
  datacenter                 = each.value.datacenter
  firewall_ids               = each.value.firewalls
  ignore_remote_firewall_ids = true
  ssh_keys                   = concat(each.value.ssh_keys, [hcloud_ssh_key.this.id])
  labels                     = merge(each.value.labels, { for group in each.value.groups : "${var.name}/group" => group })

  placement_group_id = (var.spread && (each.value.groups == values(var.servers)[0].groups)) ? hcloud_placement_group.this[0].id : null

  user_data = templatefile("${path.module}/templates/setup.sh", {
    gateway = try(var.bastion.gateway, "")
  })

  public_net {
    ipv4_enabled = (try(var.bastion.gateway, null) == null)
    ipv6_enabled = (try(var.bastion.gateway, null) == null)
  }

  dynamic "network" {
    for_each = each.value.network != null ? { 0 = each.value.network } : {}
    content {
      network_id = network.value
      alias_ips  = []
    }
  }
}

resource "hcloud_server_network" "this" {
  for_each = {
    for key, val in hcloud_server.this : key => val
    if var.servers[key].network != null
  }

  server_id  = each.value.id
  subnet_id  = var.servers[each.key].subnet
  network_id = var.servers[each.key].network
}

resource "hcloud_volume" "this" {
  for_each = {
    for item in flatten([
      for key, val in var.servers : [
        for name, volume in val.volumes : {
          key = "${key}_${name}"
          val = {
            name      = "${hcloud_server.this[key].name}-${name}"
            size      = volume.size
            format    = volume.format
            protected = volume.protected
            server_id = hcloud_server.this[key].id
          }
        }
      ]
    ]) : item.key => item.val
  }

  name              = each.value.name
  size              = each.value.size
  format            = each.value.format
  delete_protection = each.value.protected
  server_id         = each.value.server_id
  automount         = true
}

resource "terraform_data" "this" {
  depends_on = [hcloud_server_network.this]
  for_each   = hcloud_server.this

  input = {
    type                = "ssh"
    host                = (try(var.bastion.gateway, null) == null) ? each.value.ipv4_address : hcloud_server_network.this[each.key].ip
    user                = "root"
    private_key         = tls_private_key.this.private_key_openssh
    bastion_host        = try(var.bastion.host, null)
    bastion_port        = try(var.bastion.port, null)
    bastion_user        = try(var.bastion.user, null)
    bastion_private_key = try(var.bastion.private_key, null)
  }

  connection {
    type                = self.input.type
    host                = self.input.host
    user                = self.input.user
    private_key         = self.input.private_key
    bastion_host        = self.input.bastion_host
    bastion_port        = self.input.bastion_port
    bastion_user        = self.input.bastion_user
    bastion_private_key = self.input.bastion_private_key
  }

  provisioner "remote-exec" {
    inline = ["cloud-init status --wait || true"]
  }
}
