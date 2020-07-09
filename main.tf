provider "openstack" {
  use_octavia = true
}

data "openstack_identity_auth_scope_v3" "scope" {
  name = "auth_scope"
}

module "rancher-network" {
  source = "./modules/network"

  cluster_name        = var.cluster_name
  external_network_id = var.external_network_id
}

module "controllers-loadbalancer" {
  source            = "./modules/loadbalancer"
  num_nodes         = length(module.rke-controllers.instances)
  network_id        = module.rancher-network.network_id
  subnet_id         = module.rancher-network.subnet_id
  floating_ip_pool  = var.floating_ip_pool
  node_ip_addresses = module.rke-controllers.private_ips
  security_group_id = [openstack_compute_secgroup_v2.rke.id]
}

module "workers-loadbalancer" {
  source            = "./modules/loadbalancer"
  num_nodes         = length(module.rke-workers.instances)
  network_id        = module.rancher-network.network_id
  subnet_id         = module.rancher-network.subnet_id
  floating_ip_pool  = var.floating_ip_pool
  node_ip_addresses = module.rke-workers.private_ips
  security_group_id = [openstack_compute_secgroup_v2.rke.id]
}

module "rke-controllers" {
  source = "./modules/nodes"

  num                         = var.num_controllers
  cluster_name                = var.cluster_name
  image_name                  = var.image_name
  flavor_name                 = var.controllers_flavor_name
  key_pair                    = var.key_pair
  user_name                   = var.username
  user_data                   = file("user-data.conf")
  security_groups             = ["rke"]
  network_id                  = module.rancher-network.network_id
  associate_public_ip_address = true
  floating_ip_pool            = var.floating_ip_pool
  tags                        = ["controlplane", "etcd"]
}

module "rke-workers" {
  source = "./modules/nodes"

  num                         = var.num_workers
  cluster_name                = var.cluster_name
  image_name                  = var.image_name
  flavor_name                 = var.workers_flavor_name
  key_pair                    = var.key_pair
  user_name                   = var.username
  user_data                   = file("user-data.conf")
  security_groups             = ["rke"]
  network_id                  = module.rancher-network.network_id
  associate_public_ip_address = true
  floating_ip_pool            = var.floating_ip_pool
  tags                        = ["worker"]
}

resource rke_cluster "rke-cluster" {
  ssh_agent_auth = true

  # Controllers
  dynamic nodes {
    for_each = module.rke-controllers.instances
    content {
      address           = module.rke-controllers.public_ips[nodes.key]
      internal_address  = module.rke-controllers.private_ips[nodes.key]
      hostname_override = module.rke-controllers.name[nodes.key]
      user              = var.username
      role              = module.rke-controllers.tags[nodes.key]
    }
  }

  # Workers
  dynamic nodes {
    for_each = module.rke-workers.instances
    content {
      address           = module.rke-workers.public_ips[nodes.key]
      internal_address  = module.rke-workers.private_ips[nodes.key]
      hostname_override = module.rke-workers.name[nodes.key]
      user              = var.username
      role              = module.rke-workers.tags[nodes.key]
    }
  }

  authentication {
    strategy = "x509"

    sans = [
      module.controllers-loadbalancer.public_ip,
      "${module.controllers-loadbalancer.public_ip}.dnsify.me",
    ]
  }

  bastion_host {
    address        = module.rke-controllers.public_ips[0]
    ssh_agent_auth = true
    user           = "ubuntu"
  }

  services {
    kubelet {
      extra_args = {
        cloud-provider = "external"
      }
    }
  }

  cloud_provider {
    name = "openstack"
    openstack_cloud_provider {
      global {
        username  = data.openstack_identity_auth_scope_v3.scope.user_name
        password  = var.os_password
        auth_url  = var.os_auth_url
        tenant_id = data.openstack_identity_auth_scope_v3.scope.project_id
        domain_id = data.openstack_identity_auth_scope_v3.scope.project_domain_id
      }
      load_balancer {
        use_octavia         = true
        subnet_id           = module.rancher-network.subnet_id
        floating_network_id = var.external_network_id
      }
    }
  }

  depends_on = [module.rke-controllers, module.rke-workers]
}

resource "local_file" "kube_cluster_yaml" {
  filename = "${path.root}/kube_config_cluster.yml"
  content  = rke_cluster.rke-cluster.kube_config_yaml
}

