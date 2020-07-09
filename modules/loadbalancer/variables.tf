variable "security_group_id" {
  description = "The security groups (firewall rules) that will be applied to this loadbalancer"
  type        = list(string)
  default     = [""]
}

variable "num_nodes" {
  default = ""
}

variable "network_id" {
  description = "The network ID in which the loadbalancer should sit"
  default     = ""
}

variable "subnet_id" {
  description = "The subnet ID in which lb members should reside"
  default     = ""
}

variable "floating_ip_pool" {
  description = "The pool from which floating IP addresses should be allocated"
  default     = ""
}

variable "node_ip_addresses" {
  type    = list(string)
  default = []
}

variable "internal_services" {
  type    = list(string)
  default = ["80", "443", "6443"]
}
