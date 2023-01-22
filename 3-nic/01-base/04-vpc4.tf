
locals {
  vpc4_prefix   = "vpc4-"
  vpc4_asn      = 65004
  vpc4_supernet = "10.40.0.0/16"

  vpc4_psc_api_fr_range    = "10.40.255.0/24"
  vpc4_psc_api_all_fr_addr = cidrhost(local.vpc4_psc_api_fr_range, 1)
  vpc4_psc_api_sec_fr_addr = cidrhost(local.vpc4_psc_api_fr_range, 2)

  vpc4_gke_cluster1_master_cidr_block = "172.16.1.0/28"
  vpc4_gke_cluster2_master_cidr_block = "172.16.2.0/28"
  vpc4_gke_cluster3_master_cidr_block = "172.16.3.0/28"

  vpc4_nat_regions = {
    ("${local.vpc4_prefix}nat-us-region1") = {
      region                             = local.us_region1
      source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
      secondary_ip_range_names           = []
    }
    ("${local.vpc4_prefix}nat-us-region2") = {
      region                             = local.us_region2
      source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_PRIMARY_IP_RANGES"
      secondary_ip_range_names           = []
    }
    ("${local.vpc4_prefix}nat-us-region3") = {
      region                             = local.us_region3
      source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
      subnets = [{
        name                     = "${local.vpc4_prefix}subnet3"
        source_ip_ranges_to_nat  = ["ALL_IP_RANGES"]
        secondary_ip_range_names = []
      }]
    }
    ("${local.vpc4_prefix}nat-us-region4") = {
      region                             = local.us_region4
      source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
      subnets = [{
        name                     = "${local.vpc4_prefix}subnet4"
        source_ip_ranges_to_nat  = ["PRIMARY_IP_RANGE"]
        secondary_ip_range_names = []
      }]
    }
    ("${local.vpc4_prefix}nat-us-region5") = {
      region                             = local.us_region5
      source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
      subnets = [{
        name                     = "${local.vpc4_prefix}subnet5"
        source_ip_ranges_to_nat  = ["PRIMARY_IP_RANGE", "LIST_OF_SECONDARY_IP_RANGES"]
        secondary_ip_range_names = ["cluster-5-pods", "cluster-5-services"]
      }]
    }
    ("${local.vpc4_prefix}nat-us-region6") = {
      region                             = local.us_region6
      source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
      subnets = [{
        name                     = "${local.vpc4_prefix}subnet6"
        source_ip_ranges_to_nat  = ["LIST_OF_SECONDARY_IP_RANGES", ]
        secondary_ip_range_names = ["cluster-6-pods", ]
      }]
    }
  }
  vpc4_subnets = {
    ("${local.vpc4_prefix}subnet1") = {
      region                = local.us_region1
      ip_cidr_range         = "10.40.1.0/29"
      private_google_access = false
      alias_ip_ranges = {
        range1 = "10.40.201.0/24"
      }
    }
    ("${local.vpc4_prefix}subnet2") = {
      region                = local.us_region2
      ip_cidr_range         = "10.40.2.0/24"
      private_google_access = false
      alias_ip_ranges = {
        cluster-1-pods          = "10.40.12.0/22"
        cluster-1-services      = "10.40.16.0/22"
        cluster-2-pods          = "10.40.20.0/22"
        cluster-2-services      = "10.40.24.0/22"
        ip-utilization-pods     = "10.40.40.0/22"
        ip-utilization-services = "10.40.44.0/22"
        range-1                 = "10.40.52.0/22"
        range-2                 = "10.40.56.0/22"
      }
    }
    ("${local.vpc4_prefix}subnet3") = {
      ip_cidr_range         = "10.40.3.0/24"
      region                = local.us_region3
      private_google_access = false
      alias_ip_ranges = {
        cluster-3-pods     = "10.40.32.0/22"
        cluster-3-services = "10.40.36.0/22"
      }
    }
    ("${local.vpc4_prefix}subnet4") = {
      ip_cidr_range         = "10.40.4.0/24"
      region                = local.us_region4
      private_google_access = false
      alias_ip_ranges = {
        cluster-3-pods     = "10.40.60.0/22"
        cluster-3-services = "10.40.64.0/22"
      }
    }
    ("${local.vpc4_prefix}subnet5") = {
      ip_cidr_range         = "10.40.5.0/24"
      region                = local.us_region5
      private_google_access = false
      alias_ip_ranges = {
        cluster-5-pods     = "10.40.68.0/22"
        cluster-5-services = "10.40.72.0/22"
      }
    }
    ("${local.vpc4_prefix}subnet6") = {
      ip_cidr_range         = "10.40.6.0/24"
      region                = local.us_region6
      private_google_access = false
      alias_ip_ranges = {
        cluster-6-pods     = "10.40.76.0/22"
        cluster-6-services = "10.40.80.0/22"
      }
    }
  }
  vpc4_vm_config = {
    "${local.vpc4_prefix}vm1" = {
      subnet          = "${local.vpc4_prefix}subnet1"
      region          = local.vpc4_subnets["${local.vpc4_prefix}subnet1"].region
      zone            = "b"
      network_ip      = cidrhost(local.vpc4_subnets["${local.vpc4_prefix}subnet1"].ip_cidr_range, 2)
      alias_ip_ranges = local.vpc4_subnets["${local.vpc4_prefix}subnet1"].alias_ip_ranges
      startup         = local.vpc4_nat_startup,
    }
  }
  vpc4_nat_startup = templatefile("scripts/nat.sh", {
    TARGETS_BUCKET = [module.vpc4_storage_bucket.name]
  })
  vpc4_psc_api_secure    = false
  vpc4_psc_api_fr_name   = local.vpc4_psc_api_secure ? "vpc4sec" : "vpc4all"
  vpc4_psc_api_fr_target = local.vpc4_psc_api_secure ? "vpc-sc" : "all-apis"
  vpc4_psc_api_fr_addr = (
    local.vpc4_psc_api_secure ?
    local.vpc4_psc_api_sec_fr_addr :
    local.vpc4_psc_api_all_fr_addr
  )
}

