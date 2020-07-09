output rke-controller-nodes {
  description = "RKE control nodes"
  value       = module.rke-controllers.public_ips
}

output rke-worker-nodes {
  description = "RKE worker nodes"
  value = module.rke-workers.public_ips
}

output rke-public-address {
  description = "Public address for the RKE cluster"
  value       = "${module.controllers-loadbalancer.public_ip}.dnsify.me"
}
