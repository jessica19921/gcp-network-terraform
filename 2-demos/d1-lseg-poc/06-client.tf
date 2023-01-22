
locals {
  client_regions = [local.region3, ]
  client_subnet  = google_compute_subnetwork.client_subnets["${local.client_prefix}subnet"]
}

# network
#---------------------------------

resource "google_compute_network" "client_vpc" {
  project      = var.project_id_onprem
  name         = "${local.client_prefix}vpc"
  routing_mode = "GLOBAL"
  mtu          = 1460

  auto_create_subnetworks         = false
  delete_default_routes_on_create = false
}

# subnets
#---------------------------------

resource "google_compute_subnetwork" "client_subnets" {
  for_each      = local.client_subnets
  provider      = google-beta
  project       = var.project_id_onprem
  name          = each.key
  network       = google_compute_network.client_vpc.id
  region        = each.value.region
  ip_cidr_range = each.value.ip_cidr_range
  secondary_ip_range = each.value.secondary_ip_range == null ? [] : [
    for name, range in each.value.secondary_ip_range :
    { range_name = name, ip_cidr_range = range }
  ]
  purpose = each.value.purpose
  role    = each.value.role
}

# nat
#---------------------------------

module "client_nat" {
  source                = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-cloudnat"
  for_each              = toset(local.client_regions)
  project_id            = var.project_id_onprem
  region                = each.key
  name                  = "${local.client_prefix}${each.key}"
  router_network        = google_compute_network.client_vpc.self_link
  router_create         = true
  config_source_subnets = "ALL_SUBNETWORKS_ALL_PRIMARY_IP_RANGES"
}

# firewall
#---------------------------------

module "client_vpc_firewall" {
  source              = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-vpc-firewall"
  project_id          = var.project_id_onprem
  network             = google_compute_network.client_vpc.name
  admin_ranges        = []
  http_source_ranges  = []
  https_source_ranges = []
  custom_rules = {
    "${local.client_prefix}internal" = {
      description          = "allow internal"
      direction            = "INGRESS"
      action               = "allow"
      sources              = []
      ranges               = local.netblocks.internal
      targets              = []
      use_service_accounts = false
      rules                = [{ protocol = "all", ports = [] }]
      extra_attributes     = {}
    }
    "${local.client_prefix}ssh" = {
      description          = "allow ssh"
      direction            = "INGRESS"
      action               = "allow"
      sources              = []
      ranges               = ["0.0.0.0/0"]
      targets              = [local.tag_router]
      use_service_accounts = false
      rules                = [{ protocol = "tcp", ports = [22] }]
      extra_attributes     = {}
    }
  }
}

# workload
#---------------------------------

# mcast

module "client_mcast" {
  source     = "../../modules/compute-vm"
  project_id = var.project_id_onprem
  name       = "${local.client_prefix}mcast"
  zone       = "${local.region3}-b"
  tags       = [local.tag_ssh, ]
  boot_disk = {
    image = var.image_multicast
    type  = "pd-ssd"
    size  = 10
  }
  shielded_config = null
  network_interfaces = [{
    network    = google_compute_network.client_vpc.self_link
    subnetwork = local.client_subnet.self_link
    addresses = {
      internal = local.client_mcast_vm_addr
      external = null
    }
    nat       = false
    alias_ips = null
  }]
  metadata_startup_script = local.client_mcast_startup
}

resource "local_file" "client_mcast" {
  content  = module.client_mcast.instance.metadata_startup_script
  filename = "_config/client-mcast.sh"
}

# web
## separate web server for ab probe traffic
## to avoid overlaoding mcast vm python web server
## which freezes under load

module "client_probe" {
  source          = "../../modules/compute-vm"
  project_id      = var.project_id_onprem
  name            = "${local.client_prefix}probe"
  zone            = "${local.region3}-b"
  tags            = [local.tag_ssh, ]
  shielded_config = null
  network_interfaces = [{
    network    = google_compute_network.client_vpc.self_link
    subnetwork = local.client_subnet.self_link
    addresses = {
      internal = local.client_probe_vm_addr
      external = null
    }
    nat       = false
    alias_ips = null
  }]
  metadata_startup_script = local.client_probe_startup
}

resource "local_file" "client_probe" {
  content  = module.client_probe.instance.metadata_startup_script
  filename = "_config/client-probe.sh"
}