#========================================================
# service account
#========================================================

module "vpc4_sa" {
  source       = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/iam-service-account"
  project_id   = var.project_id_main
  name         = trimsuffix("${local.vpc4_prefix}sa", "-")
  generate_key = false
  iam_project_roles = {
    (var.project_id_main) = ["roles/viewer", ]
  }
}

#========================================================
# storage
#========================================================

module "vpc4_storage_bucket" {
  source        = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/gcs"
  project_id    = var.project_id_main
  prefix        = ""
  name          = "${local.vpc4_prefix}storage-bucket"
  location      = local.us_region1
  storage_class = "STANDARD"
  force_destroy = true
  iam = {
    "roles/storage.objectViewer" = [
      "serviceAccount:${module.vpc4_sa.email}",
    ]
  }
}

resource "google_storage_bucket_object" "vpc4_storage_bucket_file" {
  name    = "${local.vpc4_prefix}object.txt"
  bucket  = module.vpc4_storage_bucket.name
  content = "<--- OBJECT --->"
}

#========================================================
# network
#========================================================

resource "google_compute_network" "vpc4" {
  project                 = var.project_id_main
  name                    = "vpc4"
  routing_mode            = "GLOBAL"
  auto_create_subnetworks = false
}

#========================================================
# subnets
#========================================================

resource "google_compute_subnetwork" "vpc4_subnets" {
  for_each      = local.vpc4_subnets
  name          = each.key
  ip_cidr_range = each.value.ip_cidr_range
  region        = each.value.region
  network       = google_compute_network.vpc4.self_link
  secondary_ip_range = each.value.alias_ip_ranges == null ? [] : [
    for name, range in each.value.alias_ip_ranges :
    { range_name = name, ip_cidr_range = range }
  ]
  purpose                  = try(each.value.purpose, null)
  role                     = try(each.value.role, null)
  private_ip_google_access = try(each.value.private_google_access, true)
}

#========================================================
# addresses
#========================================================

resource "google_compute_address" "vpc4_static_ip_addresses" {
  for_each     = local.vpc4_vm_config
  name         = each.key
  subnetwork   = google_compute_subnetwork.vpc4_subnets[each.value.subnet].id
  address_type = "INTERNAL"
  address      = try(each.value.network_ip, null)
  region       = each.value.region
}

