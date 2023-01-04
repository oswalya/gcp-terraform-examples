# Random identifier
resource "random_id" "default" {
  byte_length = 1
}

# Enable service APIs on project
resource "google_project_service" "default" {
  for_each           = toset(local.enabled_apis)
  service            = each.key
  project            = var.project
  disable_on_destroy = false
}

# Create a simple manual VPC network
resource "google_compute_network" "default" {
  project                 = var.project
  name                    = "sample-peer-network-${random_id.default.dec}"
  auto_create_subnetworks = false
  depends_on = [
    google_project_service.default
  ]
}

# Create a private subnet (GKE useable with sec ranges) 
resource "google_compute_subnetwork" "default" {
  name                     = "sample-subnetwork-${random_id.default.dec}"
  ip_cidr_range            = "10.0.0.0/24"
  region                   = var.region
  network                  = google_compute_network.default.id
  private_ip_google_access = true
  secondary_ip_range {
    range_name    = "service-range"
    ip_cidr_range = "192.168.1.0/24"
  }
  secondary_ip_range {
    range_name    = "pod-range"
    ip_cidr_range = "10.1.0.0/19"
  }
}

# Create peering global adress ranges
resource "google_compute_global_address" "private_ip_alloc_1" {
  name          = "private-ip-alloc-${random_id.default.dec}-1"
  project       = var.project
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 24
  address       = "10.100.0.0"
  network       = google_compute_network.default.id
}

resource "google_compute_global_address" "private_ip_alloc_2" {
  name          = "private-ip-alloc-${random_id.default.dec}-2"
  project       = var.project
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 24
  address       = "10.100.1.0"
  network       = google_compute_network.default.id
}

# Create a private service networking connection
resource "google_service_networking_connection" "default" {
  network = google_compute_network.default.id
  service = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [
    google_compute_global_address.private_ip_alloc_1.name,
    google_compute_global_address.private_ip_alloc_2.name
  ]
}

# (Optional) Import or export custom routes
resource "google_compute_network_peering_routes_config" "peering_routes" {
  peering = google_service_networking_connection.default.peering
  network = google_compute_network.default.name

  import_custom_routes = true
  export_custom_routes = true
}
