variable "cluster_name" {
  description = "Name of the cluster"
}

variable "subnet_range" {
  description = "Private IP space to be used in CIDR format"
  default     = "172.31.0.0/24"
}

variable "external_network_id" {
  description = "The ID of the external network providing ingress / egress"
  default     = ""
}
