
locals {
  vpc3_prefix    = "vpc3-"
  vpc3_asn       = 65003
  vpc3_supernet  = "10.1.0.0/16"
  vpc3_subnet1   = "10.1.0.0/24"
  vpc3_subnet2   = "10.2.0.0/24"
  vpc3_subnet3   = "10.3.0.0/24"
  vpc3_subnet4   = "10.4.0.0/24"
  vpc3_subnet5   = "10.5.0.0/24"
  vpc3_subnet6   = "10.6.0.0/24"
  vpc3_subnet7   = "10.7.0.0/24"
  vpc3_subnet8   = "10.8.0.0/24"
  vpc3_subnet9   = "10.9.0.0/24"
  vpc3_subnet1_x = "10.0.1.0/24"
  vpc3_subnet2_x = "10.0.2.0/24"
  vpc3_subnet3_x = "10.0.3.0/24"
  vpc3_subnet4_x = "10.0.4.0/24"
  vpc3_subnet5_x = "10.0.5.0/24"
  vpc3_subnet6_x = "10.0.6.0/24"
  vpc3_subnet7_x = "10.0.7.0/24"
  vpc3_subnet8_x = "10.0.8.0/24"
  vpc3_subnet9_x = "10.0.9.0/24"
  vpc3_nat_regions = {
    "${local.vpc3_prefix}nat-eu-region1" = local.eu_region1
    "${local.vpc3_prefix}nat-eu-region2" = local.eu_region2
    "${local.vpc3_prefix}nat-eu-region3" = local.eu_region3
    "${local.vpc3_prefix}nat-us-region1" = local.us_region1
    "${local.vpc3_prefix}nat-us-region2" = local.us_region2
    "${local.vpc3_prefix}nat-us-region3" = local.us_region3
    "${local.vpc3_prefix}nat-ap-region1" = local.ap_region1
    "${local.vpc3_prefix}nat-ap-region2" = local.ap_region2
    "${local.vpc3_prefix}nat-ap-region3" = local.ap_region3
  }
  vpc3_subnets = {
    subnet1   = { range = local.vpc3_subnet1, region = local.ap_region1, log = false, }
    subnet2   = { range = local.vpc3_subnet2, region = local.eu_region3, log = false, }
    subnet3   = { range = local.vpc3_subnet3, region = local.eu_region1, log = false, }
    subnet4   = { range = local.vpc3_subnet4, region = local.eu_region1, log = false, }
    subnet5   = { range = local.vpc3_subnet5, region = local.us_region1, log = false, }
    subnet6   = { range = local.vpc3_subnet6, region = local.us_region1, log = false, }
    subnet7   = { range = local.vpc3_subnet7, region = local.ap_region1, log = false, }
    subnet8   = { range = local.vpc3_subnet8, region = local.us_region2, log = false, }
    subnet9   = { range = local.vpc3_subnet9, region = local.us_region3, log = false, }
    subnet1-x = { range = local.vpc3_subnet1_x, region = local.ap_region3, log = false, }
    subnet2-x = { range = local.vpc3_subnet2_x, region = local.ap_region2, log = false, }
    subnet3-x = { range = local.vpc3_subnet3_x, region = local.us_region3, log = false, }
    subnet4-x = { range = local.vpc3_subnet4_x, region = local.ap_region1, log = false, }
    subnet5-x = { range = local.vpc3_subnet5_x, region = local.eu_region2, log = false, }
    subnet6-x = { range = local.vpc3_subnet6_x, region = local.us_region1, log = false, }
    subnet7-x = { range = local.vpc3_subnet7_x, region = local.us_region2, log = false, }
    subnet8-x = { range = local.vpc3_subnet8_x, region = local.eu_region2, log = false, }
    subnet9-x = { range = local.vpc3_subnet9_x, region = local.ap_region1, log = false, }
  }
  vpc3_vm_config = {
    # probers
    vm1     = { zone = "b", subnet = "subnet1", startup = local.vpc3_vm1_startup, tags = ["web-app1"] }
    vm3     = { zone = "b", subnet = "subnet3", startup = local.vpc3_vm3_startup, tags = ["server3"] }
    vm5     = { zone = "b", subnet = "subnet5", startup = local.vpc3_vm5_startup, tags = ["server5"] }
    vm7     = { zone = "c", subnet = "subnet7", startup = local.vpc3_vm7_startup, tags = ["server7"] }
    probe5a = { zone = "b", subnet = "subnet5-x", startup = local.vpc3_probe5_startup }
    probe5b = { zone = "b", subnet = "subnet5-x", startup = local.vpc3_probe5_startup }
    probe6  = { zone = "c", subnet = "subnet6-x", startup = local.vpc3_probe6_startup }
    probe7  = { zone = "c", subnet = "subnet7-x", startup = local.vpc3_probe7_startup }
    # targets
    vm2          = { zone = "b", subnet = "subnet2", startup = local.vpc3_basic_startup, tags = ["web-app2"] }
    vm4          = { zone = "b", subnet = "subnet4", startup = local.vpc3_basic_startup, tags = ["db-srv4"] }
    vm6          = { zone = "b", subnet = "subnet6", startup = local.vpc3_basic_startup, tags = ["auth-srv6"] }
    vm8          = { zone = "c", subnet = "subnet8", startup = local.vpc3_basic_startup, tags = ["anthos8-fw", "db8-mysql"] }
    http-server  = { zone = "b", subnet = "subnet1-x", startup = local.vpc3_basic_startup, tags = ["http-server"] }
    https-server = { zone = "b", subnet = "subnet2-x", startup = local.vpc3_basic_startup, tags = ["https-server"] }
    proxy-server = { zone = "b", subnet = "subnet3-x", startup = local.vpc3_basic_startup, tags = ["proxy-server"] }
  }
  vpc3_basic_startup = templatefile("scripts/basic.sh", {})
  vpc3_vm1_startup = templatefile("scripts/probe.sh", {
    TARGETS_INSIGHT = [
      { host = "${local.vpc3_prefix}vm2", protocol = "tcp", p = 80, }
    ]
    TARGETS_SLO = [
      "${local.vpc3_prefix}vm3/",
      "${local.vpc3_prefix}vm4/",
      "${local.vpc3_prefix}vm5/",
      "${local.vpc3_prefix}vm7/",
    ]
  })
  vpc3_vm3_startup = templatefile("scripts/probe.sh", {
    TARGETS_INSIGHT = [
      { host = "${local.vpc3_prefix}vm4", protocol = "tcp", p = 80, },
      { host = "${local.vpc3_prefix}vm4", protocol = "tcp", p = 443, },
      { host = "${local.vpc3_prefix}vm6", protocol = "tcp", p = 3389, },
    ]
    TARGETS_SLO = [
      "${local.vpc3_prefix}vm1/",
      "${local.vpc3_prefix}vm4/",
      "${local.vpc3_prefix}vm5/",
      "${local.vpc3_prefix}vm7/",
    ]
  })
  vpc3_vm5_startup = templatefile("scripts/probe.sh", {
    TARGETS_INSIGHT = [
      { host = "${local.vpc3_prefix}vm6", protocol = "tcp", p = 3389, }
    ]
    TARGETS_SLO = [
      "${local.vpc3_prefix}vm1/",
      "${local.vpc3_prefix}vm2/",
      "${local.vpc3_prefix}vm7/",
      "${local.vpc3_prefix}vm8/",
    ]
  })
  vpc3_vm7_startup = templatefile("scripts/probe.sh", {
    TARGETS_INSIGHT = [
      { host = "${local.vpc3_prefix}vm8", protocol = "tcp", p = 3306, },
      { host = "${local.vpc3_prefix}vm8", protocol = "tcp", p = 30001, },
    ]
    TARGETS_SLO = [
      "${local.vpc3_prefix}vm1/",
      "${local.vpc3_prefix}vm2/",
      "${local.vpc3_prefix}vm4/",
      "${local.vpc3_prefix}vm8/",
    ]
  })
  vpc3_probe5_startup = templatefile("scripts/probe.sh", {
    TARGETS_INSIGHT = [
      { host = "${local.vpc3_prefix}https-server", protocol = "tcp", p = 443, }
    ]
    TARGETS_SLO = [
      "${local.vpc3_prefix}vm1/",
      "${local.vpc3_prefix}vm3/",
      "${local.vpc3_prefix}vm6/",
      "${local.vpc3_prefix}vm8/",
    ]
  })
  vpc3_probe6_startup = templatefile("scripts/probe.sh", {
    TARGETS_INSIGHT = [
      { host = "${local.vpc3_prefix}https-server", protocol = "tcp", p = 443, }
    ]
    TARGETS_SLO = [
      "${local.vpc3_prefix}vm1/",
      "${local.vpc3_prefix}vm5/",
      "${local.vpc3_prefix}vm6/",
      "${local.vpc3_prefix}vm7/",
    ]
  })
  vpc3_probe7_startup = templatefile("scripts/probe.sh", {
    TARGETS_INSIGHT = [
      { host = "${local.vpc3_prefix}proxy-server", protocol = "tcp", p = 8080, }
    ]
    TARGETS_SLO = [
      "${local.vpc3_prefix}vm2/",
      "${local.vpc3_prefix}vm3/",
      "${local.vpc3_prefix}vm5/",
      "${local.vpc3_prefix}vm8/",
    ]
  })
}

