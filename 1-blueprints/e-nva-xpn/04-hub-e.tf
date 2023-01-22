
locals {
  hub_regions        = [local.hub_eu_region, local.hub_us_region, ]
  hub_eu_subnet1     = google_compute_subnetwork.hub_subnets["${local.hub_prefix}eu-subnet1"]
  hub_eu_subnet2     = google_compute_subnetwork.hub_subnets["${local.hub_prefix}eu-subnet2"]
  hub_eu_subnet3     = google_compute_subnetwork.hub_subnets["${local.hub_prefix}eu-subnet3"]
  hub_us_subnet1     = google_compute_subnetwork.hub_subnets["${local.hub_prefix}us-subnet1"]
  hub_us_subnet2     = google_compute_subnetwork.hub_subnets["${local.hub_prefix}us-subnet2"]
  hub_us_subnet3     = google_compute_subnetwork.hub_subnets["${local.hub_prefix}us-subnet3"]
  hub_mgt_eu_subnet1 = google_compute_subnetwork.hub_mgt_subnets["${local.hub_prefix}mgt-eu-subnet1"]
  hub_mgt_us_subnet1 = google_compute_subnetwork.hub_mgt_subnets["${local.hub_prefix}mgt-us-subnet1"]
  hub_int_eu_subnet1 = google_compute_subnetwork.hub_int_subnets["${local.hub_prefix}int-eu-subnet1"]
  hub_int_eu_subnet2 = google_compute_subnetwork.hub_int_subnets["${local.hub_prefix}int-eu-subnet2"]
  hub_int_us_subnet1 = google_compute_subnetwork.hub_int_subnets["${local.hub_prefix}int-us-subnet1"]
  hub_int_us_subnet2 = google_compute_subnetwork.hub_int_subnets["${local.hub_prefix}int-us-subnet2"]
}

locals {
  spoke1_eu_subnet1                  = google_compute_subnetwork.spoke1_subnets["${local.spoke1_prefix}eu-subnet1"]
  spoke1_eu_subnet2                  = google_compute_subnetwork.spoke1_subnets["${local.spoke1_prefix}eu-subnet2"]
  spoke1_eu_subnet3                  = google_compute_subnetwork.spoke1_eu_subnet3
  spoke1_us_subnet1                  = google_compute_subnetwork.spoke1_subnets["${local.spoke1_prefix}us-subnet1"]
  spoke1_us_subnet2                  = google_compute_subnetwork.spoke1_subnets["${local.spoke1_prefix}us-subnet2"]
  spoke1_eu_psc_producer_nat_subnet1 = google_compute_subnetwork.spoke1_subnets["${local.spoke1_prefix}eu-psc-producer-nat-subnet1"]
}

locals {
  spoke2_eu_subnet1                  = google_compute_subnetwork.spoke2_subnets["${local.spoke2_prefix}eu-subnet1"]
  spoke2_eu_subnet2                  = google_compute_subnetwork.spoke2_subnets["${local.spoke2_prefix}eu-subnet2"]
  spoke2_us_subnet1                  = google_compute_subnetwork.spoke2_subnets["${local.spoke2_prefix}us-subnet1"]
  spoke2_us_subnet2                  = google_compute_subnetwork.spoke2_subnets["${local.spoke2_prefix}us-subnet2"]
  spoke2_us_subnet3                  = google_compute_subnetwork.spoke2_us_subnet3
  spoke2_us_psc_producer_nat_subnet1 = google_compute_subnetwork.spoke2_subnets["${local.spoke2_prefix}us-psc-producer-nat-subnet1"]
}

# namespace
#---------------------------------

resource "google_service_directory_namespace" "hub_td" {
  provider     = google-beta
  project      = var.project_id_hub
  namespace_id = "${local.hub_prefix}td"
  location     = local.hub_eu_region
}

