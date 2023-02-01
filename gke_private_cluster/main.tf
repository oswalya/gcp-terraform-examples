# Random identifier
resource "random_id" "default" {
  byte_length = 1
}

# Enable service APIs on project
resource "google_project_service" "default" {
  for_each           = toset(local.enabled_apis)
  service            = each.key
  project            = var.project_id
  disable_on_destroy = false
}

##########################
# VPC
##########################

# Create a simple manual VPC network
resource "google_compute_network" "default" {
  project                 = var.project_id
  name                    = "gke-network-${random_id.default.dec}"
  auto_create_subnetworks = false
  depends_on = [
    google_project_service.default
  ]
}

# Create a private subnet for GKE with secondary ranges
# and private google API access
resource "google_compute_subnetwork" "default" {
  name                     = "gke-subnetwork-${random_id.default.dec}"
  ip_cidr_range            = local.network_cidr_range
  region                   = var.region
  network                  = google_compute_network.default.id
  private_ip_google_access = true
  secondary_ip_range {
    range_name    = "service-range"
    ip_cidr_range = local.network_alias_service_range
  }
  secondary_ip_range {
    range_name    = "pod-range"
    ip_cidr_range = local.network_alias_pod_range
  }
}

##########################
# Service Account Cluster
# + Basic IAM
##########################

resource "google_service_account" "cluster_service_account" {
  project      = var.project_id
  account_id   = "tf-gke-cluster-sa"
  display_name = "Terraform-managed service account for GKE"
}

resource "google_project_iam_member" "cluster_service_account-log_writer" {
  project = google_service_account.cluster_service_account.project
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.cluster_service_account.email}"
}

resource "google_project_iam_member" "cluster_service_account-metric_writer" {
  project = google_project_iam_member.cluster_service_account-log_writer.project
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.cluster_service_account.email}"
}

resource "google_project_iam_member" "cluster_service_account-monitoring_viewer" {
  project = google_project_iam_member.cluster_service_account-metric_writer.project
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.cluster_service_account.email}"
}

resource "google_project_iam_member" "cluster_service_account-resourceMetadata-writer" {
  project = google_project_iam_member.cluster_service_account-monitoring_viewer.project
  role    = "roles/stackdriver.resourceMetadata.writer"
  member  = "serviceAccount:${google_service_account.cluster_service_account.email}"
}

resource "google_project_iam_member" "cluster_service_account-gcr" {
  project = google_service_account.cluster_service_account.project
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.cluster_service_account.email}"
}

resource "google_project_iam_member" "cluster_service_account-artifact-registry" {
  project = google_service_account.cluster_service_account.project
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.cluster_service_account.email}"
}

##########################
# Cluster Setup
##########################

data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${module.gke.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(module.gke.ca_certificate)
}

module "gke" {
  source                    = "terraform-google-modules/kubernetes-engine/google//modules/beta-private-cluster"
  project_id                = google_service_account.cluster_service_account.project
  name                      = local.cluster_name
  regional                  = true
  region                    = var.region
  network                   = google_compute_network.default.name
  subnetwork                = google_compute_subnetwork.default.name
  ip_range_pods             = "pod-range"
  ip_range_services         = "service-range"
  create_service_account    = false
  service_account           = google_service_account.cluster_service_account.email
  enable_private_endpoint   = true
  enable_private_nodes      = true
  master_ipv4_cidr_block    = local.master_ipv4_cidr_block
  default_max_pods_per_node = 20
  #release_channel            = "REGULAR"
  remove_default_node_pool   = true
  enable_shielded_nodes      = true
  http_load_balancing        = true
  horizontal_pod_autoscaling = true
  network_policy             = true
  istio                      = false

  node_pools = [
    {
      name                  = "demo1-pool-01"
      node_locations        = "${var.region}-a"
      machine_type          = "e2-standard-2"
      min_count             = 1
      max_count             = 1
      local_ssd_count       = 0
      disk_size_gb          = 100
      disk_type             = "pd-standard"
      auto_repair           = true
      auto_upgrade          = true
      service_account       = google_service_account.cluster_service_account.email
      preemptible           = true
      enable_shielded_nodes = true
      enable_secure_boot    = true
      max_pods_per_node     = 100
    },
  ]

  master_authorized_networks = [
    {
      cidr_block   = google_compute_subnetwork.default.ip_cidr_range
      display_name = "VPC"
    },
  ]
}

##########################
# (Cluster) Firewalls
##########################

##########################
# Required for clusters when VPCs enforce
# a default-deny egress rule
# allow egress to all cluster cidrs
##########################
resource "google_compute_firewall" "intra_egress" {
  name        = "gke-${substr(module.gke.name, 0, min(25, length(module.gke.name)))}-intra-cluster-egress"
  description = "Allow pods to communicate with each other and the master"
  project     = google_compute_network.default.project
  network     = google_compute_network.default.name
  priority    = local.default_fw_priority
  direction   = "EGRESS"
  # log_config {
  #   metadata = INCLUDE_ALL_METADATA
  # }

  target_tags = [local.cluster_network_tag]
  destination_ranges = [
    module.gke.master_ipv4_cidr_block,
    google_compute_subnetwork.default.ip_cidr_range,
    local.network_alias_pod_range,
    local.network_alias_service_range
  ]

  allow { protocol = "tcp" }
  allow { protocol = "udp" }
  allow { protocol = "icmp" }
}

