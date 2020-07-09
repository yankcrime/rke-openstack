locals {
  services = ["80", "443", "6443"]
}

resource "openstack_lb_loadbalancer_v2" "rancher_lb" {
  name = "Rancher Loadbalancer"
  description        = "Rancher Loadbalancer"
  vip_subnet_id      = var.subnet_id
  security_group_ids = var.security_group_id
}

resource "openstack_lb_listener_v2" "rancher_lb_listener" {
  name = format("listener_%s", element(local.services, count.index))
  count = length(local.services)
  protocol        = "TCP"
  protocol_port   = element(local.services, count.index)
  loadbalancer_id = openstack_lb_loadbalancer_v2.rancher_lb.id
}

resource "openstack_lb_pool_v2" "rancher_lb_pool" {
  name = format("pool_%s", element(local.services, count.index))
  count = length(local.services)
  protocol    = "TCP"
  lb_method   = "ROUND_ROBIN"
  listener_id = openstack_lb_listener_v2.rancher_lb_listener[count.index].id
}

resource "openstack_lb_member_v2" "rancher_lb_members" {
  count = length(local.services) * var.num_nodes
  pool_id = openstack_lb_pool_v2.rancher_lb_pool[floor(count.index / var.num_nodes)].id
  protocol_port = local.services[floor(count.index / var.num_nodes)]
  subnet_id = var.subnet_id
  address = var.node_ip_addresses[count.index % var.num_nodes]
}

resource "openstack_networking_floatingip_v2" "rancher_lb_fip" {
  pool = var.floating_ip_pool
  port_id = openstack_lb_loadbalancer_v2.rancher_lb.vip_port_id
}
