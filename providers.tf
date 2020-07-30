provider "openstack" {
  version     = "~> 1.29"
  use_octavia = true
}

provider "rke" {
  version = "~> 1.0"
}