resource "google_service_directory_namespace" "hub_psc" {
  provider     = google-beta
  project      = var.project_id_hub
  namespace_id = "${local.hub_prefix}psc"
  location     = local.hub_eu_region
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

resource "google_compute_network" "hub_int_vpc" {
  project      = var.project_id_hub
  name         = "${local.hub_prefix}int-vpc"
  routing_mode = "GLOBAL"
  mtu          = 1460

  auto_create_subnetworks         = false
  delete_default_routes_on_create = false
}

resource "google_compute_network" "hub_mgt_vpc" {
  project      = var.project_id_hub
  name         = "${local.hub_prefix}mgt-vpc"
  routing_mode = "GLOBAL"
  mtu          = 1460

  auto_create_subnetworks         = false
  delete_default_routes_on_create = false
}

# subnets
#---------------------------------

# hub

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

resource "google_compute_subnetwork" "hub_int_subnets" {
  for_each = merge(
    { for k, v in local.hub_int_subnets : k => v if v.purpose != "INTERNAL_HTTPS_LOAD_BALANCER" },
  )
  provider      = google-beta
  project       = var.project_id_hub
  name          = each.key
  network       = google_compute_network.hub_int_vpc.id
  region        = each.value.region
  ip_cidr_range = each.value.ip_cidr_range
  secondary_ip_range = each.value.secondary_ip_range == null ? [] : [
    for name, range in each.value.secondary_ip_range :
    { range_name = name, ip_cidr_range = range }
  ]
  purpose = each.value.purpose
  role    = each.value.role
}

resource "google_compute_subnetwork" "hub_mgt_subnets" {
  for_each      = local.hub_mgt_subnets
  provider      = google-beta
  project       = var.project_id_hub
  name          = each.key
  network       = google_compute_network.hub_mgt_vpc.id
  region        = each.value.region
  ip_cidr_range = each.value.ip_cidr_range
  secondary_ip_range = each.value.secondary_ip_range == null ? [] : [
    for name, range in each.value.secondary_ip_range :
    { range_name = name, ip_cidr_range = range }
  ]
  purpose = each.value.purpose
  role    = each.value.role
}

# spoke1

resource "google_compute_subnetwork" "spoke1_subnets" {
  for_each      = { for k, v in local.spoke1_subnets : k => v if v.purpose != "INTERNAL_HTTPS_LOAD_BALANCER" }
  provider      = google-beta
  project       = var.project_id_hub
  name          = each.key
  network       = google_compute_network.hub_int_vpc.id
  region        = each.value.region
  ip_cidr_range = each.value.ip_cidr_range
  secondary_ip_range = each.value.secondary_ip_range == null ? [] : [
    for name, range in each.value.secondary_ip_range :
    { range_name = name, ip_cidr_range = range }
  ]
  purpose = each.value.purpose
  role    = each.value.role
}

resource "google_compute_subnetwork" "spoke1_eu_subnet3" {
  provider           = google-beta
  project            = var.project_id_hub
  name               = "${local.spoke1_prefix}eu-subnet3"
  network            = google_compute_network.hub_int_vpc.id
  region             = local.spoke1_subnets["${local.spoke1_prefix}eu-subnet3"].region
  ip_cidr_range      = local.spoke1_subnets["${local.spoke1_prefix}eu-subnet3"].ip_cidr_range
  secondary_ip_range = null
  purpose            = "INTERNAL_HTTPS_LOAD_BALANCER"
  role               = "ACTIVE"
}

# spoke2

resource "google_compute_subnetwork" "spoke2_subnets" {
  for_each      = { for k, v in local.spoke2_subnets : k => v if v.purpose != "INTERNAL_HTTPS_LOAD_BALANCER" }
  provider      = google-beta
  project       = var.project_id_hub
  name          = each.key
  network       = google_compute_network.hub_int_vpc.id
  region        = each.value.region
  ip_cidr_range = each.value.ip_cidr_range
  secondary_ip_range = each.value.secondary_ip_range == null ? [] : [
    for name, range in each.value.secondary_ip_range :
    { range_name = name, ip_cidr_range = range }
  ]
  purpose = each.value.purpose
  role    = each.value.role
}

resource "google_compute_subnetwork" "spoke2_us_subnet3" {
  provider           = google-beta
  project            = var.project_id_hub
  name               = "${local.spoke2_prefix}us-subnet3"
  network            = google_compute_network.hub_int_vpc.id
  region             = local.spoke2_subnets["${local.spoke2_prefix}us-subnet3"].region
  ip_cidr_range      = local.spoke2_subnets["${local.spoke2_prefix}us-subnet3"].ip_cidr_range
  secondary_ip_range = null
  purpose            = "INTERNAL_HTTPS_LOAD_BALANCER"
  role               = "ACTIVE"
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

# service networking connection
#---------------------------------

resource "google_compute_global_address" "hub_eu_psa_range1" {
  project       = var.project_id_hub
  name          = "${local.spoke1_prefix}hub-eu-psa-range1"
  network       = google_compute_network.hub_vpc.self_link
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  address       = split("/", local.hub_eu_psa_range1).0
  prefix_length = split("/", local.hub_eu_psa_range1).1
}

resource "google_compute_global_address" "hub_eu_psa_range2" {
  project       = var.project_id_hub
  name          = "${local.spoke1_prefix}hub-eu-psa-range2"
  network       = google_compute_network.hub_vpc.self_link
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  address       = split("/", local.hub_eu_psa_range2).0
  prefix_length = split("/", local.hub_eu_psa_range2).1
}

resource "google_service_networking_connection" "hub_eu_psa_ranges" {
  provider = google-beta
  network  = google_compute_network.hub_vpc.self_link
  service  = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [
    google_compute_global_address.hub_eu_psa_range1.name,
    google_compute_global_address.hub_eu_psa_range2.name
  ]
}

resource "google_compute_network_peering_routes_config" "hub_eu_psa_ranges" {
  project = var.project_id_hub
  peering = google_service_networking_connection.hub_eu_psa_ranges.peering
  network = google_compute_network.hub_vpc.name

  import_custom_routes = true
  export_custom_routes = true
}

# vpc-sc config

locals {
  hub_sn_vpcsc_config_create = templatefile("templates/sn/vpc-sc/create.sh", {
    PROJECT = var.project_id_hub
    NETWORK = google_compute_network.hub_vpc.name
    SERVICE = google_service_networking_connection.hub_eu_psa_ranges.service
  })
  hub_sn_vpcsc_config_delete = templatefile("templates/sn/vpc-sc/delete.sh", {
    PROJECT = var.project_id_hub
    NETWORK = google_compute_network.hub_vpc.name
    SERVICE = google_service_networking_connection.hub_eu_psa_ranges.service
  })
}

resource "null_resource" "hub_sn_vpcsc_config" {
  triggers = {
    create = local.hub_sn_vpcsc_config_create
    delete = local.hub_sn_vpcsc_config_delete
  }
  provisioner "local-exec" {
    command = self.triggers.create
  }
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete
  }
}

# dns config

resource "google_service_networking_peered_dns_domain" "hub_psa_dns_peering_onprem" {
  project    = var.project_id_hub
  name       = "${local.hub_prefix}psa-dns-peering-onprem"
  network    = google_compute_network.hub_vpc.name
  dns_suffix = "onprem."
  service    = google_service_networking_connection.hub_eu_psa_ranges.service
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

module "hub_mgt_nat" {
  source                = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-cloudnat"
  for_each              = toset(local.hub_regions)
  project_id            = var.project_id_hub
  region                = each.key
  name                  = "${local.hub_prefix}mgt-${each.key}"
  router_network        = google_compute_network.hub_mgt_vpc.self_link
  router_create         = true
  config_source_subnets = "ALL_SUBNETWORKS_ALL_PRIMARY_IP_RANGES"
}

module "hub_int_nat" {
  source                = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-cloudnat"
  for_each              = toset(local.hub_regions)
  project_id            = var.project_id_hub
  region                = each.key
  name                  = "${local.hub_prefix}int-${each.key}"
  router_network        = google_compute_network.hub_int_vpc.self_link
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
      targets              = [local.tag_dns]
      use_service_accounts = false
      rules                = [{ protocol = "all", ports = [] }]
      extra_attributes     = {}
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

module "hub_mgt_vpc_firewall" {
  source              = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-vpc-firewall"
  project_id          = var.project_id_hub
  network             = google_compute_network.hub_mgt_vpc.name
  admin_ranges        = []
  http_source_ranges  = []
  https_source_ranges = []
  custom_rules = {
    "${local.hub_prefix}mgt-internal" = {
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
    "${local.hub_prefix}mgt-dns-egress-proxy" = {
      description          = "allow dns egress proxy"
      direction            = "INGRESS"
      action               = "allow"
      sources              = []
      ranges               = local.netblocks.dns
      targets              = [local.tag_dns]
      use_service_accounts = false
      rules                = [{ protocol = "all", ports = [] }]
      extra_attributes     = {}
    }
    "${local.hub_prefix}mgt-gfe" = {
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

module "hub_int_vpc_firewall" {
  source              = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-vpc-firewall"
  project_id          = var.project_id_hub
  network             = google_compute_network.hub_int_vpc.name
  admin_ranges        = []
  http_source_ranges  = []
  https_source_ranges = []
  custom_rules = {
    "${local.hub_prefix}int-internal" = {
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
    "${local.hub_prefix}int-dns-egress" = {
      description          = "allow dns egress proxy"
      direction            = "INGRESS"
      action               = "allow"
      sources              = []
      ranges               = local.netblocks.dns
      targets              = [local.tag_dns]
      use_service_accounts = false
      rules                = [{ protocol = "all", ports = [] }]
      extra_attributes     = {}
    }
    "${local.hub_prefix}int-gfe" = {
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

# custom dns
#---------------------------------

# eu

resource "google_compute_instance" "hub_eu_dns" {
  project      = var.project_id_hub
  name         = "${local.hub_prefix}eu-dns"
  machine_type = var.machine_type
  zone         = "${local.hub_eu_region}-b"
  tags         = [local.tag_dns, local.tag_ssh]
  boot_disk {
    initialize_params {
      image = var.image_debian
      type  = var.disk_type
      size  = var.disk_size
    }
  }
  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }
  network_interface {
    network    = google_compute_network.hub_vpc.self_link
    subnetwork = local.hub_eu_subnet1.self_link
    network_ip = local.hub_eu_ns_addr
  }
  service_account {
    email  = module.hub_sa.email
    scopes = ["cloud-platform"]
  }
  metadata_startup_script   = local.hub_unbound_config
  allow_stopping_for_update = true
}

# us

resource "google_compute_instance" "hub_us_dns" {
  project      = var.project_id_hub
  name         = "${local.hub_prefix}us-dns"
  machine_type = var.machine_type
  zone         = "${local.hub_us_region}-b"
  tags         = [local.tag_dns, local.tag_ssh]
  boot_disk {
    initialize_params {
      image = var.image_debian
      type  = var.disk_type
      size  = var.disk_size
    }
  }
  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }
  network_interface {
    network    = google_compute_network.hub_vpc.self_link
    subnetwork = local.hub_us_subnet1.self_link
    network_ip = local.hub_us_ns_addr
  }
  service_account {
    email  = module.hub_sa.email
    scopes = ["cloud-platform"]
  }
  metadata_startup_script   = local.hub_unbound_config
  allow_stopping_for_update = true
}

# psc/api
#---------------------------------

# hub

resource "google_compute_global_address" "hub_psc_api_fr_addr" {
  provider     = google-beta
  project      = var.project_id_hub
  name         = local.hub_psc_api_fr_name
  address_type = "INTERNAL"
  purpose      = "PRIVATE_SERVICE_CONNECT"
  network      = google_compute_network.hub_vpc.self_link
  address      = local.hub_psc_api_fr_addr
}

resource "google_compute_global_forwarding_rule" "hub_psc_api_fr" {
  provider              = google-beta
  project               = var.project_id_hub
  name                  = local.hub_psc_api_fr_name
  target                = local.hub_psc_api_fr_target
  network               = google_compute_network.hub_vpc.self_link
  ip_address            = google_compute_global_address.hub_psc_api_fr_addr.id
  load_balancing_scheme = ""
}

# hub-int

resource "google_compute_global_address" "hub_int_psc_api_fr_addr" {
  provider     = google-beta
  project      = var.project_id_hub
  name         = local.hub_int_psc_api_fr_name
  address_type = "INTERNAL"
  purpose      = "PRIVATE_SERVICE_CONNECT"
  network      = google_compute_network.hub_int_vpc.self_link
  address      = local.hub_int_psc_api_fr_addr
}

resource "google_compute_global_forwarding_rule" "hub_int_psc_api_fr" {
  provider              = google-beta
  project               = var.project_id_hub
  name                  = local.hub_int_psc_api_fr_name
  target                = local.hub_int_psc_api_fr_target
  network               = google_compute_network.hub_int_vpc.self_link
  ip_address            = google_compute_global_address.hub_int_psc_api_fr_addr.id
  load_balancing_scheme = ""
}

# hub-mgt

resource "google_compute_global_address" "hub_mgt_psc_api_fr_addr" {
  provider     = google-beta
  project      = var.project_id_hub
  name         = local.hub_mgt_psc_api_fr_name
  address_type = "INTERNAL"
  purpose      = "PRIVATE_SERVICE_CONNECT"
  network      = google_compute_network.hub_mgt_vpc.self_link
  address      = local.hub_mgt_psc_api_fr_addr
}

resource "google_compute_global_forwarding_rule" "hub_mgt_psc_api_fr" {
  provider              = google-beta
  project               = var.project_id_hub
  name                  = local.hub_mgt_psc_api_fr_name
  target                = local.hub_mgt_psc_api_fr_target
  network               = google_compute_network.hub_mgt_vpc.self_link
  ip_address            = google_compute_global_address.hub_mgt_psc_api_fr_addr.id
  load_balancing_scheme = ""
}

# dns policy
#---------------------------------

resource "google_dns_policy" "hub_dns_policy" {
  provider                  = google-beta
  project                   = var.project_id_hub
  name                      = "${local.hub_prefix}dns-policy"
  enable_inbound_forwarding = false
  enable_logging            = true
  networks { network_url = google_compute_network.hub_vpc.self_link }
  networks { network_url = google_compute_network.hub_mgt_vpc.self_link }
  networks { network_url = google_compute_network.hub_int_vpc.self_link }
}

# dns response policy
#---------------------------------

resource "time_sleep" "hub_dns_forward_to_dns_wait_100s" {
  create_duration = "100s"
  depends_on = [
    google_compute_instance.hub_eu_dns,
    google_compute_instance.hub_us_dns
  ]
}

# policy

resource "google_dns_response_policy" "hub_dns_rp" {
  provider = google-beta
  project  = var.project_id_hub

  response_policy_name = "${local.hub_prefix}dns-rp"
  networks {
    network_url = google_compute_network.hub_vpc.self_link
  }
  depends_on = [time_sleep.hub_dns_forward_to_dns_wait_100s]
}

resource "google_dns_response_policy" "hub_mgt_dns_rp" {
  provider = google-beta
  project  = var.project_id_hub

  response_policy_name = "${local.hub_prefix}mgt-dns-rp"
  networks {
    network_url = google_compute_network.hub_mgt_vpc.self_link
  }
  depends_on = [time_sleep.hub_dns_forward_to_dns_wait_100s]
}

resource "google_dns_response_policy" "hub_int_dns_rp" {
  provider = google-beta
  project  = var.project_id_hub

  response_policy_name = "${local.hub_prefix}int-dns-rp"
  networks {
    network_url = google_compute_network.hub_int_vpc.self_link
  }
  depends_on = [time_sleep.hub_dns_forward_to_dns_wait_100s]
}

# rules - local

locals {
  hub_dns_rp_rules_local = {
    ("${local.hub_prefix}dns-rp-rule-eu-psc-https-ctrl") = {
      dns_name    = "${local.hub_eu_psc_https_ctrl_run_dns}."
      local_datas = { name = "${local.hub_eu_psc_https_ctrl_run_dns}.", type = "A", ttl = 300, rrdatas = [local.hub_eu_ilb7_addr] }
    }
    ("${local.hub_prefix}dns-rp-rule-us-psc-https-ctrl") = {
      dns_name    = "${local.hub_us_psc_https_ctrl_run_dns}."
      local_datas = { name = "${local.hub_us_psc_https_ctrl_run_dns}.", type = "A", ttl = 300, rrdatas = [local.hub_us_ilb7_addr] }
    }
    ("${local.hub_prefix}dns-rp-rule-runapp") = {
      dns_name    = "*.run.app."
      local_datas = { name = "*.run.app.", type = "A", ttl = 300, rrdatas = [local.hub_psc_api_fr_addr] }
    }
    ("${local.hub_prefix}dns-rp-rule-gcr") = {
      dns_name    = "*.gcr.io."
      local_datas = { name = "*.gcr.io.", type = "A", ttl = 300, rrdatas = [local.hub_psc_api_fr_addr] }
    }
    ("${local.hub_prefix}dns-rp-rule-apis") = {
      dns_name    = "*.googleapis.com."
      local_datas = { name = "*.googleapis.com.", type = "A", ttl = 300, rrdatas = [local.hub_psc_api_fr_addr] }
    }
  }
}

resource "google_dns_response_policy_rule" "hub_dns_rp_rules_local" {
  for_each        = local.hub_dns_rp_rules_local
  provider        = google-beta
  project         = var.project_id_hub
  response_policy = google_dns_response_policy.hub_dns_rp.response_policy_name
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

locals {
  hub_mgt_dns_rp_rules_local = {
    ("${local.hub_mgt_prefix}mgt-dns-rp-rule-runapp") = {
      dns_name    = "*.run.app."
      local_datas = { name = "*.run.app.", type = "A", ttl = 300, rrdatas = [local.hub_mgt_psc_api_fr_addr] }
    }
    ("${local.hub_mgt_prefix}mgt-dns-rp-rule-gcr") = {
      dns_name    = "*.gcr.io."
      local_datas = { name = "*.gcr.io.", type = "A", ttl = 300, rrdatas = [local.hub_mgt_psc_api_fr_addr] }
    }
    ("${local.hub_mgt_prefix}mgt-dns-rp-rule-apis") = {
      dns_name    = "*.googleapis.com."
      local_datas = { name = "*.googleapis.com.", type = "A", ttl = 300, rrdatas = [local.hub_mgt_psc_api_fr_addr] }
    }
  }
}

resource "google_dns_response_policy_rule" "hub_mgt_dns_rp_rules_local" {
  for_each        = local.hub_mgt_dns_rp_rules_local
  provider        = google-beta
  project         = var.project_id_hub
  response_policy = google_dns_response_policy.hub_mgt_dns_rp.response_policy_name
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

locals {
  hub_int_dns_rp_rules_local = {
    ("${local.hub_int_prefix}int-dns-rp-rule-runapp") = {
      dns_name    = "*.run.app."
      local_datas = { name = "*.run.app.", type = "A", ttl = 300, rrdatas = [local.hub_int_psc_api_fr_addr] }
    }
    ("${local.hub_int_prefix}int-dns-rp-rule-gcr") = {
      dns_name    = "*.gcr.io."
      local_datas = { name = "*.gcr.io.", type = "A", ttl = 300, rrdatas = [local.hub_int_psc_api_fr_addr] }
    }
    ("${local.hub_int_prefix}int-dns-rp-rule-apis") = {
      dns_name    = "*.googleapis.com."
      local_datas = { name = "*.googleapis.com.", type = "A", ttl = 300, rrdatas = [local.hub_int_psc_api_fr_addr] }
    }
  }
}

resource "google_dns_response_policy_rule" "hub_int_dns_rp_rules_local" {
  for_each        = local.hub_int_dns_rp_rules_local
  provider        = google-beta
  project         = var.project_id_hub
  response_policy = google_dns_response_policy.hub_int_dns_rp.response_policy_name
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
  hub_dns_rp_rules_bypass = {
    ("${local.hub_prefix}dns-rp-rule-bypass-www")    = { dns_name = "www.googleapis.com." }
    ("${local.hub_prefix}dns-rp-rule-bypass-ouath2") = { dns_name = "oauth2.googleapis.com." }
    ("${local.hub_prefix}dns-rp-rule-bypass-psc")    = { dns_name = "*.p.googleapis.com." }
  }
  hub_dns_rp_rules_bypass_create = templatefile("scripts/dns/rule-bypass-create.sh", {
    PROJECT = var.project_id_hub
    RP_NAME = google_dns_response_policy.hub_dns_rp.response_policy_name
    RULES   = local.hub_dns_rp_rules_bypass
  })
  hub_dns_rp_rules_bypass_delete = templatefile("scripts/dns/rule-delete.sh", {
    PROJECT = var.project_id_hub
    RP_NAME = google_dns_response_policy.hub_dns_rp.response_policy_name
    RULES   = local.hub_dns_rp_rules_bypass
  })
}

resource "null_resource" "hub_dns_rp_rules_bypass" {
  triggers = {
    create = local.hub_dns_rp_rules_bypass_create
    delete = local.hub_dns_rp_rules_bypass_delete
  }
  provisioner "local-exec" {
    command = self.triggers.create
  }
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete
  }
}

locals {
  hub_mgt_dns_rp_rules_bypass = {
    ("${local.hub_prefix}mgt-dns-rp-rule-bypass-www")    = { dns_name = "www.googleapis.com." }
    ("${local.hub_prefix}mgt-dns-rp-rule-bypass-ouath2") = { dns_name = "oauth2.googleapis.com." }
    ("${local.hub_prefix}mgt-dns-rp-rule-bypass-psc")    = { dns_name = "*.p.googleapis.com." }
  }
  hub_mgt_dns_rp_rules_bypass_create = templatefile("scripts/dns/rule-bypass-create.sh", {
    PROJECT = var.project_id_hub
    RP_NAME = google_dns_response_policy.hub_mgt_dns_rp.response_policy_name
    RULES   = local.hub_mgt_dns_rp_rules_bypass
  })
  hub_mgt_dns_rp_rules_bypass_delete = templatefile("scripts/dns/rule-delete.sh", {
    PROJECT = var.project_id_hub
    RP_NAME = google_dns_response_policy.hub_mgt_dns_rp.response_policy_name
    RULES   = local.hub_mgt_dns_rp_rules_bypass
  })
}

resource "null_resource" "hub_mgt_dns_rp_rules_bypass" {
  triggers = {
    create = local.hub_mgt_dns_rp_rules_bypass_create
    delete = local.hub_mgt_dns_rp_rules_bypass_delete
  }
  provisioner "local-exec" {
    command = self.triggers.create
  }
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete
  }
}

locals {
  hub_int_dns_rp_rules_bypass = {
    ("${local.hub_prefix}int-dns-rp-rule-bypass-www")    = { dns_name = "www.googleapis.com." }
    ("${local.hub_prefix}int-dns-rp-rule-bypass-ouath2") = { dns_name = "oauth2.googleapis.com." }
    ("${local.hub_prefix}int-dns-rp-rule-bypass-psc")    = { dns_name = "*.p.googleapis.com." }
  }
  hub_int_dns_rp_rules_bypass_create = templatefile("scripts/dns/rule-bypass-create.sh", {
    PROJECT = var.project_id_hub
    RP_NAME = google_dns_response_policy.hub_int_dns_rp.response_policy_name
    RULES   = local.hub_int_dns_rp_rules_bypass
  })
  hub_int_dns_rp_rules_bypass_delete = templatefile("scripts/dns/rule-delete.sh", {
    PROJECT = var.project_id_hub
    RP_NAME = google_dns_response_policy.hub_int_dns_rp.response_policy_name
    RULES   = local.hub_int_dns_rp_rules_bypass
  })
}

resource "null_resource" "hub_int_dns_rp_rules_bypass" {
  triggers = {
    create = local.hub_int_dns_rp_rules_bypass_create
    delete = local.hub_int_dns_rp_rules_bypass_delete
  }
  provisioner "local-exec" {
    command = self.triggers.create
  }
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete
  }
}

# cloud dns
#---------------------------------

# onprem zone

module "hub_dns_peering_to_hub_onprem" {
  source      = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns"
  project_id  = var.project_id_hub
  type        = "peering"
  name        = "${local.hub_prefix}to-hub-onprem"
  domain      = "${local.onprem_domain}."
  description = "${local.onprem_domain}."
  client_networks = [
    google_compute_network.hub_mgt_vpc.self_link,
    google_compute_network.hub_int_vpc.self_link,
  ]
  peer_network = google_compute_network.hub_vpc.self_link
}

module "hub_dns_forward_to_onprem" {
  source      = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns"
  project_id  = var.project_id_hub
  type        = "forwarding"
  name        = "${local.hub_prefix}to-onprem"
  domain      = "${local.onprem_domain}."
  description = "local data"
  forwarders = {
    (local.hub_eu_ns_addr) = "private"
    (local.hub_us_ns_addr) = "private"
  }
  client_networks = [google_compute_network.hub_vpc.self_link, ]
}

# psc zone

module "hub_dns_psc" {
  source          = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns"
  project_id      = var.project_id_hub
  type            = "private"
  name            = "${local.hub_prefix}psc"
  domain          = "${local.hub_psc_api_fr_name}.p.googleapis.com."
  description     = "psc"
  client_networks = [google_compute_network.hub_vpc.self_link, ]
  recordsets      = { "A " = { type = "A", ttl = 300, records = [local.hub_psc_api_fr_addr] } }
  depends_on      = [time_sleep.hub_dns_forward_to_unbound_wait_100s]
}

module "hub_int_dns_psc" {
  source          = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns"
  project_id      = var.project_id_hub
  type            = "private"
  name            = "${local.hub_prefix}int-psc"
  domain          = "${local.hub_int_psc_api_fr_name}.p.googleapis.com."
  description     = "psc"
  client_networks = [google_compute_network.hub_int_vpc.self_link, ]
  recordsets      = { "A " = { type = "A", ttl = 300, records = [local.hub_int_psc_api_fr_addr] } }
  depends_on      = [time_sleep.hub_dns_forward_to_unbound_wait_100s]
}

module "hub_mgt_dns_psc" {
  source          = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns"
  project_id      = var.project_id_hub
  type            = "private"
  name            = "${local.hub_prefix}mgt-psc"
  domain          = "${local.hub_mgt_psc_api_fr_name}.p.googleapis.com."
  description     = "psc"
  client_networks = [google_compute_network.hub_mgt_vpc.self_link, ]
  recordsets      = { "A " = { type = "A", ttl = 300, records = [local.hub_mgt_psc_api_fr_addr] } }
  depends_on      = [time_sleep.hub_dns_forward_to_unbound_wait_100s]
}

# local zone

module "hub_dns_private_zone" {
  source      = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns"
  project_id  = var.project_id_hub
  type        = "private"
  name        = "${local.hub_prefix}private"
  domain      = "${local.hub_domain}.${local.cloud_domain}."
  description = "local data"
  client_networks = [
    google_compute_network.hub_vpc.self_link,
    google_compute_network.hub_mgt_vpc.self_link,
    google_compute_network.hub_int_vpc.self_link,
  ]
  recordsets = {
    "A ${local.hub_eu_nva_ilb4_dns}" = { type = "A", ttl = 300, records = [local.hub_eu_nva_ilb4_addr] },
    "A ${local.hub_us_nva_ilb4_dns}" = { type = "A", ttl = 300, records = [local.hub_us_nva_ilb4_addr] },
    "A ${local.hub_eu_ilb4_dns}"     = { type = "A", ttl = 300, records = [local.hub_eu_ilb4_addr] },
    "A ${local.hub_us_ilb4_dns}"     = { type = "A", ttl = 300, records = [local.hub_us_ilb4_addr] },
    "A ${local.hub_eu_ilb7_dns}"     = { type = "A", ttl = 300, records = [local.hub_eu_ilb7_addr] },
    "A ${local.hub_us_ilb7_dns}"     = { type = "A", ttl = 300, records = [local.hub_us_ilb7_addr] },
    "A ${local.hub_mgt_eu_app1_dns}" = { type = "A", ttl = 300, records = [local.hub_mgt_eu_app1_addr] },
    "A ${local.hub_mgt_us_app1_dns}" = { type = "A", ttl = 300, records = [local.hub_mgt_us_app1_addr] },
  }
}

# sd zone

module "hub_sd_td" {
  source      = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns"
  project_id  = var.project_id_hub
  type        = "service-directory"
  name        = "${local.hub_prefix}sd-td"
  domain      = "${local.hub_td_domain}."
  description = google_service_directory_namespace.hub_td.id
  client_networks = [
    google_compute_network.hub_vpc.self_link,
    google_compute_network.hub_mgt_vpc.self_link,
    google_compute_network.hub_int_vpc.self_link,
  ]
  service_directory_namespace = google_service_directory_namespace.hub_td.id
}

module "hub_sd_psc" {
  source      = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns"
  project_id  = var.project_id_hub
  type        = "service-directory"
  name        = "${local.hub_prefix}sd-psc"
  domain      = "${local.hub_psc_domain}."
  description = google_service_directory_namespace.hub_psc.id
  client_networks = [
    google_compute_network.hub_vpc.self_link,
    google_compute_network.hub_mgt_vpc.self_link,
    google_compute_network.hub_int_vpc.self_link,
  ]
  service_directory_namespace = google_service_directory_namespace.hub_psc.id
}

# reverse zones

locals {
  _spoke1_eu_subnet1_reverse_custom         = split("/", local.spoke1_subnets["${local.spoke1_prefix}eu-subnet1"].ip_cidr_range).0
  _spoke1_us_subnet1_reverse_custom         = split("/", local.spoke1_subnets["${local.spoke1_prefix}us-subnet1"].ip_cidr_range).0
  _spoke1_eu_random_google_reverse_internal = cidrhost(local.spoke1_subnets["${local.spoke1_prefix}eu-subnet1"].ip_cidr_range, 254)
  spoke1_eu_subnet1_reverse_custom = (format("%s.%s.%s.in-addr.arpa.",
    element(split(".", local._spoke1_eu_subnet1_reverse_custom), 2),
    element(split(".", local._spoke1_eu_subnet1_reverse_custom), 1),
    element(split(".", local._spoke1_eu_subnet1_reverse_custom), 0),
  ))
  spoke1_us_subnet1_reverse_custom = (format("%s.%s.%s.in-addr.arpa.",
    element(split(".", local._spoke1_us_subnet1_reverse_custom), 2),
    element(split(".", local._spoke1_us_subnet1_reverse_custom), 1),
    element(split(".", local._spoke1_us_subnet1_reverse_custom), 0),
  ))
  spoke1_eu_random_google_reverse_internal = (format("%s.%s.%s.%s.in-addr.arpa.",
    element(split(".", local._spoke1_eu_random_google_reverse_internal), 3),
    element(split(".", local._spoke1_eu_random_google_reverse_internal), 2),
    element(split(".", local._spoke1_eu_random_google_reverse_internal), 1),
    element(split(".", local._spoke1_eu_random_google_reverse_internal), 0),
  ))
}

locals {
  _spoke2_eu_subnet1_reverse_custom          = split("/", local.spoke2_subnets["${local.spoke2_prefix}eu-subnet1"].ip_cidr_range).0
  _spoke2_us_subnet1_reverse_custom          = split("/", local.spoke2_subnets["${local.spoke2_prefix}us-subnet1"].ip_cidr_range).0
  _spoke2_eu_test_vm_google_reverse_internal = google_compute_instance.spoke2_eu_test_vm.network_interface.0.network_ip
  spoke2_eu_subnet1_reverse_custom = (format("%s.%s.%s.in-addr.arpa.",
    element(split(".", local._spoke2_eu_subnet1_reverse_custom), 2),
    element(split(".", local._spoke2_eu_subnet1_reverse_custom), 1),
    element(split(".", local._spoke2_eu_subnet1_reverse_custom), 0),
  ))
  spoke2_us_subnet1_reverse_custom = (format("%s.%s.%s.in-addr.arpa.",
    element(split(".", local._spoke2_us_subnet1_reverse_custom), 2),
    element(split(".", local._spoke2_us_subnet1_reverse_custom), 1),
    element(split(".", local._spoke2_us_subnet1_reverse_custom), 0),
  ))
  spoke2_eu_test_vm_google_reverse_internal = (format("%s.%s.%s.%s.in-addr.arpa.",
    element(split(".", local._spoke2_eu_test_vm_google_reverse_internal), 3),
    element(split(".", local._spoke2_eu_test_vm_google_reverse_internal), 2),
    element(split(".", local._spoke2_eu_test_vm_google_reverse_internal), 1),
    element(split(".", local._spoke2_eu_test_vm_google_reverse_internal), 0),
  ))
}

module "spoke1_eu_subnet1_reverse_custom" {
  source      = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns"
  project_id  = var.project_id_hub
  type        = "private"
  name        = "${local.spoke1_prefix}eu-subnet1-reverse-custom"
  domain      = local.spoke1_eu_subnet1_reverse_custom
  description = "eu-subnet1 reverse custom zone"
  client_networks = [
    google_compute_network.hub_vpc.self_link,
    google_compute_network.hub_mgt_vpc.self_link,
    google_compute_network.hub_int_vpc.self_link,
  ]
  recordsets = {
    "PTR 30" = { type = "PTR", ttl = 300, records = ["${local.spoke1_eu_ilb4_dns}.${local.spoke1_domain}.${local.cloud_domain}."] },
    "PTR 40" = { type = "PTR", ttl = 300, records = ["${local.spoke1_eu_ilb7_dns}.${local.spoke1_domain}.${local.cloud_domain}."] },
  }
}

module "spoke1_us_subnet1_reverse_custom" {
  source      = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns"
  project_id  = var.project_id_hub
  type        = "private"
  name        = "${local.spoke1_prefix}us-subnet1-reverse-custom"
  domain      = local.spoke1_us_subnet1_reverse_custom
  description = "us-subnet1 reverse custom zone"
  client_networks = [
    google_compute_network.hub_vpc.self_link,
    google_compute_network.hub_mgt_vpc.self_link,
    google_compute_network.hub_int_vpc.self_link,
  ]
  recordsets = {
    "PTR 30" = { type = "PTR", ttl = 300, records = ["${local.spoke1_us_ilb4_dns}.${local.spoke1_domain}.${local.cloud_domain}."] },
    "PTR 40" = { type = "PTR", ttl = 300, records = ["${local.spoke1_us_ilb7_dns}.${local.spoke1_domain}.${local.cloud_domain}."] },
  }
}

module "spoke2_eu_subnet1_reverse_custom" {
  source      = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns"
  project_id  = var.project_id_hub
  type        = "private"
  name        = "${local.spoke2_prefix}eu-subnet1-reverse-custom"
  domain      = local.spoke2_eu_subnet1_reverse_custom
  description = "eu-subnet1 reverse custom zone"
  client_networks = [
    google_compute_network.hub_vpc.self_link,
    google_compute_network.hub_mgt_vpc.self_link,
    google_compute_network.hub_int_vpc.self_link,
  ]
  recordsets = {
    "PTR 30" = { type = "PTR", ttl = 300, records = ["${local.spoke2_eu_ilb4_dns}.${local.spoke2_domain}.${local.cloud_domain}."] },
    "PTR 40" = { type = "PTR", ttl = 300, records = ["${local.spoke2_eu_ilb7_dns}.${local.spoke2_domain}.${local.cloud_domain}."] },
  }
}

module "spoke2_us_subnet1_reverse_custom" {
  source      = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns"
  project_id  = var.project_id_hub
  type        = "private"
  name        = "${local.spoke2_prefix}us-subnet1-reverse-custom"
  domain      = local.spoke2_us_subnet1_reverse_custom
  description = "us-subnet1 reverse custom zone"
  client_networks = [
    google_compute_network.hub_vpc.self_link,
    google_compute_network.hub_mgt_vpc.self_link,
    google_compute_network.hub_int_vpc.self_link,
  ]
  recordsets = {
    "PTR 30" = { type = "PTR", ttl = 300, records = ["${local.spoke2_us_ilb4_dns}.${local.spoke2_domain}.${local.cloud_domain}."] },
    "PTR 40" = { type = "PTR", ttl = 300, records = ["${local.spoke2_us_ilb7_dns}.${local.spoke2_domain}.${local.cloud_domain}."] },
  }
}

# reverse zone (google-managed reverse lookup for everything else)

resource "google_dns_managed_zone" "spoke1_eu_random_google_reverse_internal" {
  provider       = google-beta
  project        = var.project_id_hub
  name           = "${local.spoke1_prefix}eu-random-google-reverse-internal"
  dns_name       = local.spoke1_eu_random_google_reverse_internal
  description    = "random reverse internal zone"
  visibility     = "private"
  reverse_lookup = true
  private_visibility_config {
    networks { network_url = google_compute_network.hub_vpc.self_link }
    networks { network_url = google_compute_network.hub_mgt_vpc.self_link }
    networks { network_url = google_compute_network.hub_int_vpc.self_link }
  }
}

resource "google_dns_managed_zone" "spoke2_eu_test_vm_google_reverse_internal" {
  provider       = google-beta
  project        = var.project_id_hub
  name           = "${local.spoke2_prefix}eu-test-vm-google-reverse-internal"
  dns_name       = local.spoke2_eu_test_vm_google_reverse_internal
  description    = "eu-test-vm reverse internal zone"
  visibility     = "private"
  reverse_lookup = true
  private_visibility_config {
    networks { network_url = google_compute_network.hub_vpc.self_link }
    networks { network_url = google_compute_network.hub_mgt_vpc.self_link }
    networks { network_url = google_compute_network.hub_int_vpc.self_link }
  }
}

# nva: instances
#---------------------------------

# eu

resource "google_compute_instance" "hub_eu_nva" {
  project        = var.project_id_hub
  name           = "${local.hub_prefix}eu-nva"
  machine_type   = "e2-standard-4"
  zone           = "${local.hub_eu_region}-b"
  tags           = [local.tag_ssh, local.tag_gfe, local.tag_dns, ]
  can_ip_forward = true
  boot_disk {
    initialize_params {
      image = var.image_debian
      size  = var.disk_size
      type  = var.disk_type
    }
  }
  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }
  network_interface {
    network    = google_compute_network.hub_vpc.self_link
    subnetwork = local.hub_eu_subnet1.self_link
    network_ip = local.hub_eu_nva_vm_addr
  }
  network_interface {
    network    = google_compute_network.hub_int_vpc.self_link
    subnetwork = local.hub_int_eu_subnet1.self_link
    network_ip = local.hub_int_eu_nva_vm_addr
  }
  network_interface {
    network    = google_compute_network.hub_mgt_vpc.self_link
    subnetwork = local.hub_mgt_eu_subnet1.self_link
    network_ip = local.hub_mgt_eu_nva_vm_addr
  }
  service_account {
    email  = module.hub_sa.email
    scopes = ["cloud-platform"]
  }
  metadata_startup_script = local.hub_nva_eu_startup
}

resource "local_file" "hub_eu_nva" {
  content  = google_compute_instance.hub_eu_nva.metadata_startup_script
  filename = "config/hub/${local.hub_prefix}eu-nva.sh"
}

resource "google_compute_instance_group" "hub_eu_ig_nva" {
  project   = var.project_id_hub
  name      = "${local.hub_prefix}eu-ig-nva"
  zone      = "${local.hub_eu_region}-b"
  instances = [google_compute_instance.hub_eu_nva.self_link]
  named_port {
    name = local.hub_svc_8001.name
    port = local.hub_svc_8001.port
  }
  named_port {
    name = local.hub_svc_8002.name
    port = local.hub_svc_8002.port
  }
}

# us

resource "google_compute_instance" "hub_us_nva" {
  project        = var.project_id_hub
  name           = "${local.hub_prefix}us-nva"
  machine_type   = "e2-standard-4"
  zone           = "${local.hub_us_region}-b"
  tags           = [local.tag_ssh, local.tag_gfe, local.tag_dns, ]
  can_ip_forward = true
  boot_disk {
    initialize_params {
      image = var.image_debian
      size  = var.disk_size
      type  = var.disk_type
    }
  }
  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }
  network_interface {
    network    = google_compute_network.hub_vpc.self_link
    subnetwork = local.hub_us_subnet1.self_link
    network_ip = local.hub_us_nva_vm_addr
  }
  network_interface {
    network    = google_compute_network.hub_int_vpc.self_link
    subnetwork = local.hub_int_us_subnet1.self_link
    network_ip = local.hub_int_us_nva_vm_addr
  }
  network_interface {
    network    = google_compute_network.hub_mgt_vpc.self_link
    subnetwork = local.hub_mgt_us_subnet1.self_link
    network_ip = local.hub_mgt_us_nva_vm_addr
  }
  service_account {
    email  = module.hub_sa.email
    scopes = ["cloud-platform"]
  }
  metadata_startup_script = local.hub_nva_us_startup
}

resource "google_compute_instance_group" "hub_us_ig_nva" {
  project   = var.project_id_hub
  name      = "${local.hub_prefix}us-ig-nva"
  zone      = "${local.hub_us_region}-b"
  instances = [google_compute_instance.hub_us_nva.self_link]
  named_port {
    name = local.hub_svc_8001.name
    port = local.hub_svc_8001.port
  }
  named_port {
    name = local.hub_svc_8002.name
    port = local.hub_svc_8002.port
  }
}

resource "local_file" "hub_us_nva" {
  content  = google_compute_instance.hub_us_nva.metadata_startup_script
  filename = "config/hub/${local.hub_prefix}us-nva.sh"
}

# nva: ilb4
#---------------------------------

# hub

module "hub_eu_ilb4_nva" {
  source        = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-ilb"
  project_id    = var.project_id_hub
  region        = local.hub_eu_region
  name          = "${local.hub_prefix}eu-ilb4-nva"
  service_label = "${local.hub_prefix}eu-ilb4-nva"
  network       = google_compute_network.hub_vpc.self_link
  subnetwork    = local.hub_eu_subnet1.self_link
  address       = local.hub_eu_nva_ilb4_addr
  backends = [{
    failover       = false
    group          = google_compute_instance_group.hub_eu_ig_nva.self_link
    balancing_mode = "CONNECTION"
  }]
  health_check_config = {
    type = "http"
    check = {
      port               = local.svc_web.port
      host               = local.uhc_config.host
      request_path       = "/${local.uhc_config.request_path}"
      response           = local.uhc_config.response
      port_specification = "USE_FIXED_PORT"
    }
    config  = {}
    logging = true
  }
  ports         = null
  global_access = true
}

module "hub_us_ilb4_nva" {
  source        = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-ilb"
  project_id    = var.project_id_hub
  region        = local.hub_us_region
  name          = "${local.hub_prefix}us-ilb4-nva"
  service_label = "${local.hub_prefix}us-ilb4-nva"
  network       = google_compute_network.hub_vpc.self_link
  subnetwork    = local.hub_us_subnet1.self_link
  address       = local.hub_us_nva_ilb4_addr
  backends = [{
    failover       = false
    group          = google_compute_instance_group.hub_us_ig_nva.self_link
    balancing_mode = "CONNECTION"
  }]
  health_check_config = {
    type = "http"
    check = {
      port               = local.svc_web.port
      host               = local.uhc_config.host
      request_path       = "/${local.uhc_config.request_path}"
      response           = local.uhc_config.response
      port_specification = "USE_FIXED_PORT"
    }
    config  = {}
    logging = true
  }
  ports         = null
  global_access = true
}

# hub-mgt

module "hub_mgt_eu_ilb4_nva" {
  source        = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-ilb"
  project_id    = var.project_id_hub
  region        = local.hub_eu_region
  name          = "${local.hub_prefix}mgt-eu-ilb4-nva"
  service_label = "${local.hub_prefix}mgt-eu-ilb4-nva"
  network       = google_compute_network.hub_mgt_vpc.self_link
  subnetwork    = local.hub_mgt_eu_subnet1.self_link
  address       = local.hub_mgt_eu_nva_ilb4_addr
  backends = [{
    failover       = false
    group          = google_compute_instance_group.hub_eu_ig_nva.self_link
    balancing_mode = "CONNECTION"
  }]
  health_check_config = {
    type = "http"
    check = {
      port               = local.svc_web.port
      host               = local.uhc_config.host
      request_path       = "/${local.uhc_config.request_path}"
      response           = local.uhc_config.response
      port_specification = "USE_FIXED_PORT"
    }
    config  = {}
    logging = true
  }
  ports         = null
  global_access = true
}

module "hub_mgt_us_ilb4_nva" {
  source        = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-ilb"
  project_id    = var.project_id_hub
  region        = local.hub_us_region
  name          = "${local.hub_prefix}mgt-us-ilb4-nva"
  service_label = "${local.hub_prefix}mgt-us-ilb4-nva"
  network       = google_compute_network.hub_mgt_vpc.self_link
  subnetwork    = local.hub_mgt_us_subnet1.self_link
  address       = local.hub_mgt_us_nva_ilb4_addr
  backends = [{
    failover       = false
    group          = google_compute_instance_group.hub_us_ig_nva.self_link
    balancing_mode = "CONNECTION"
  }]
  health_check_config = {
    type = "http"
    check = {
      port               = local.svc_web.port
      host               = local.uhc_config.host
      request_path       = "/${local.uhc_config.request_path}"
      response           = local.uhc_config.response
      port_specification = "USE_FIXED_PORT"
    }
    config  = {}
    logging = true
  }
  ports         = null
  global_access = true
}

# hub-int

module "hub_int_eu_ilb4_nva" {
  source        = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-ilb"
  project_id    = var.project_id_hub
  region        = local.hub_eu_region
  name          = "${local.hub_prefix}int-ilb4-nva"
  service_label = "${local.hub_prefix}int-ilb4-nva"
  network       = google_compute_network.hub_int_vpc.self_link
  subnetwork    = local.hub_int_eu_subnet1.self_link
  address       = local.hub_int_eu_nva_ilb4_addr
  backends = [{
    failover       = false
    group          = google_compute_instance_group.hub_eu_ig_nva.self_link
    balancing_mode = "CONNECTION"
  }]
  health_check_config = {
    type = "http"
    check = {
      port               = local.svc_web.port
      host               = local.uhc_config.host
      request_path       = "/${local.uhc_config.request_path}"
      response           = local.uhc_config.response
      port_specification = "USE_FIXED_PORT"
    }
    config  = {}
    logging = true
  }
  ports         = null
  global_access = true
}

module "hub_int_us_ilb4_nva" {
  source        = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-ilb"
  project_id    = var.project_id_hub
  region        = local.hub_us_region
  name          = "${local.hub_prefix}int-us-ilb4-nva"
  service_label = "${local.hub_prefix}int-us-ilb4-nva"
  network       = google_compute_network.hub_int_vpc.self_link
  subnetwork    = local.hub_int_us_subnet1.self_link
  address       = local.hub_int_us_nva_ilb4_addr
  backends = [{
    failover       = false
    group          = google_compute_instance_group.hub_us_ig_nva.self_link
    balancing_mode = "CONNECTION"
  }]
  health_check_config = {
    type = "http"
    check = {
      port               = local.svc_web.port
      host               = local.uhc_config.host
      request_path       = "/${local.uhc_config.request_path}"
      response           = local.uhc_config.response
      port_specification = "USE_FIXED_PORT"
    }
    config  = {}
    logging = true
  }
  ports         = null
  global_access = true
}

# ilb4: hub-eu
#---------------------------------

# instance

resource "google_compute_instance" "hub_eu_ilb4_vm" {
  project      = var.project_id_hub
  name         = "${local.hub_prefix}eu-ilb4-vm"
  zone         = "${local.hub_eu_region}-b"
  machine_type = var.machine_type
  tags         = [local.tag_ssh, local.tag_gfe]
  boot_disk {
    initialize_params {
      image = var.image_debian
      size  = var.disk_size
      type  = var.disk_type
    }
  }
  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }
  network_interface {
    network    = google_compute_network.hub_vpc.self_link
    subnetwork = local.hub_eu_subnet1.self_link
  }
  service_account {
    email  = module.hub_sa.email
    scopes = ["cloud-platform"]
  }
  metadata_startup_script   = local.vm_startup
  allow_stopping_for_update = true
}

# instance group

resource "google_compute_instance_group" "hub_eu_ilb4_ig" {
  project   = var.project_id_hub
  zone      = "${local.hub_eu_region}-b"
  name      = "${local.hub_prefix}eu-ilb4-ig"
  instances = [google_compute_instance.hub_eu_ilb4_vm.self_link]
  named_port {
    name = local.svc_web.name
    port = local.svc_web.port
  }
}

# ilb4

module "hub_eu_ilb4" {
  source        = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-ilb"
  project_id    = var.project_id_hub
  region        = local.hub_eu_region
  name          = "${local.hub_prefix}eu-ilb4"
  service_label = "${local.hub_prefix}eu-ilb4"
  network       = google_compute_network.hub_vpc.self_link
  subnetwork    = local.hub_eu_subnet1.self_link
  address       = local.hub_eu_ilb4_addr
  backends = [{
    failover       = false
    group          = google_compute_instance_group.hub_eu_ilb4_ig.self_link
    balancing_mode = "CONNECTION"
  }]
  health_check_config = {
    type    = "http"
    config  = {}
    logging = true
    check = {
      port_specification = "USE_FIXED_PORT"
      port               = local.svc_web.port
      host               = local.uhc_config.host
      request_path       = "/${local.uhc_config.request_path}"
      response           = local.uhc_config.response
    }
  }
  global_access = true
}

# ilb4: hub-us
#---------------------------------

# instance

resource "google_compute_instance" "hub_us_ilb4_vm" {
  project      = var.project_id_hub
  name         = "${local.hub_prefix}us-ilb4-vm"
  zone         = "${local.hub_us_region}-b"
  machine_type = var.machine_type
  tags         = [local.tag_ssh, local.tag_gfe]
  boot_disk {
    initialize_params {
      image = var.image_debian
      size  = var.disk_size
      type  = var.disk_type
    }
  }
  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }
  network_interface {
    network    = google_compute_network.hub_vpc.self_link
    subnetwork = local.hub_us_subnet1.self_link
  }
  service_account {
    email  = module.hub_sa.email
    scopes = ["cloud-platform"]
  }
  metadata_startup_script   = local.vm_startup
  allow_stopping_for_update = true
}

# instance group

resource "google_compute_instance_group" "hub_us_ilb4_ig" {
  project   = var.project_id_hub
  zone      = "${local.hub_us_region}-b"
  name      = "${local.hub_prefix}us-ilb4-ig"
  instances = [google_compute_instance.hub_us_ilb4_vm.self_link]
  named_port {
    name = local.svc_web.name
    port = local.svc_web.port
  }
}

# ilb4

module "hub_us_ilb4" {
  source        = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-ilb"
  project_id    = var.project_id_hub
  region        = local.hub_us_region
  name          = "${local.hub_prefix}us-ilb4"
  service_label = "${local.hub_prefix}us-ilb4"
  network       = google_compute_network.hub_vpc.self_link
  subnetwork    = local.hub_us_subnet1.self_link
  address       = local.hub_us_ilb4_addr
  backends = [{
    failover       = false
    group          = google_compute_instance_group.hub_us_ilb4_ig.self_link
    balancing_mode = "CONNECTION"
  }]
  health_check_config = {
    type    = "http"
    config  = {}
    logging = true
    check = {
      port_specification = "USE_FIXED_PORT"
      port               = local.svc_web.port
      host               = local.uhc_config.host
      request_path       = "/${local.uhc_config.request_path}"
      response           = local.uhc_config.response
    }
  }
  global_access = true
}

# ilb7: hub-eu
#---------------------------------

locals {
  hub_eu_ilb7_domains = [
    "${local.hub_eu_ilb7_dns}.${local.hub_domain}.${local.cloud_domain}",
    local.hub_eu_psc_https_ctrl_run_dns
  ]
}

# instance

resource "google_compute_instance" "hub_eu_ilb7_vm" {
  project      = var.project_id_hub
  name         = "${local.hub_prefix}eu-ilb7-vm"
  zone         = "${local.hub_eu_region}-b"
  machine_type = var.machine_type
  tags         = [local.tag_ssh, local.tag_gfe]
  boot_disk {
    initialize_params {
      image = var.image_debian
      size  = var.disk_size
      type  = var.disk_type
    }
  }
  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }
  network_interface {
    network    = google_compute_network.hub_vpc.self_link
    subnetwork = local.hub_eu_subnet1.self_link
  }
  service_account {
    email  = module.hub_sa.email
    scopes = ["cloud-platform"]
  }
  metadata_startup_script   = local.vm_startup
  allow_stopping_for_update = true
}

# ig

resource "google_compute_instance_group" "hub_eu_ilb7_ig" {
  project   = var.project_id_hub
  zone      = "${local.hub_eu_region}-b"
  name      = "${local.hub_prefix}eu-ilb7-ig"
  instances = [google_compute_instance.hub_eu_ilb7_vm.self_link]
  named_port {
    name = local.svc_web.name
    port = local.svc_web.port
  }
}

# psc neg

locals {
  hub_eu_ilb7_psc_api_neg_name      = "${local.hub_prefix}eu-ilb7-psc-api-neg"
  hub_eu_ilb7_psc_api_neg_self_link = "projects/${var.project_id_hub}/regions/${local.hub_eu_region}/networkEndpointGroups/${local.hub_eu_ilb7_psc_api_neg_name}"
  hub_eu_ilb7_psc_api_neg_create = templatefile("scripts/neg/psc/create.sh", {
    PROJECT_ID     = var.project_id_hub
    NETWORK        = google_compute_network.hub_vpc.self_link
    REGION         = local.hub_eu_region
    NEG_NAME       = local.hub_eu_ilb7_psc_api_neg_name
    TARGET_SERVICE = local.hub_eu_psc_https_ctrl_run_dns
  })
  hub_eu_ilb7_psc_api_neg_delete = templatefile("scripts/neg/psc/delete.sh", {
    PROJECT_ID = var.project_id_hub
    REGION     = local.hub_eu_region
    NEG_NAME   = local.hub_eu_ilb7_psc_api_neg_name
  })
}

resource "null_resource" "hub_eu_ilb7_psc_api_neg" {
  triggers = {
    create = local.hub_eu_ilb7_psc_api_neg_create
    delete = local.hub_eu_ilb7_psc_api_neg_delete
  }
  provisioner "local-exec" {
    command = self.triggers.create
  }
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete
  }
}

# backend

locals {
  hub_eu_ilb7_backend_services_mig = {
    ("main") = {
      port_name = local.svc_web.name
      backends = [
        {
          group                 = google_compute_instance_group.hub_eu_ilb7_ig.self_link
          balancing_mode        = "RATE"
          max_rate_per_instance = 100
          capacity_scaler       = 1.0
        },
      ]
      health_check_config = {
        config  = {}
        logging = true
        check = {
          port_specification = "USE_SERVING_PORT"
          host               = local.uhc_config.host
          request_path       = "/${local.uhc_config.request_path}"
          response           = local.uhc_config.response
        }
      }
    }
  }
  hub_eu_ilb7_backend_services_psc_neg = {
    ("api") = {
      port = local.svc_web.port
      backends = [
        {
          group           = local.hub_eu_ilb7_psc_api_neg_self_link
          balancing_mode  = "UTILIZATION"
          capacity_scaler = 1.0
        },
      ]
      health_check_config = {
        config  = {}
        logging = true
        check   = {}
      }
    }
  }
  hub_eu_ilb7_backend_services_neg = {}
}

module "hub_eu_ilb7_bes" {
  depends_on               = [null_resource.hub_eu_ilb7_psc_api_neg]
  source                   = "../../modules/backend-region"
  project_id               = var.project_id_hub
  prefix                   = "${local.hub_prefix}eu-ilb7"
  network                  = google_compute_network.hub_vpc.self_link
  region                   = local.hub_eu_region
  backend_services_mig     = local.hub_eu_ilb7_backend_services_mig
  backend_services_neg     = local.hub_eu_ilb7_backend_services_neg
  backend_services_psc_neg = local.hub_eu_ilb7_backend_services_psc_neg
}

# url map

resource "google_compute_region_url_map" "hub_eu_ilb7_url_map" {
  provider        = google-beta
  project         = var.project_id_hub
  name            = "${local.hub_prefix}eu-ilb7-url-map"
  region          = local.hub_eu_region
  default_service = module.hub_eu_ilb7_bes.backend_service_mig["main"].id
  host_rule {
    path_matcher = "main"
    hosts        = ["${local.hub_eu_ilb7_dns}.${local.hub_domain}.${local.cloud_domain}"]
  }
  host_rule {
    path_matcher = "api"
    hosts        = [local.hub_eu_psc_https_ctrl_run_dns]
  }
  path_matcher {
    name            = "main"
    default_service = module.hub_eu_ilb7_bes.backend_service_mig["main"].self_link
  }
  path_matcher {
    name            = "api"
    default_service = module.hub_eu_ilb7_bes.backend_service_psc_neg["api"].self_link
  }
}

# frontend

module "hub_eu_ilb7_frontend" {
  source           = "../../modules/ilb7-frontend"
  project_id       = var.project_id_hub
  prefix           = "${local.hub_prefix}eu-ilb7"
  network          = google_compute_network.hub_vpc.self_link
  subnetwork       = local.hub_eu_subnet1.self_link
  proxy_subnetwork = [local.hub_eu_subnet3]
  region           = local.hub_eu_region
  url_map          = google_compute_region_url_map.hub_eu_ilb7_url_map.id
  frontend = {
    address = local.hub_eu_ilb7_addr
    ssl     = { self_cert = true, domains = local.hub_eu_ilb7_domains }
  }
}

# ilb7: hub-us
#---------------------------------

locals {
  hub_us_ilb7_domains = [
    "${local.hub_us_ilb7_dns}.${local.hub_domain}.${local.cloud_domain}",
    local.hub_us_psc_https_ctrl_run_dns
  ]
}

# instance

resource "google_compute_instance" "hub_us_ilb7_vm" {
  project      = var.project_id_hub
  name         = "${local.hub_prefix}us-ilb7-vm"
  zone         = "${local.hub_us_region}-b"
  machine_type = var.machine_type
  tags         = [local.tag_ssh, local.tag_gfe]
  boot_disk {
    initialize_params {
      image = var.image_debian
      size  = var.disk_size
      type  = var.disk_type
    }
  }
  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }
  network_interface {
    network    = google_compute_network.hub_vpc.self_link
    subnetwork = local.hub_us_subnet1.self_link
  }
  service_account {
    email  = module.hub_sa.email
    scopes = ["cloud-platform"]
  }
  metadata_startup_script   = local.vm_startup
  allow_stopping_for_update = true
}

# ig

resource "google_compute_instance_group" "hub_us_ilb7_ig" {
  project   = var.project_id_hub
  zone      = "${local.hub_us_region}-b"
  name      = "${local.hub_prefix}us-ilb7-ig"
  instances = [google_compute_instance.hub_us_ilb7_vm.self_link]
  named_port {
    name = local.svc_web.name
    port = local.svc_web.port
  }
}

# psc neg

locals {
  hub_us_ilb7_psc_neg_name      = "${local.hub_prefix}us-ilb7-psc-neg"
  hub_us_ilb7_psc_neg_self_link = "projects/${var.project_id_hub}/regions/${local.hub_us_region}/networkEndpointGroups/${local.hub_us_ilb7_psc_neg_name}"
  hub_us_ilb7_psc_neg_create = templatefile("scripts/neg/psc/create.sh", {
    PROJECT_ID     = var.project_id_hub
    NETWORK        = google_compute_network.hub_vpc.self_link
    REGION         = local.hub_us_region
    NEG_NAME       = local.hub_us_ilb7_psc_neg_name
    TARGET_SERVICE = local.hub_us_psc_https_ctrl_run_dns
  })
  hub_us_ilb7_psc_neg_delete = templatefile("scripts/neg/psc/delete.sh", {
    PROJECT_ID = var.project_id_hub
    REGION     = local.hub_us_region
    NEG_NAME   = local.hub_us_ilb7_psc_neg_name
  })
}

resource "null_resource" "hub_us_ilb7_psc_neg" {
  triggers = {
    create = local.hub_us_ilb7_psc_neg_create
    delete = local.hub_us_ilb7_psc_neg_delete
  }
  provisioner "local-exec" {
    command = self.triggers.create
  }
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete
  }
}