#========================================================
# cloud nat
#========================================================

# router

resource "google_compute_router" "vpc4_nat_routers" {
  for_each = local.vpc4_nat_regions
  name     = each.key
  region   = each.value.region
  network  = google_compute_network.vpc4.self_link
}

# nat

resource "google_compute_router_nat" "vpc4_nat" {
  for_each               = local.vpc4_nat_regions
  name                   = each.key
  router                 = google_compute_router.vpc4_nat_routers[each.key].name
  region                 = each.value.region
  nat_ip_allocate_option = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = try(
    each.value.source_subnetwork_ip_ranges_to_nat,
    "ALL_SUBNETWORKS_ALL_IP_RANGES"
  )
  dynamic "subnetwork" {
    for_each = (
      each.value.source_subnetwork_ip_ranges_to_nat ==
      "LIST_OF_SUBNETWORKS" ? try(each.value.subnets, []) : []
    )
    iterator = subnet
    content {
      name                     = try(google_compute_subnetwork.vpc4_subnets[subnet.value.name].id, null)
      source_ip_ranges_to_nat  = subnet.value.source_ip_ranges_to_nat
      secondary_ip_range_names = try(subnet.value.secondary_ip_range_names, null)
    }
  }
  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

#========================================================
# PSC for Google API
#========================================================

# vip

resource "google_compute_global_address" "vpc4_psc_api_fr_addr" {
  provider     = google-beta
  name         = "vpc4"
  address_type = "INTERNAL"
  purpose      = "PRIVATE_SERVICE_CONNECT"
  network      = google_compute_network.vpc4.self_link
  address      = local.vpc4_psc_api_fr_addr
}

# fr

resource "google_compute_global_forwarding_rule" "vpc4_psc_api_fr" {
  provider              = google-beta
  name                  = local.vpc4_psc_api_fr_name
  target                = local.vpc4_psc_api_fr_target
  network               = google_compute_network.vpc4.self_link
  ip_address            = google_compute_global_address.vpc4_psc_api_fr_addr.id
  load_balancing_scheme = ""
}

#========================================================
# DNS
#========================================================

# dns policy

resource "google_dns_policy" "vpc4_dns_policy" {
  provider                  = google-beta
  name                      = "${local.vpc4_prefix}dns-policy"
  enable_inbound_forwarding = false
  enable_logging            = true
  networks { network_url = google_compute_network.vpc4.self_link }
}

# policy

resource "google_dns_response_policy" "vpc4_dns_rp" {
  provider             = google-beta
  response_policy_name = "${local.vpc4_prefix}dns-rp"
  networks {
    network_url = google_compute_network.vpc4.self_link
  }
}

# rules - local

locals {
  vpc4_dns_rp_rules_local = {
    ("${local.vpc4_prefix}dns-rp-rule-runapp") = {
      dns_name    = "*.run.app."
      local_datas = { name = "*.run.app.", type = "A", ttl = 300, rrdatas = [local.vpc4_psc_api_fr_addr] }
    }
    ("${local.vpc4_prefix}dns-rp-rule-gcr") = {
      dns_name    = "*.gcr.io."
      local_datas = { name = "*.gcr.io.", type = "A", ttl = 300, rrdatas = [local.vpc4_psc_api_fr_addr] }
    }
    ("${local.vpc4_prefix}dns-rp-rule-apis") = {
      dns_name    = "*.googleapis.com."
      local_datas = { name = "*.googleapis.com.", type = "A", ttl = 300, rrdatas = [local.vpc4_psc_api_fr_addr] }
    }
  }
}

resource "google_dns_response_policy_rule" "vpc4_dns_rp_rules_local" {
  for_each        = local.vpc4_dns_rp_rules_local
  provider        = google-beta
  response_policy = google_dns_response_policy.vpc4_dns_rp.response_policy_name
  rule_name       = each.key
  dns_name        = each.value.dns_name
  local_data {
    local_datas {
      name    = each.value.local_datas.name
      type    = each.value.local_datas.type
      ttl     = each.value.local_datas.ttl
      rrdatas = each.value.local_datas.rrdatas
    }
  }
}

# rules - bypass

locals {
  vpc4_dns_rp_rules_bypass = {
    ("${local.vpc4_prefix}dns-rp-rule-bypass-www")    = { dns_name = "www.googleapis.com." }
    ("${local.vpc4_prefix}dns-rp-rule-bypass-ouath2") = { dns_name = "oauth2.googleapis.com." }
    ("${local.vpc4_prefix}dns-rp-rule-bypass-psc")    = { dns_name = "*.p.googleapis.com." }
  }
  vpc4_dns_rp_rules_bypass_create = templatefile("scripts/dns/rule-bypass-create.sh", {
    PROJECT = var.project_id_main
    RP_NAME = google_dns_response_policy.vpc4_dns_rp.response_policy_name
    RULES   = local.vpc4_dns_rp_rules_bypass
  })
  vpc4_dns_rp_rules_bypass_delete = templatefile("scripts/dns/rule-delete.sh", {
    PROJECT = var.project_id_main
    RP_NAME = google_dns_response_policy.vpc4_dns_rp.response_policy_name
    RULES   = local.vpc4_dns_rp_rules_bypass
  })
}

resource "null_resource" "vpc4_dns_rp_rules_bypass" {
  triggers = {
    create = local.vpc4_dns_rp_rules_bypass_create
    delete = local.vpc4_dns_rp_rules_bypass_delete
  }
  provisioner "local-exec" {
    command = self.triggers.create
  }
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete
  }
}

