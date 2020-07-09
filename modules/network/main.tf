/**
 * OpenStack Network
 * =======================
 * This module creates the network infrastructure necessary for Rancher
 * on OpenStack
 */

resource "openstack_networking_network_v2" "rancher_network" {
  name = "rancher_network"
}

resource "openstack_networking_subnet_v2" "rancher_subnet" {
  name       = "rancher_subnet"
  network_id = openstack_networking_network_v2.rancher_network.id
  cidr       = var.subnet_range
  ip_version = 4
}

resource "openstack_networking_router_v2" "rancher_router" {
  name                = "rancher_router"
  admin_state_up      = true
  external_network_id = var.external_network_id
}

resource "openstack_networking_router_interface_v2" "rancher_router_int" {
  router_id = openstack_networking_router_v2.rancher_router.id
  subnet_id = openstack_networking_subnet_v2.rancher_subnet.id
}