# backend

locals {
  hub_us_ilb7_backend_services_mig = {
    ("main") = {
      port_name = local.svc_web.name
      backends = [
        {
          group                 = google_compute_instance_group.hub_us_ilb7_ig.self_link
          balancing_mode        = "RATE"
          max_rate_per_instance = 100
          capacity_scaler       = 1.0
        },
      ]
      health_check_config = {
        config  = {}
        logging = true
        check = {
          port_specification = "USE_SERVING_PORT"
          host               = local.uhc_config.host
          request_path       = "/${local.uhc_config.request_path}"
          response           = local.uhc_config.response
        }
      }
    }
  }
  hub_us_ilb7_backend_services_psc_neg = {
    ("api") = {
      port = local.svc_web.port
      backends = [
        {
          group           = local.hub_us_ilb7_psc_neg_self_link
          balancing_mode  = "UTILIZATION"
          capacity_scaler = 1.0
        },
      ]
      health_check_config = {
        config  = {}
        logging = true
        check   = {}
      }
    }
  }
  hub_us_ilb7_backend_services_neg = {}
}

module "hub_us_ilb7_bes" {
  depends_on               = [null_resource.hub_us_ilb7_psc_neg]
  source                   = "../../modules/backend-region"
  project_id               = var.project_id_hub
  prefix                   = "${local.hub_prefix}us-ilb7"
  network                  = google_compute_network.hub_vpc.self_link
  region                   = local.hub_us_region
  backend_services_mig     = local.hub_us_ilb7_backend_services_mig
  backend_services_neg     = local.hub_us_ilb7_backend_services_neg
  backend_services_psc_neg = local.hub_us_ilb7_backend_services_psc_neg
}

