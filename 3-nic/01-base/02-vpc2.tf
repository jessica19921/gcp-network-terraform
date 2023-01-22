
locals {
  vpc2_prefix = "vpc2-"
  vpc2_asn    = 65002
  vpc2_nat_regions = {
    ("${local.vpc2_prefix}nat-eu-region3") = local.us_region1
  }
  vpc2_subnets = {}
}

#========================================================
# network
#========================================================

resource "google_compute_network" "vpc2" {
  project                 = var.project_id_main
  name                    = "vpc2"
  routing_mode            = "GLOBAL"
  auto_create_subnetworks = false
}

#========================================================
# subnets
#========================================================

resource "google_compute_subnetwork" "vpc2_subnets" {
  for_each      = local.vpc2_subnets
  name          = each.key
  ip_cidr_range = each.value.range
  region        = each.value.region
  network       = google_compute_network.vpc2.self_link
  secondary_ip_range = each.value.secondary_ip_range == null ? [] : [
    for name, range in each.value.secondary_ip_range :
    { range_name = name, ip_cidr_range = range }
  ]
  purpose = try(each.value.purpose, null)
  role    = try(each.value.role, null)
}

#========================================================
# addresses
#========================================================


#========================================================
# cloud nat
#========================================================

# router

resource "google_compute_router" "vpc2_nat_routers" {
  for_each = local.vpc2_nat_regions
  name     = each.key
  region   = each.value
  network  = google_compute_network.vpc2.self_link
}

# nat

resource "google_compute_router_nat" "vpc2_nat" {
  for_each                           = google_compute_router.vpc2_nat_routers
  name                               = each.value.name
  router                             = each.value.name
  region                             = each.value.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

#========================================================
# firewall rules
#========================================================

# allow ssh ingress from only iap ranges

resource "google_compute_firewall" "vpc2_ingress_allow_iap" {
  name      = "${local.vpc2_prefix}ingress-allow-iap"
  network   = google_compute_network.vpc2.self_link
  direction = "INGRESS"
  priority  = 100
  allow {
    protocol = "tcp"
    ports    = ["22", ]
  }
  source_ranges = data.google_netblock_ip_ranges.iap_forwarders.cidr_blocks_ipv4
}

# allow ingress from all internal ranges

resource "google_compute_firewall" "vpc2_ingress_allow_internal" {
  name      = "${local.vpc2_prefix}ingress-allow-internal"
  network   = google_compute_network.vpc2.self_link
  direction = "INGRESS"
  priority  = 110
  allow {
    protocol = "all"
  }
  source_ranges = [local.supernet, ]
}

# allow ingress from google health check ranges

resource "google_compute_firewall" "vpc2_ingress_allow_health_check" {
  name      = "${local.vpc2_prefix}ingress-allow-health-check"
  network   = google_compute_network.vpc2.self_link
  direction = "INGRESS"
  priority  = 120
  allow {
    protocol = "all"
  }
  source_ranges = data.google_netblock_ip_ranges.health_checkers.cidr_blocks_ipv4
  target_tags   = ["ingress-allow-health-check", ]
}

# deny ingress from everything

resource "google_compute_firewall" "vpc2_ingress_deny_all" {
  name      = "${local.vpc2_prefix}ingress-deny-all"
  network   = google_compute_network.vpc2.self_link
  direction = "INGRESS"
  priority  = 999
  deny {
    protocol = "all"
  }
  source_ranges = ["0.0.0.0/0", ]
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}
