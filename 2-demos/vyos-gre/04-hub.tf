
locals {
  hub_regions    = [local.hub_eu_region, local.hub_us_region, ]
  hub_eu_subnet1 = google_compute_subnetwork.hub_subnets["${local.hub_prefix}eu-subnet1"]
  hub_eu_subnet2 = google_compute_subnetwork.hub_subnets["${local.hub_prefix}eu-subnet2"]
  hub_eu_subnet3 = google_compute_subnetwork.hub_subnets["${local.hub_prefix}eu-subnet3"]
  hub_us_subnet1 = google_compute_subnetwork.hub_subnets["${local.hub_prefix}us-subnet1"]
  hub_us_subnet2 = google_compute_subnetwork.hub_subnets["${local.hub_prefix}us-subnet2"]
  hub_us_subnet3 = google_compute_subnetwork.hub_subnets["${local.hub_prefix}us-subnet3"]
}

# network
#---------------------------------

resource "google_compute_network" "hub_vpc" {
  project      = var.project_id_hub
  name         = "${local.hub_prefix}vpc"
  routing_mode = "GLOBAL"
  mtu          = 1460

  auto_create_subnetworks         = false
  delete_default_routes_on_create = false
}

# subnets
#---------------------------------

resource "google_compute_subnetwork" "hub_subnets" {
  for_each      = local.hub_subnets
  provider      = google-beta
  project       = var.project_id_hub
  name          = each.key
  network       = google_compute_network.hub_vpc.id
  region        = each.value.region
  ip_cidr_range = each.value.ip_cidr_range
  secondary_ip_range = each.value.secondary_ip_range == null ? [] : [
    for name, range in each.value.secondary_ip_range :
    { range_name = name, ip_cidr_range = range }
  ]
  purpose = each.value.purpose
  role    = each.value.role
}

# addresses
#---------------------------------

resource "google_compute_address" "hub_eu_subnet1_addresses" {
  for_each     = local.hub_eu_subnet1_addresses
  project      = var.project_id_hub
  name         = each.key
  subnetwork   = local.hub_eu_subnet1.id
  address_type = "INTERNAL"
  address      = each.value.addr
  region       = local.hub_eu_region
}

resource "google_compute_address" "hub_us_subnet1_addresses" {
  for_each     = local.hub_us_subnet1_addresses
  project      = var.project_id_hub
  name         = each.key
  subnetwork   = local.hub_us_subnet1.id
  address_type = "INTERNAL"
  address      = each.value.addr
  region       = local.hub_us_region
}

# nat
#---------------------------------

module "hub_nat" {
  source                = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-cloudnat"
  for_each              = toset(local.hub_regions)
  project_id            = var.project_id_hub
  region                = each.key
  name                  = "${local.hub_prefix}${each.key}"
  router_network        = google_compute_network.hub_vpc.self_link
  router_create         = true
  config_source_subnets = "ALL_SUBNETWORKS_ALL_PRIMARY_IP_RANGES"
}

# firewall
#---------------------------------

module "hub_vpc_firewall" {
  source              = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-vpc-firewall"
  project_id          = var.project_id_hub
  network             = google_compute_network.hub_vpc.name
  admin_ranges        = []
  http_source_ranges  = []
  https_source_ranges = []
  custom_rules = {
    "${local.hub_prefix}internal" = {
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
    "${local.hub_prefix}dns-egress" = {
      description          = "allow dns egress proxy"
      direction            = "INGRESS"
      action               = "allow"
      sources              = []
      ranges               = local.netblocks.dns
      targets              = [local.tag_dns, local.tag_router]
      use_service_accounts = false
      rules                = [{ protocol = "all", ports = [] }]
      extra_attributes     = {}
    }
    "${local.hub_prefix}ssh" = {
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
    "${local.hub_prefix}vpn" = {
      description          = "allow nat-t and esp"
      direction            = "INGRESS"
      action               = "allow"
      sources              = []
      ranges               = ["0.0.0.0/0"]
      targets              = [local.tag_router]
      use_service_accounts = false
      rules = [
        { protocol = "udp", ports = [500, 4500] },
        { protocol = "esp", ports = [] }
      ]
      extra_attributes = {}
    }
    "${local.hub_prefix}gfe" = {
      description          = "allow gfe"
      direction            = "INGRESS"
      action               = "allow"
      sources              = []
      ranges               = local.netblocks.gfe
      targets              = [local.tag_gfe]
      use_service_accounts = false
      rules                = [{ protocol = "all", ports = [] }]
      extra_attributes     = {}
    }
  }
}
