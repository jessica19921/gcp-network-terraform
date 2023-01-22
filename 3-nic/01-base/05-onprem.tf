
locals {
  onprem_prefix = "onprem-"
  #onprem_asn    = 65010
  onprem_nat_regions = {
    ("${local.onprem_prefix}nat-eu-region2") = local.eu_region2
  }
  onprem_subnets = {
    ("${local.onprem_prefix}eu-region2-subnet1") = { range = "10.10.10.0/24", region = local.eu_region2, log = false, }
  }
}

#========================================================
# network
#========================================================

resource "google_compute_network" "onprem" {
  project                 = var.project_id_main
  name                    = "onprem"
  routing_mode            = "GLOBAL"
  auto_create_subnetworks = false
}

#========================================================
# subnets
#========================================================

resource "google_compute_subnetwork" "onprem_subnets" {
  for_each      = local.onprem_subnets
  name          = each.key
  ip_cidr_range = each.value.range
  region        = each.value.region
  network       = google_compute_network.onprem.self_link
}

#========================================================
# cloud nat
#========================================================

# router

resource "google_compute_router" "onprem_nat_routers" {
  for_each = local.onprem_nat_regions
  name     = each.key
  region   = each.value
  network  = google_compute_network.onprem.self_link
}

# nat

resource "google_compute_router_nat" "onprem_nat" {
  for_each                           = google_compute_router.onprem_nat_routers
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

resource "google_compute_firewall" "onprem_ingress_allow_iap" {
  name      = "${local.onprem_prefix}ingress-allow-iap"
  network   = google_compute_network.onprem.self_link
  direction = "INGRESS"
  allow {
    protocol = "tcp"
    ports    = ["22", ]
  }
  source_ranges = data.google_netblock_ip_ranges.iap_forwarders.cidr_blocks_ipv4
}

# allow ingress from all internal ranges

resource "google_compute_firewall" "onprem_ingress_allow_internal" {
  name      = "${local.onprem_prefix}ingress-allow-internal"
  network   = google_compute_network.onprem.self_link
  direction = "INGRESS"
  allow {
    protocol = "all"
  }
  source_ranges = [local.supernet, ]
}

# allow egress to internal ranges

resource "google_compute_firewall" "onprem_egress_allow_internal" {
  name      = "${local.onprem_prefix}egress-allow-internal"
  network   = google_compute_network.onprem.self_link
  direction = "EGRESS"
  priority  = "900"
  allow {
    protocol = "all"
  }
  target_tags = ["egress-allow-internal", ]
}

# deny egress to everything else

resource "google_compute_firewall" "onprem_egress_deny_external" {
  name      = "${local.onprem_prefix}egress-deny-external"
  network   = google_compute_network.onprem.self_link
  direction = "EGRESS"
  priority  = "1000"
  deny {
    protocol = "all"
  }
  target_tags = ["egress-deny-external", ]
}