#========================================================
# network
#========================================================

resource "google_compute_network" "vpc3" {
  project                 = var.project_id_main
  name                    = "vpc3"
  routing_mode            = "GLOBAL"
  auto_create_subnetworks = false
}

#========================================================
# subnets
#========================================================

resource "google_compute_subnetwork" "vpc3_subnets" {
  for_each      = local.vpc3_subnets
  name          = "${local.vpc3_prefix}${each.key}"
  ip_cidr_range = each.value.range
  region        = each.value.region
  network       = google_compute_network.vpc3.self_link
}

#========================================================
# addresses
#========================================================

resource "google_compute_address" "vpc3_vm9" {
  name         = "${local.vpc3_prefix}vm9"
  description  = "regional static address for vm"
  region       = local.us_region2
  network_tier = "STANDARD"
}

resource "google_compute_address" "vpc3_vm10" {
  name         = "${local.vpc3_prefix}vm10"
  description  = "regional static address for vm"
  region       = local.us_region2
  network_tier = "STANDARD"
}

#========================================================
# cloud nat
#========================================================

# router

resource "google_compute_router" "vpc3_nat_routers" {
  for_each = local.vpc3_nat_regions
  name     = each.key
  region   = each.value
  network  = google_compute_network.vpc3.self_link
}

