data "openstack_compute_availability_zones_v2" "region" {}

resource "openstack_compute_instance_v2" "instance" {
  count           = var.num
  name            = format(var.hostname_format, count.index + 1, var.cluster_name, join("-", var.tags))
  image_name      = var.image_name
  flavor_name     = var.flavor_name
  key_pair        = var.key_pair
  user_data       = var.user_data
  security_groups = var.security_groups
  tags            = var.tags

  network {
    uuid = var.network_id
  }
}

resource "openstack_networking_floatingip_v2" "instance_fip" {
  count = var.associate_public_ip_address ? var.num : 0
  pool  = var.floating_ip_pool
}

resource "openstack_compute_floatingip_associate_v2" "instance_fip" {
  count       = var.associate_public_ip_address ? var.num : 0
  instance_id = openstack_compute_instance_v2.instance.*.id[count.index]
  floating_ip = openstack_networking_floatingip_v2.instance_fip.*.address[count.index]
}

resource "null_resource" "wait_for_cloudinit" {
  count = var.associate_public_ip_address ? var.num : 0
  triggers = {
    node_instance_id = openstack_compute_instance_v2.instance.*.id[count.index]
  }
  connection {
    host  = openstack_networking_floatingip_v2.instance_fip.*.address[count.index]
    user  = var.user_name
    agent = true
  }
  provisioner "remote-exec" {
    inline = ["cloud-init status --wait"]
  }
}