#========================================================
# firewall rules
#========================================================

# ingress
#---------------------------------------------

# allow ssh ingress from only iap ranges

resource "google_compute_firewall" "vpc4_ingress_allow_iap" {
  name      = "${local.vpc4_prefix}ingress-allow-iap"
  network   = google_compute_network.vpc4.self_link
  direction = "INGRESS"
  priority  = 100
  allow {
    protocol = "tcp"
    ports    = ["22", ]
  }
  source_ranges = data.google_netblock_ip_ranges.iap_forwarders.cidr_blocks_ipv4
}

# allow ingress from google health check ranges

resource "google_compute_firewall" "vpc4_ingress_allow_health_check" {
  name      = "${local.vpc4_prefix}ingress-allow-health-check"
  network   = google_compute_network.vpc4.self_link
  direction = "INGRESS"
  priority  = 100
  allow {
    protocol = "all"
  }
  source_ranges = data.google_netblock_ip_ranges.health_checkers.cidr_blocks_ipv4
  target_tags   = ["ingress-allow-health-check", ]
}

# deny ingress from all gke control plane ranges

resource "google_compute_firewall" "vpc4_ingress_deny_cluster1_control_plane" {
  name      = "${local.vpc4_prefix}ingress-deny-cluster1-control-plane"
  network   = google_compute_network.vpc4.self_link
  direction = "INGRESS"
  priority  = 100
  allow {
    protocol = "all"
  }
  source_ranges = [local.vpc4_gke_cluster1_master_cidr_block, ]
}

# allow ingress from all internal ranges

resource "google_compute_firewall" "vpc4_ingress_allow_internal" {
  name      = "${local.vpc4_prefix}ingress-allow-internal"
  network   = google_compute_network.vpc4.self_link
  direction = "INGRESS"
  priority  = 8888
  allow {
    protocol = "all"
  }
  source_ranges = [local.supernet, ]
}

# deny ingress from everything