##########################
#  Allow GKE master to hit non 443 ports for
#  Webhooks/Admission Controllers
#  https://github.com/kubernetes/kubernetes/issues/79739
##########################
resource "google_compute_firewall" "master_webhooks" {
  name        = "gke-${substr(module.gke.name, 0, min(25, length(module.gke.name)))}-webhooks"
  description = "Allow master to hit pods for admission controllers/webhooks"
  project     = google_compute_network.default.project
  network     = google_compute_network.default.name
  priority    = local.default_fw_priority
  direction   = "INGRESS"

  source_ranges = [module.gke.master_ipv4_cidr_block]
  source_tags   = []
  target_tags   = [local.cluster_network_tag]

  allow {
    protocol = "tcp"
    ports    = ["8443", "9443", "15017"]
  }
}

##########################
# IAP
##########################

resource "google_compute_firewall" "allow_from_iap_to_instances" {
  project = google_compute_network.default.project
  name    = "iap-${random_id.default.dec}-allow-ingress"
  network = google_compute_network.default.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # https://cloud.google.com/iap/docs/using-tcp-forwarding#before_you_begin
  # This is the netblock needed to forward to the instances
  source_ranges = ["35.235.240.0/20"]
}

resource "google_iap_tunnel_instance_iam_binding" "enable_iap" {
  project  = google_compute_instance_from_template.tunnelvm.project
  zone     = google_compute_instance_from_template.tunnelvm.zone
  instance = google_compute_instance_from_template.tunnelvm.name
  role     = "roles/iap.tunnelResourceAccessor"
  members  = var.tunnel_user
}

##########################
# Bastion Host
# NOTE: 
# KMS / Encryption has not been added here for simplicity,
# but should be added beyond a playground
##########################

resource "google_service_account" "bastion_service_account" {
  project      = google_compute_network.default.project
  account_id   = "tf-bastion-sa"
  display_name = "Terraform-managed service account for bastion VM"
}

module "instance_template" {
  source = "terraform-google-modules/vm/google//modules/instance_template"

  project_id         = google_compute_network.default.project
  machine_type       = "e2-small"
  subnetwork         = google_compute_subnetwork.default.self_link
  enable_shielded_vm = true
  service_account = {
    email  = google_service_account.bastion_service_account.email
    scopes = ["cloud-platform"]
  }
  metadata = {
    enable-oslogin = "TRUE"
  }

  source_image         = "debian-11-bullseye-v20221206"
  source_image_family  = "debian-11"
  source_image_project = "debian-cloud"

  startup_script = <<EOF
  #! /bin/bash
  apt-get update
  apt-get install -y tinyproxy
  grep -qxF 'Allow localhost' /etc/tinyproxy/tinyproxy.conf || echo 'Allow localhost' >> /etc/tinyproxy/tinyproxy.conf
  service tinyproxy restart
  EOF
}

resource "google_compute_instance_from_template" "tunnelvm" {
  name    = "bastion-${random_id.default.dec}"
  project = google_compute_subnetwork.default.project
  zone    = "${var.region}-a"
  network_interface {
    subnetwork = google_compute_subnetwork.default.self_link
  }
  source_instance_template = module.instance_template.self_link
}

##########################
# Bastion Host
# IAM
##########################

# Additional OS login IAM bindings.
# https://cloud.google.com/compute/docs/instances/managing-instance-access#granting_os_login_iam_roles
resource "google_service_account_iam_binding" "bastion_service_account_user" {
  service_account_id = google_service_account.bastion_service_account.id
  role               = "roles/iam.serviceAccountUser"
  members            = var.tunnel_user
}

resource "google_project_iam_member" "os_login_bindings" {
  for_each = toset(var.tunnel_user)
  project  = google_compute_network.default.project
  role     = "roles/compute.osLogin"
  member   = each.key
}

##########################
# Cloud NAT for package installations
# + external pods
##########################

resource "google_compute_router" "default" {
  name    = "cloud-router-${random_id.default.dec}"
  project = google_compute_network.default.project
  region  = google_compute_subnetwork.default.region
  network = google_compute_network.default.id
  bgp {
    asn = "64514"
  }
}

resource "google_compute_address" "nat" {
  name    = "nat-address-${random_id.default.dec}"
  project = google_compute_network.default.project
  region  = google_compute_subnetwork.default.region
}

resource "google_compute_router_nat" "default" {
  project                            = google_compute_router.default.project
  region                             = google_compute_router.default.region
  name                               = "cloud-router-nat-${random_id.default.dec}"
  router                             = google_compute_router.default.name
  nat_ip_allocate_option             = "MANUAL_ONLY"
  nat_ips                            = [google_compute_address.nat.self_link]
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  min_ports_per_vm                   = 1000
  tcp_established_idle_timeout_sec   = 300

  subnetwork {
    name                    = google_compute_subnetwork.default.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
