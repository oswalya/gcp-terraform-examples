locals {
  enabled_apis = [
    "secretmanager.googleapis.com",
    "container.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iamcredentials.googleapis.com",
    "cloudbilling.googleapis.com",
    "billingbudgets.googleapis.com",
    "cloudkms.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "servicenetworking.googleapis.com",
    "iap.googleapis.com",
    "oslogin.googleapis.com"
  ]
  default_fw_priority         = 1000
  cluster_name                = "cluster-demo1-${random_id.default.dec}"
  cluster_network_tag         = "gke-${local.cluster_name}"
  master_ipv4_cidr_block      = "172.16.0.0/28"
  network_cidr_range          = "10.0.0.0/24"
  network_alias_pod_range     = "10.1.0.0/19"
  network_alias_service_range = "192.168.1.0/24"
}
