
locals {
  vpc1_prefix = "vpc1-"
  vpc1_asn    = 65001
  vpc1_nat_regions = {
    ("${local.vpc1_prefix}nat-eu-region1") = local.eu_region1
    ("${local.vpc1_prefix}nat-ap-region1") = local.ap_region1
    ("${local.vpc1_prefix}nat-us-region1") = local.us_region1
    ("${local.vpc1_prefix}nat-us-region2") = local.us_region2
    ("${local.vpc1_prefix}nat-ap-region2") = local.ap_region2
    ("${local.vpc1_prefix}nat-eu-region2") = local.eu_region2
    ("${local.vpc1_prefix}nat-us-region3") = local.us_region3
    ("${local.vpc1_prefix}nat-ap-region3") = local.ap_region3
    ("${local.vpc1_prefix}nat-eu-region3") = local.eu_region3
  }
  vpc1_browse_map = {
    ("${local.vpc1_prefix}browse-eu") = { region = local.eu_region1, startup = local.vpc1_web_eu_startup }
    ("${local.vpc1_prefix}browse-us") = { region = local.us_region1, startup = local.vpc1_web_us_startup }
    ("${local.vpc1_prefix}browse-ap") = { region = local.ap_region1, startup = local.vpc1_web_ap_startup }
  }
  vpc1_cart_map = {
    ("${local.vpc1_prefix}cart-eu") = { region = local.eu_region1, startup = local.vpc1_web_eu_startup }
    ("${local.vpc1_prefix}cart-us") = { region = local.us_region1, startup = local.vpc1_web_us_startup }
    ("${local.vpc1_prefix}cart-ap") = { region = local.ap_region1, startup = local.vpc1_web_ap_startup }
  }
  vpc1_checkout_map = {
    ("${local.vpc1_prefix}checkout-eu") = { region = local.eu_region1, startup = local.vpc1_web_eu_startup }
    ("${local.vpc1_prefix}checkout-us") = { region = local.us_region1, startup = local.vpc1_web_us_startup }
    ("${local.vpc1_prefix}checkout-ap") = { region = local.ap_region1, startup = local.vpc1_web_ap_startup }
  }
  vpc1_feeds_map = {
    ("${local.vpc1_prefix}feeds-eu") = { region = local.eu_region1, startup = local.vpc1_web_eu_startup }
    ("${local.vpc1_prefix}feeds-us") = { region = local.us_region1, startup = local.vpc1_web_us_startup }
    ("${local.vpc1_prefix}feeds-ap") = { region = local.ap_region1, startup = local.vpc1_web_ap_startup }
  }
  vpc1_db_map = {
    ("${local.vpc1_prefix}db-eu") = { region = local.eu_region1, startup = local.vpc1_db_eu_startup }
    ("${local.vpc1_prefix}db-us") = { region = local.us_region1, startup = local.vpc1_db_us_startup }
    ("${local.vpc1_prefix}db-ap") = { region = local.ap_region1, startup = local.vpc1_db_ap_startup }
  }
  vpc1_web_eu_startup = templatefile("scripts/web.sh", { PORT = local.named_port.port, TARGETS = ["${local.vpc1_prefix}db-eu/"] })
  vpc1_web_us_startup = templatefile("scripts/web.sh", { PORT = local.named_port.port, TARGETS = ["${local.vpc1_prefix}db-us/"] })
  vpc1_web_ap_startup = templatefile("scripts/web.sh", { PORT = local.named_port.port, TARGETS = ["${local.vpc1_prefix}db-ap/"] })
  vpc1_db_eu_startup  = templatefile("scripts/web.sh", { PORT = local.named_port.port, TARGETS = ["${local.vpc1_prefix}db-us/"] })
  vpc1_db_us_startup  = templatefile("scripts/web.sh", { PORT = local.named_port.port, TARGETS = [] })
  vpc1_db_ap_startup  = templatefile("scripts/web.sh", { PORT = local.named_port.port, TARGETS = ["${local.vpc1_prefix}db-us/"] })
  vpc1_probe_eu_startup = templatefile("scripts/probe.sh", {
    TARGETS_INSIGHT = []
    TARGETS_SLO = [
      "${google_compute_global_address.vpc1_gclb_global.address}/",
      "${google_compute_address.vpc1_gclb_eu_region1.address}/",
      "${google_compute_global_address.vpc1_tcp_global.address}/",
    ]
  })
  vpc1_probe_us_startup = templatefile("scripts/probe.sh", {
    TARGETS_INSIGHT = []
    TARGETS_SLO = [
      "${google_compute_global_address.vpc1_gclb_global.address}/",
      "${google_compute_address.vpc1_gclb_eu_region1.address}/",
      "${google_compute_global_address.vpc1_tcp_global.address}/",
    ]
  })
  vpc1_probe_ap_startup = templatefile("scripts/probe.sh", {
    TARGETS_INSIGHT = []
    TARGETS_SLO = [
      "${google_compute_global_address.vpc1_gclb_global.address}/",
      "${google_compute_global_address.vpc1_tcp_global.address}/",
    ]
  })
  vpc1_probes_config = {
    probe1 = { zone = "${local.eu_region3}-b", startup = local.vpc1_probe_eu_startup }
    probe2 = { zone = "${local.us_region3}-b", startup = local.vpc1_probe_us_startup }
    probe3 = { zone = "${local.ap_region3}-b", startup = local.vpc1_probe_ap_startup }
  }
}

