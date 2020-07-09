variable cluster_name {
  description = "Name of cluster"
  default     = "rke"
}

variable key_pair {
  description = "Name of SSH keypair"
  default     = ""
}

variable controllers_flavor_name {
  description = "Flavor of instance to be used for master nodes"
  default     = "hotdog"
}

variable workers_flavor_name {
  description = "Flavor of instance to be used for worker nodes"
  default     = "bratwurst"
}

variable kubernetes_version {
  description = "Version of Kubernetes to deploy"
  default = "v1.18.3-rancher2-2"
}

variable image_name {
  description = "Name of image to be used"
  default     = "Ubuntu 18.04 (20942020)"
}

variable external_network_id {
  description = "UUID of external network"
  default     = ""
}

variable floating_ip_pool {
  description = "Name of network from which floating IP addresses should be assigned"
  default     = "internet"
}

variable num_controllers {
  default = "1"
}

variable num_workers {
  default = "1"
}

variable username {
  description = "Username to be used when SSH'ing into instances"
  default     = "ubuntu"
}

variable os_password {
  description = "OpenStack password"
  default     = ""
}

variable os_auth_url {
  description = "OpenStack authentication service URL"
  default     = "https://compute.sausage.cloud:5000/v3"
}