# url map

resource "google_compute_region_url_map" "hub_us_ilb7_url_map" {
  provider        = google-beta
  project         = var.project_id_hub
  name            = "${local.hub_prefix}us-ilb7-url-map"
  region          = local.hub_us_region
  default_service = module.hub_us_ilb7_bes.backend_service_mig["main"].id
  host_rule {
    path_matcher = "main"
    hosts        = ["${local.hub_us_ilb7_dns}.${local.hub_domain}.${local.cloud_domain}"]
  }
  host_rule {
    path_matcher = "api"
    hosts        = [local.hub_us_psc_https_ctrl_run_dns]
  }
  path_matcher {
    name            = "main"
    default_service = module.hub_us_ilb7_bes.backend_service_mig["main"].self_link
  }
  path_matcher {
    name            = "api"
    default_service = module.hub_us_ilb7_bes.backend_service_psc_neg["api"].self_link
  }
}

# frontend

module "hub_us_ilb7_frontend" {
  source           = "../../modules/ilb7-frontend"
  project_id       = var.project_id_hub
  prefix           = "${local.hub_prefix}us-ilb7"
  network          = google_compute_network.hub_vpc.self_link
  subnetwork       = local.hub_us_subnet1.self_link
  proxy_subnetwork = [local.hub_us_subnet3]
  region           = local.hub_us_region
  url_map          = google_compute_region_url_map.hub_us_ilb7_url_map.id
  frontend = {
    address = local.hub_us_ilb7_addr
    ssl     = { self_cert = true, domains = local.hub_us_ilb7_domains }
  }
}