resource "google_compute_firewall" "vpc4_ingress_deny_all" {
  name      = "${local.vpc4_prefix}ingress-deny-all"
  network   = google_compute_network.vpc4.self_link
  direction = "INGRESS"
  priority  = 9999
  deny {
    protocol = "all"
  }
  source_ranges = ["0.0.0.0/0", ]
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# egress
#---------------------------------------------

resource "google_compute_firewall" "vpc4_egress_deny_cluster1_master" {
  name      = "${local.vpc4_prefix}egress-deny-cluster1-master"
  network   = google_compute_network.vpc4.self_link
  direction = "EGRESS"
  priority  = 100
  deny {
    protocol = "all"
  }
  destination_ranges = [local.vpc4_gke_cluster1_master_cidr_block, ]
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "vpc4_egress_deny_cluster3_endpoint" {
  name      = "${local.vpc4_prefix}egress-deny-cluster3-endpoint"
  network   = google_compute_network.vpc4.self_link
  direction = "EGRESS"
  priority  = 100
  deny {
    protocol = "all"
  }
  destination_ranges = [local.vpc4_gke_cluster1_master_cidr_block, ]
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

#========================================================
# instances
#========================================================

resource "google_compute_instance" "vpc4_vm" {
  for_each                  = local.vpc4_vm_config
  name                      = each.key
  machine_type              = var.machine_type
  zone                      = "${local.vpc4_subnets[each.value.subnet].region}-${each.value.zone}"
  tags                      = try(each.value.tags, null)
  metadata_startup_script   = each.value.startup
  allow_stopping_for_update = true
  boot_disk {
    initialize_params {
      image = var.image_debian
    }
  }
  network_interface {
    subnetwork = google_compute_subnetwork.vpc4_subnets[each.value.subnet].self_link
    network_ip = try(each.value.network_ip, null)
    dynamic "access_config" {
      for_each = try(each.value.nat_ip, null) == null ? [] : [0]
      content {
        nat_ip       = try(each.value.nat_ip, null)
        network_tier = try(each.value.network_tier, "STANDARD")
      }
    }
    dynamic "alias_ip_range" {
      for_each = try(each.value.alias_ip_ranges, {})
      iterator = alias
      content {
        subnetwork_range_name = alias.key
        ip_cidr_range         = alias.value
      }
    }
  }
  service_account {
    scopes = ["cloud-platform"]
  }
}
/*
#========================================================
# gke
#========================================================

# cluster-2
#---------------------------------------------

# cluster

resource "google_container_cluster" "vpc4_cluster_2" {
  provider                 = google-beta
  name                     = "${local.vpc4_prefix}cluster-2"
  description              = ""
  location                 = local.us_region2
  network                  = google_compute_network.vpc4.self_link
  subnetwork               = google_compute_subnetwork.vpc4_subnets["${local.vpc4_prefix}subnet2"].self_link
  initial_node_count       = 1
  remove_default_node_pool = true

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = local.vpc4_gke_cluster2_master_cidr_block
    master_global_access_config {
      enabled = true
    }
  }
  ip_allocation_policy {
    cluster_secondary_range_name  = "cluster-2-pods"
    services_secondary_range_name = "cluster-2-services"
  }
}

# node pool

resource "google_container_node_pool" "vpc4_cluster_2_node_pool" {
  provider           = google-beta
  name               = "${local.vpc4_prefix}cluster-2-node-pool"
  location           = local.us_region2
  cluster            = google_container_cluster.vpc4_cluster_2.name
  initial_node_count = 1
  node_config {
    machine_type = "e2-medium"
  }
}

# cluster-3
#---------------------------------------------

# cluster

resource "google_container_cluster" "vpc4_cluster_3" {
  provider                 = google-beta
  name                     = "${local.vpc4_prefix}cluster-3"
  description              = ""
  location                 = local.us_region3
  network                  = google_compute_network.vpc4.self_link
  subnetwork               = google_compute_subnetwork.vpc4_subnets["${local.vpc4_prefix}subnet3"].self_link
  initial_node_count       = 1
  remove_default_node_pool = true

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = local.vpc4_gke_cluster3_master_cidr_block
    master_global_access_config {
      enabled = true
    }
  }
  ip_allocation_policy {
    cluster_secondary_range_name  = "cluster-3-pods"
    services_secondary_range_name = "cluster-3-services"
  }
}

# node pool
/*
resource "google_container_node_pool" "vpc4_cluster_3_node_pool" {
  provider           = google-beta
  name               = "${local.vpc4_prefix}cluster-3-node-pool"
  location           = local.us_region3
  cluster            = google_container_cluster.vpc4_cluster_3.name
  initial_node_count = 1
  node_config {
    machine_type = "e2-medium"
  }
}*/