#========================================================
# network
#========================================================

resource "google_compute_network" "vpc1" {
  name                    = "vpc1"
  routing_mode            = "GLOBAL"
  auto_create_subnetworks = true
}

#========================================================
# subnets
#========================================================

# database subnets

data "google_compute_subnetwork" "vpc1_db_subnets" {
  for_each = local.vpc1_db_map
  name     = google_compute_network.vpc1.name
  region   = each.value.region
}

#========================================================
# addresses
#========================================================

# gclb global

resource "google_compute_global_address" "vpc1_gclb_global" {
  name        = "${local.vpc1_prefix}gclb-global"
  description = "global static address for gclb"
}

# gclb regional

resource "google_compute_address" "vpc1_gclb_eu_region1" {
  name         = "${local.vpc1_prefix}gclb-eu-region1"
  description  = "regional static address for gclb"
  region       = local.eu_region1
  network_tier = "STANDARD"
}

# tcp global

resource "google_compute_global_address" "vpc1_tcp_global" {
  name        = "${local.vpc1_prefix}tcp-global"
  description = "global static address for tcp proxy"
}

# databases

resource "google_compute_address" "vpc1_db_static_addresses" {
  for_each     = local.vpc1_db_map
  name         = each.key
  region       = each.value.region
  subnetwork   = google_compute_network.vpc1.name
  address_type = "INTERNAL"
  address      = cidrhost(data.google_compute_subnetwork.vpc1_db_subnets[each.key].ip_cidr_range, 100)
}

#========================================================
# cloud nat
#========================================================

# router

resource "google_compute_router" "vpc1_nat_routers" {
  for_each = local.vpc1_nat_regions
  name     = each.key
  region   = each.value
  network  = google_compute_network.vpc1.self_link
}

# nat