# hub-mgt: instances
#---------------------------------

# hub-mgt eu

resource "google_compute_instance" "hub_mgt_eu_vm" {
  project      = var.project_id_hub
  name         = "${local.hub_prefix}mgt-eu-vm"
  machine_type = var.machine_type
  zone         = "${local.hub_eu_region}-b"
  tags         = [local.tag_ssh, local.tag_http]
  boot_disk {
    initialize_params {
      image = var.image_debian
      size  = var.disk_size
      type  = var.disk_type
    }
  }
  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }
  network_interface {
    network    = google_compute_network.hub_mgt_vpc.self_link
    subnetwork = local.hub_mgt_eu_subnet1.self_link
    network_ip = local.hub_mgt_eu_app1_addr
  }
  service_account {
    email  = module.hub_sa.email
    scopes = ["cloud-platform"]
  }
  metadata_startup_script = local.vm_startup
}

# hub-mgt us

resource "google_compute_instance" "hub_mgt_us_vm" {
  project      = var.project_id_hub
  name         = "${local.hub_prefix}mgt-us-vm"
  machine_type = var.machine_type
  zone         = "${local.hub_us_region}-b"
  tags         = [local.tag_ssh, local.tag_http]
  boot_disk {
    initialize_params {
      image = var.image_debian
      size  = var.disk_size
      type  = var.disk_type
    }
  }
  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }
  network_interface {
    network    = google_compute_network.hub_mgt_vpc.self_link
    subnetwork = local.hub_mgt_us_subnet1.self_link
    network_ip = local.hub_mgt_us_app1_addr
  }
  service_account {
    email  = module.hub_sa.email
    scopes = ["cloud-platform"]
  }
  metadata_startup_script = local.vm_startup
}