#========================================================
# nat
#========================================================

resource "google_compute_router_nat" "vpc3_nat" {
  for_each                           = google_compute_router.vpc3_nat_routers
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

# ssh

resource "google_compute_firewall" "vpc3_allow_ssh" {
  name        = "${local.vpc3_prefix}vpc3-allow-ssh"
  network     = google_compute_network.vpc3.self_link
  direction   = "INGRESS"
  description = ""
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = data.google_netblock_ip_ranges.iap_forwarders.cidr_blocks_ipv4
  priority      = "900"
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# allows ingress from internal

resource "google_compute_firewall" "vpc3_allow_internal" {
  name        = "${local.vpc3_prefix}vpc3-allow-internal"
  network     = google_compute_network.vpc3.self_link
  direction   = "INGRESS"
  description = ""
  allow {
    protocol = "all"
  }
  source_ranges = ["10.0.0.0/8", ]
  priority      = "8888"
}

# deny ingress from everything

resource "google_compute_firewall" "vpc3_ingress_deny_all" {
  name        = "${local.vpc3_prefix}ingress-deny-all"
  network     = google_compute_network.vpc3.self_link
  direction   = "INGRESS"
  description = ""
  priority    = 9999
  deny {
    protocol = "all"
  }
  source_ranges = ["0.0.0.0/0", ]
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# Use Case 1
#---------------------------------------------

# allow rule is shadowed by deny rule,
# causing unexpected service disruption

resource "google_compute_firewall" "vpc3_uc1_app2_allow_app1" {
  name        = "${local.vpc3_prefix}uc1-app2-allow-app1"
  network     = google_compute_network.vpc3.self_link
  direction   = "INGRESS"
  description = "allow ingress from subnet1 to vm2"
  allow {
    protocol = "all"
  }
  source_ranges = [local.vpc3_subnet1]
  target_tags   = ["web-app2"]
  priority      = "1000"
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "vpc3_uc1_app2_deny_all" {
  name        = "${local.vpc3_prefix}uc1-app2-deny-all"
  network     = google_compute_network.vpc3.self_link
  direction   = "INGRESS"
  description = "deny ingress from supernet to vm2"
  deny {
    protocol = "all"
  }
  source_ranges = [local.vpc3_supernet]
  target_tags   = ["web-app2"]
  priority      = "1000"
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# Shadow rule variation
# 2 rules combined shadow a lower priority rule

resource "google_compute_firewall" "vpc3_uc1_db4_allow_app3" {
  name        = "${local.vpc3_prefix}uc1-db4-allow-app3"
  network     = google_compute_network.vpc3.self_link
  priority    = "1000"
  direction   = "INGRESS"
  description = "allow http and https access to vm4 from subnet3"
  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }
  source_ranges = [local.vpc3_subnet3]
  target_tags   = ["db-srv4"]
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "vpc3_uc1_db4_deny_http" {
  name        = "${local.vpc3_prefix}uc1-db4-deny-http"
  network     = google_compute_network.vpc3.self_link
  direction   = "INGRESS"
  description = "deny http access to vm4 from subnet3"
  deny {
    protocol = "tcp"
    ports    = ["80"]
  }
  source_ranges = [local.vpc3_subnet3]
  target_tags   = ["db-srv4"]
  priority      = "900"
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "vpc3_uc1_db4_deny_https" {
  name        = "${local.vpc3_prefix}uc1-db4-deny-https"
  network     = google_compute_network.vpc3.self_link
  direction   = "INGRESS"
  description = "deny https access to vm4 from subnet3"
  deny {
    protocol = "tcp"
    ports    = ["443"]
  }
  source_ranges = [local.vpc3_subnet3]
  target_tags   = ["db-srv4"]
  priority      = "900"
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# Use Case 2
#---------------------------------------------

# Allow Rule with no Hit
# there is no incoming traffic from 10.1.0.0/24
# so this firewall rule will not be hit

resource "google_compute_firewall" "vpc3_uc2_test_allow_rdp" {
  name        = "${local.vpc3_prefix}uc2-test-allow-rdp"
  network     = google_compute_network.vpc3.self_link
  direction   = "INGRESS"
  description = "allow rdp from subnet1 to vm6"
  allow {
    protocol = "tcp"
    ports    = ["3389"]
  }
  source_ranges = [local.vpc3_subnet1, ]
  target_tags   = ["auth-srv6", ]
  priority      = "1000"
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# Similar rules (2 with hit) - group 1
# all these rules have same target tags

resource "google_compute_firewall" "vpc3_uc2_test_allow_rdp2" {
  name        = "${local.vpc3_prefix}uc2-test-allow-rdp2"
  network     = google_compute_network.vpc3.self_link
  direction   = "INGRESS"
  description = "allow rdp from subnet2 to vm6"
  allow {
    protocol = "tcp"
    ports    = ["3389"]
  }
  source_ranges = [local.vpc3_subnet2, ]
  target_tags   = ["auth-srv6", ]
  priority      = "1000"
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "vpc3_uc2_test_allow_rdp3" {
  name        = "${local.vpc3_prefix}uc2-test-allow-rdp3"
  network     = google_compute_network.vpc3.self_link
  direction   = "INGRESS"
  description = "allow rdp from subnet3 to vm6"

  allow {
    protocol = "tcp"
    ports    = ["3389"]
  }
  source_ranges = [local.vpc3_subnet3, ]
  target_tags   = ["auth-srv6", ]
  priority      = "1000"

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "vpc3_uc2_test_allow_rdp4" {
  name        = "${local.vpc3_prefix}uc2-test-allow-rdp4"
  network     = google_compute_network.vpc3.self_link
  direction   = "INGRESS"
  description = "allow rdp from subnet4 to vm6"
  allow {
    protocol = "tcp"
    ports    = ["3389"]
  }
  source_ranges = [local.vpc3_subnet4, ]
  target_tags   = ["auth-srv6", ]
  priority      = "1000"
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "vpc3_uc2_test_allow_rdp5" {
  name        = "${local.vpc3_prefix}uc2-test-allow-rdp5"
  network     = google_compute_network.vpc3.self_link
  direction   = "INGRESS"
  description = "allow rdp from subnet5 to server6"
  allow {
    protocol = "tcp"
    ports    = ["3389"]
  }
  source_ranges = [local.vpc3_subnet5, ]
  target_tags   = ["auth-srv6", ]
  priority      = "1000"
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# Similar rules (1 with hit) - group 2
# all these rules have same target tags

resource "google_compute_firewall" "vpc3_uc2_app1_allow_external" {
  name        = "${local.vpc3_prefix}uc2-app1-allow-external"
  network     = google_compute_network.vpc3.self_link
  direction   = "INGRESS"
  description = "allow ssh from internet to vm1"
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["0.0.0.0/0", ]
  target_tags   = ["web-app1", ]
  priority      = "1000"
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "vpc3_uc2_app1_deny_icmp" {
  name        = "${local.vpc3_prefix}uc2-app1-deny-icmp"
  network     = google_compute_network.vpc3.self_link
  direction   = "INGRESS"
  description = "deny icmp access to vm1"
  deny {
    protocol = "icmp"
  }
  source_ranges = ["10.100.0.0/24", ]
  target_tags   = ["web-app1", ]
  priority      = "1000"
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "vpc3_uc2_app1_allow_ssh" {
  name        = "${local.vpc3_prefix}uc2-app1-allow-ssh"
  network     = google_compute_network.vpc3.self_link
  direction   = "INGRESS"
  description = "deny ssh access to vm1"
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["10.55.0.0/24", ]
  target_tags   = ["web-app1", ]
  priority      = "1000"
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# Use Case 3
#---------------------------------------------

# mysql partial hit

resource "google_compute_firewall" "vpc3_uc3_db7_allow_mysql" {
  name        = "${local.vpc3_prefix}uc3-db7-allow-mysql"
  network     = google_compute_network.vpc3.self_link
  direction   = "INGRESS"
  description = ""
  allow {
    protocol = "tcp"
    ports = [
      "3306", "6446", "389"
    ]
  }
  source_ranges = [local.vpc3_subnet7, ]
  target_tags   = ["db8-mysql", ]
  priority      = "1000"

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "vpc3_uc3_anthos_allow_admin" {
  name        = "${local.vpc3_prefix}uc3-anthos-allow-admin"
  network     = google_compute_network.vpc3.self_link
  direction   = "INGRESS"
  description = ""
  allow {
    protocol = "tcp"
    ports    = ["22", "443", "30000-32767"]
  }
  source_ranges = [local.vpc3_subnet7, ]
  target_tags   = ["anthos8-fw", ]
  priority      = "1000"

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# Use Case 4
#---------------------------------------------

## Unhit rule insight with low future hit probability

resource "google_compute_firewall" "vpc3_uc4_rule_1_1" {
  name        = "${local.vpc3_prefix}uc4-rule-1-1"
  network     = google_compute_network.vpc3.self_link
  direction   = "INGRESS"
  description = ""
  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
  source_ranges = [local.vpc3_subnet2_x, ]
  target_tags   = ["http-server", ]
  priority      = "1000"
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "vpc3_uc4_rule_1_2" {
  name        = "${local.vpc3_prefix}uc4-rule-1-2"
  network     = google_compute_network.vpc3.self_link
  direction   = "INGRESS"
  description = ""
  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
  source_ranges = [local.vpc3_subnet3_x, ]
  target_tags   = ["http-server", ]
  priority      = "1000"
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "vpc3_uc4_rule_1_3" {
  name        = "${local.vpc3_prefix}uc4-rule-1-3"
  network     = google_compute_network.vpc3.self_link
  direction   = "INGRESS"
  description = ""
  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
  source_ranges = [local.vpc3_subnet4_x, ]
  target_tags   = ["http-server", ]
  priority      = "1000"
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# Use Case 5
#---------------------------------------------

## Unhit rule insight with high future hit probability

resource "google_compute_firewall" "vpc3_uc5_rule_2_1" {
  name        = "${local.vpc3_prefix}uc5-rule-2-1"
  network     = google_compute_network.vpc3.self_link
  direction   = "INGRESS"
  description = ""
  allow {
    protocol = "tcp"
    ports    = ["443"]
  }
  source_ranges = [local.vpc3_subnet5_x, ]
  target_tags   = ["https-server", ]
  priority      = "1000"

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "vpc3_uc5_rule_2_2" {
  name        = "${local.vpc3_prefix}uc5-rule-2-2"
  network     = google_compute_network.vpc3.self_link
  direction   = "INGRESS"
  description = ""
  allow {
    protocol = "tcp"
    ports    = ["443"]
  }
  source_ranges = [local.vpc3_subnet6_x, ]
  target_tags   = ["https-server", ]
  priority      = "1000"
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "vpc3_uc5_rule_2_3" {
  name        = "${local.vpc3_prefix}uc5-rule-2-3"
  network     = google_compute_network.vpc3.self_link
  direction   = "INGRESS"
  description = ""
  allow {
    protocol = "tcp"
    ports    = ["443"]
  }
  source_ranges = [local.vpc3_subnet7_x, ]
  target_tags   = ["https-server", ]
  priority      = "1000"
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# Use Case 6
#---------------------------------------------

# Unhit attribute insight with low future hit probability

resource "google_compute_firewall" "vpc3_uc6_rule_3_1" {
  name        = "${local.vpc3_prefix}uc6-rule-3-1"
  network     = google_compute_network.vpc3.self_link
  direction   = "INGRESS"
  description = ""
  allow {
    protocol = "tcp"
    ports    = ["8080", "10080", ]
  }
  source_ranges = [local.vpc3_subnet8_x, ]
  target_tags   = ["proxy-server", ]
  priority      = "1000"
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "vpc3_uc6_rule_3_2" {
  name        = "${local.vpc3_prefix}uc6-rule-3-2"
  network     = google_compute_network.vpc3.self_link
  direction   = "INGRESS"
  description = ""
  allow {
    protocol = "tcp"
    ports    = ["10080", ]
  }
  source_ranges = [local.vpc3_subnet9_x, ]
  target_tags   = ["proxy-server", ]
  priority      = "1000"
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

#========================================================
# instances
#========================================================

resource "google_compute_instance" "vpc3_vm" {
  for_each                  = local.vpc3_vm_config
  name                      = "${local.vpc3_prefix}${each.key}"
  machine_type              = var.machine_type
  zone                      = "${local.vpc3_subnets[each.value.subnet].region}-${each.value.zone}"
  tags                      = try(each.value.tags, null)
  metadata_startup_script   = each.value.startup
  allow_stopping_for_update = true
  boot_disk {
    initialize_params {
      image = var.image_debian
    }
  }
  network_interface {
    subnetwork = google_compute_subnetwork.vpc3_subnets[each.value.subnet].self_link
    dynamic "access_config" {
      for_each = try(each.value.nat_ip, null) == null ? [] : [0]
      content {
        nat_ip       = try(each.value.nat_ip, null)
        network_tier = try(each.value.network_tier, "STANDARD")
      }
    }
  }
  service_account {
    scopes = ["cloud-platform"]
  }
}
