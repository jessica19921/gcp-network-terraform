
locals {
  transit_regions        = [local.region1, local.region2, local.region3, ]
  transit_subnet_region1 = google_compute_subnetwork.transit_subnets["${local.transit_prefix}subnet-region1"]
  transit_subnet_region2 = google_compute_subnetwork.transit_subnets["${local.transit_prefix}subnet-region2"]
  transit_subnet_region3 = google_compute_subnetwork.transit_subnets["${local.transit_prefix}subnet-region3"]
}

# network
#---------------------------------

resource "google_compute_network" "transit_vpc" {
  project      = var.project_id_hub
  name         = "${local.transit_prefix}vpc"
  routing_mode = "GLOBAL"
  mtu          = 1460

  auto_create_subnetworks         = false
  delete_default_routes_on_create = false
}

# subnets
#---------------------------------

resource "google_compute_subnetwork" "transit_subnets" {
  for_each = merge(
    local.transit_subnets_region1,
    local.transit_subnets_region2,
    local.transit_subnets_region3
  )
  provider      = google-beta
  project       = var.project_id_hub
  name          = each.key
  network       = google_compute_network.transit_vpc.id
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

module "transit_nat" {
  source                = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-cloudnat"
  for_each              = toset(local.transit_regions)
  project_id            = var.project_id_hub
  region                = each.key
  name                  = "${local.transit_prefix}${each.key}"
  router_network        = google_compute_network.transit_vpc.self_link
  router_create         = true
  config_source_subnets = "ALL_SUBNETWORKS_ALL_PRIMARY_IP_RANGES"
}

# firewall
#---------------------------------

module "transit_firewall" {
  source              = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-vpc-firewall"
  project_id          = var.project_id_hub
  network             = google_compute_network.transit_vpc.name
  admin_ranges        = []
  http_source_ranges  = []
  https_source_ranges = []
  custom_rules = {
    "${local.transit_prefix}internal" = {
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
  }
}