# shared vpc
#---------------------------------

# host

resource "google_compute_shared_vpc_host_project" "hub" {
  project = var.project_id_hub
}

# spoke1

resource "google_compute_shared_vpc_service_project" "spoke1" {
  host_project    = google_compute_shared_vpc_host_project.hub.project
  service_project = var.project_id_spoke1
  #depends_on      = [google_compute_shared_vpc_host_project.hub]
}
/*
locals {
  remove_service_project_spoke1 = <<EOT
gcloud compute shared-vpc associated-projects remove ${var.project_id_spoke1} \
--host-project=${var.project_id_hub}
EOT
}

resource "null_resource" "remove_service_project_spoke1" {
  depends_on = [google_compute_shared_vpc_service_project.spoke1]
  triggers = {
    create = ":"
    delete = local.remove_service_project_spoke1
  }
  provisioner "local-exec" {
    command = self.triggers.create
  }
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete
  }
}*/

# spoke2

resource "google_compute_shared_vpc_service_project" "spoke2" {
  host_project    = google_compute_shared_vpc_host_project.hub.project
  service_project = var.project_id_spoke2
  depends_on      = [google_compute_shared_vpc_host_project.hub]
}

locals {
  remove_service_project_spoke2 = <<EOT
  gcloud compute shared-vpc associated-projects remove ${var.project_id_spoke2} --host-project=${var.project_id_hub}
EOT
}