resource "google_compute_router_nat" "vpc1_nat" {
  for_each                           = google_compute_router.vpc1_nat_routers
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

resource "google_compute_firewall" "vpc1_ingress_allow_iap" {
  name      = "${local.vpc1_prefix}ingress-allow-iap"
  network   = google_compute_network.vpc1.self_link
  direction = "INGRESS"
  priority  = 100
  allow {
    protocol = "tcp"
    ports    = ["22", ]
  }
  source_ranges = data.google_netblock_ip_ranges.iap_forwarders.cidr_blocks_ipv4
}

# allow ingress from all internal ranges

resource "google_compute_firewall" "vpc1_ingress_allow_internal" {
  name      = "${local.vpc1_prefix}ingress-allow-internal"
  network   = google_compute_network.vpc1.self_link
  direction = "INGRESS"
  priority  = 110
  allow {
    protocol = "all"
  }
  source_ranges = [local.supernet, ]
}

# allow ingress from google health check ranges

resource "google_compute_firewall" "vpc1_ingress_allow_health_check" {
  name      = "${local.vpc1_prefix}ingress-allow-health-check"
  network   = google_compute_network.vpc1.self_link
  direction = "INGRESS"
  priority  = 120
  allow {
    protocol = "all"
  }
  source_ranges = data.google_netblock_ip_ranges.health_checkers.cidr_blocks_ipv4
  target_tags   = ["ingress-allow-health-check", ]
}

# deny ingress from everything

resource "google_compute_firewall" "vpc1_ingress_deny_all" {
  name      = "${local.vpc1_prefix}ingress-deny-all"
  network   = google_compute_network.vpc1.self_link
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

#========================================================
# instance templates
#========================================================

# instance templates created from the compute images

resource "google_compute_instance_template" "vpc1_instance_templates" {
  for_each = merge(
    local.vpc1_browse_map,
    local.vpc1_cart_map,
    local.vpc1_checkout_map,
    local.vpc1_feeds_map
  )
  name         = each.key
  region       = each.value.region
  machine_type = var.machine_type
  tags         = ["ingress-allow-health-check", ]
  network_interface {
    subnetwork = google_compute_network.vpc1.name
  }
  disk {
    source_image = var.image_debian
    auto_delete  = true
    boot         = true
  }
  service_account {
    scopes = ["cloud-platform"]
  }
  metadata_startup_script = each.value.startup
  lifecycle {
    create_before_destroy = true
    ignore_changes        = all
  }
}

#========================================================
# health check
#========================================================

resource "google_compute_health_check" "vpc1" {
  name = "vpc1"
  http_health_check {
    port = local.named_port.port
  }
}

#========================================================
# external https load balancer
#========================================================

# instance groups

resource "google_compute_instance_group_manager" "vpc1_gclb_instance_groups" {
  for_each           = google_compute_instance_template.vpc1_instance_templates
  name               = each.key
  base_instance_name = each.key
  zone               = "${each.value.region}-b"
  version {
    instance_template = each.value.self_link
  }
  named_port {
    name = local.named_port.name
    port = local.named_port.port
  }
}

resource "google_compute_autoscaler" "vpc1_gclb_autoscalers" {
  for_each = google_compute_instance_group_manager.vpc1_gclb_instance_groups
  name     = each.key
  zone     = each.value.zone
  target   = each.value.self_link
  autoscaling_policy {
    min_replicas    = 1
    max_replicas    = 3
    cooldown_period = 60
    cpu_utilization {
      target = "0.7"
    }
  }
}

# backend services

locals {
  vpc1_gclb_backend_services = {
    ("${local.vpc1_prefix}browse")   = local.vpc1_browse_map
    ("${local.vpc1_prefix}cart")     = local.vpc1_cart_map
    ("${local.vpc1_prefix}checkout") = local.vpc1_checkout_map
    ("${local.vpc1_prefix}feeds")    = local.vpc1_feeds_map
  }
}

resource "google_compute_backend_service" "vpc1_gclb_backend_services" {
  for_each      = local.vpc1_gclb_backend_services
  provider      = google-beta
  name          = each.key
  port_name     = local.named_port.name
  protocol      = "HTTP"
  health_checks = [google_compute_health_check.vpc1.self_link]
  dynamic "backend" {
    for_each = each.value
    iterator = backend
    content {
      group           = google_compute_instance_group_manager.vpc1_gclb_instance_groups[backend.key].instance_group
      balancing_mode  = "UTILIZATION"
      max_utilization = "0.8"
      capacity_scaler = "1"
    }
  }
}

# url map

resource "google_compute_url_map" "vpc1_shopping_site_url_map" {
  name            = "${local.vpc1_prefix}shopping-site-url-map"
  default_service = google_compute_backend_service.vpc1_gclb_backend_services["${local.vpc1_prefix}browse"].self_link
  host_rule {
    hosts        = ["*"]
    path_matcher = "allpaths"
  }
  path_matcher {
    name            = "allpaths"
    default_service = google_compute_backend_service.vpc1_gclb_backend_services["${local.vpc1_prefix}browse"].self_link
    path_rule {
      paths   = ["/browse/*", ]
      service = google_compute_backend_service.vpc1_gclb_backend_services["${local.vpc1_prefix}browse"].self_link
    }
    path_rule {
      paths   = ["/cart/*"]
      service = google_compute_backend_service.vpc1_gclb_backend_services["${local.vpc1_prefix}cart"].self_link
    }
    path_rule {
      paths   = ["/checkout/*", ]
      service = google_compute_backend_service.vpc1_gclb_backend_services["${local.vpc1_prefix}checkout"].self_link
    }
    path_rule {
      paths   = ["/feeds/*", ]
      service = google_compute_backend_service.vpc1_gclb_backend_services["${local.vpc1_prefix}feeds"].self_link
    }
  }
}

# http proxy

resource "google_compute_target_http_proxy" "vpc1_gclb_http_proxy" {
  name    = "${local.vpc1_prefix}gclb-http-proxy"
  url_map = google_compute_url_map.vpc1_shopping_site_url_map.self_link
}

# forwarding rule

resource "google_compute_global_forwarding_rule" "vpc1_gclb_shopping_site_fr" {
  name        = "${local.vpc1_prefix}gclb-shopping-site-fr"
  target      = google_compute_target_http_proxy.vpc1_gclb_http_proxy.self_link
  ip_address  = google_compute_global_address.vpc1_gclb_global.address
  ip_protocol = "TCP"
  port_range  = 80
}

#========================================================
# databases
#========================================================

resource "google_compute_instance" "vpc1_db" {
  for_each                  = local.vpc1_db_map
  name                      = each.key
  machine_type              = var.machine_type
  zone                      = "${each.value.region}-b"
  metadata_startup_script   = each.value.startup
  allow_stopping_for_update = true
  boot_disk {
    initialize_params {
      image = var.image_debian
    }
  }
  network_interface {
    subnetwork = google_compute_network.vpc1.name
    network_ip = google_compute_address.vpc1_db_static_addresses[each.key].address
  }
  service_account {
    scopes = ["cloud-platform"]
  }
}

#========================================================
# probes
#========================================================

resource "google_compute_instance" "vpc1_probes" {
  for_each                  = local.vpc1_probes_config
  name                      = "${local.vpc1_prefix}${each.key}"
  machine_type              = var.machine_type
  zone                      = each.value.zone
  metadata_startup_script   = each.value.startup
  allow_stopping_for_update = true
  boot_disk {
    initialize_params {
      image = var.image_debian
    }
  }
  network_interface {
    subnetwork = google_compute_network.vpc1.name
    dynamic "access_config" {
      for_each = try(each.value.nat_ip, null) == null ? [] : [0]
      content {
        nat_ip = try(each.value.nat_ip, null)
      }
    }
  }
  service_account {
    scopes = ["cloud-platform"]
  }
}