resource "null_resource" "remove_service_project_spoke2" {
  depends_on = [google_compute_shared_vpc_service_project.spoke2]
  triggers = {
    create = ":"
    delete = local.remove_service_project_spoke2
  }
  provisioner "local-exec" {
    command = self.triggers.create
  }
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete
  }
}

# iam (not needed for terraform)
#---------------------------------

resource "google_compute_subnetwork_iam_member" "hub_int_eu_subnet1_prod_grp" {
  provider   = google-beta
  subnetwork = local.hub_int_eu_subnet1.self_link
  region     = local.spoke1_eu_region
  role       = "roles/compute.networkUser"
  member     = "group:prod-grp@cloudtuple.com"
}

resource "google_compute_subnetwork_iam_member" "hub_int_us_subnet1_prod_grp" {
  provider   = google-beta
  subnetwork = local.hub_int_us_subnet1.self_link
  region     = local.spoke1_us_region
  role       = "roles/compute.networkUser"
  member     = "group:prod-grp@cloudtuple.com"
}

# project constraints
#---------------------------------

resource "google_project_organization_policy" "spoke1_eu_subnets_for_spoke1_only" {
  project    = var.project_id_spoke1
  constraint = "compute.restrictSharedVpcSubnetworks"
  list_policy {
    allow {
      values = [
        local.spoke1_eu_subnet1.id,
        local.spoke1_eu_subnet2.id,
        local.spoke1_eu_subnet3.id,
        local.spoke1_us_subnet1.id,
        local.spoke1_us_subnet2.id,
      ]
    }
    suggested_value = "spoke1 service project has access to hub eu subnets"
  }
}

resource "google_project_organization_policy" "spoke2_us_subnets_for_spoke2_only" {
  project    = var.project_id_spoke2
  constraint = "compute.restrictSharedVpcSubnetworks"
  list_policy {
    allow {
      values = [
        local.spoke2_eu_subnet1.id,
        local.spoke2_eu_subnet2.id,
        local.spoke2_us_subnet1.id,
        local.spoke2_us_subnet2.id,
        local.spoke2_us_subnet3.id,
      ]
    }
    suggested_value = "spoke2 service project has access to hub us subnets"
  }
}
