
locals {
  hub_regions    = [local.hub_eu_region, local.hub_us_region, ]
  hub_eu_subnet1 = google_compute_subnetwork.hub_subnets["${local.hub_prefix}eu-subnet1"]
  hub_eu_subnet2 = google_compute_subnetwork.hub_subnets["${local.hub_prefix}eu-subnet2"]
  hub_eu_subnet3 = google_compute_subnetwork.hub_subnets["${local.hub_prefix}eu-subnet3"]
  hub_us_subnet1 = google_compute_subnetwork.hub_subnets["${local.hub_prefix}us-subnet1"]
  hub_us_subnet2 = google_compute_subnetwork.hub_subnets["${local.hub_prefix}us-subnet2"]
  hub_us_subnet3 = google_compute_subnetwork.hub_subnets["${local.hub_prefix}us-subnet3"]
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

# service networking connection
#---------------------------------

resource "google_service_networking_connection" "hub_eu_psa_ranges" {
  provider = google-beta
  network  = google_compute_network.hub_vpc.self_link
  service  = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [
    google_compute_global_address.hub_eu_psa_range1.name,
    google_compute_global_address.hub_eu_psa_range2.name
  ]
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

resource "local_file" "hub_eu_dns" {
  content  = google_compute_instance.hub_eu_dns.metadata_startup_script
  filename = "_config/hub/${local.hub_prefix}eu-dns.sh"
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

resource "local_file" "hub_us_dns" {
  content  = google_compute_instance.hub_us_dns.metadata_startup_script
  filename = "_config/hub/${local.hub_prefix}us-dns.sh"
}

# psc/api
#---------------------------------

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

# dns policy
#---------------------------------

resource "google_dns_policy" "hub_dns_policy" {
  provider                  = google-beta
  project                   = var.project_id_hub
  name                      = "${local.hub_prefix}dns-policy"
  enable_inbound_forwarding = false
  enable_logging            = true
  networks { network_url = google_compute_network.hub_vpc.self_link }
}

# dns response policy
#---------------------------------

resource "time_sleep" "hub_dns_forward_to_dns_wait_90s" {
  create_duration = "90s"
  depends_on = [
    google_compute_instance.hub_eu_dns,
    google_compute_instance.hub_us_dns
  ]
}

# policy

locals {
  hub_dns_rp_create = templatefile("scripts/dns/policy-create.sh", {
    PROJECT     = var.project_id_hub
    RP_NAME     = "${local.hub_prefix}dns-rp"
    NETWORKS    = join(",", [google_compute_network.hub_vpc.self_link, ])
    DESCRIPTION = "dns repsonse policy"
  })
  hub_dns_rp_delete = templatefile("scripts/dns/policy-delete.sh", {
    PROJECT = var.project_id_hub
    RP_NAME = "${local.hub_prefix}dns-rp"
  })
}

resource "null_resource" "hub_dns_rp" {
  triggers = {
    create = local.hub_dns_rp_create
    delete = local.hub_dns_rp_delete
  }
  provisioner "local-exec" {
    command = self.triggers.create
  }
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete
  }
  depends_on = [time_sleep.hub_dns_forward_to_dns_wait_90s]
}

# rules local data

locals {
  hub_dns_rp_rules_local = {
    ("${local.hub_prefix}dns-rp-rule-runapp") = {
      dns_name   = "*.run.app."
      local_data = "name=*.run.app.,type=A,ttl=300,rrdatas=${local.hub_psc_api_fr_addr}"
    }
    ("${local.hub_prefix}dns-rp-rule-gcr") = {
      dns_name   = "*.gcr.io."
      local_data = "name=*.gcr.io.,type=A,ttl=300,rrdatas=${local.hub_psc_api_fr_addr}"
    }
    ("${local.hub_prefix}dns-rp-rule-apis") = {
      dns_name   = "*.googleapis.com."
      local_data = "name=*.googleapis.com.,type=A,ttl=300,rrdatas=${local.hub_psc_api_fr_addr}"
    }
  }
  hub_dns_rp_rules_local_create = templatefile("scripts/dns/rule-create.sh", {
    PROJECT = var.project_id_hub
    RP_NAME = "${local.hub_prefix}dns-rp"
    RULES   = local.hub_dns_rp_rules_local
  })
  hub_dns_rp_rules_local_delete = templatefile("scripts/dns/rule-delete.sh", {
    PROJECT = var.project_id_hub
    RP_NAME = "${local.hub_prefix}dns-rp"
    RULES   = local.hub_dns_rp_rules_local
  })
}

resource "null_resource" "hub_dns_rp_rules_local" {
  triggers = {
    create = local.hub_dns_rp_rules_local_create
    delete = local.hub_dns_rp_rules_local_delete
  }
  provisioner "local-exec" {
    command = self.triggers.create
  }
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete
  }
  depends_on = [null_resource.hub_dns_rp, ]
}

# rules bypass

locals {
  hub_dns_rp_rules_bypass = {
    ("${local.hub_prefix}dns-rp-rule-bypass-www")    = { dns_name = "www.googleapis.com." }
    ("${local.hub_prefix}dns-rp-rule-bypass-ouath2") = { dns_name = "oauth2.googleapis.com." }
    ("${local.hub_prefix}dns-rp-rule-bypass-psc")    = { dns_name = "*.p.googleapis.com." }
  }
  hub_dns_rp_rules_bypass_create = templatefile("scripts/dns/rule-bypass-create.sh", {
    PROJECT = var.project_id_hub
    RP_NAME = "${local.hub_prefix}dns-rp"
    RULES   = local.hub_dns_rp_rules_bypass
  })
  hub_dns_rp_rules_bypass_delete = templatefile("scripts/dns/rule-delete.sh", {
    PROJECT = var.project_id_hub
    RP_NAME = "${local.hub_prefix}dns-rp"
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
  depends_on = [null_resource.hub_dns_rp]
}

# cloud dns
#---------------------------------

# psc zone

module "hub_dns_psc" {
  source      = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns"
  project_id  = var.project_id_hub
  type        = "private"
  name        = "${local.hub_prefix}psc"
  domain      = "${local.hub_psc_api_fr_name}.p.googleapis.com."
  description = "psc"
  client_networks = [
    google_compute_network.hub_vpc.self_link,
    google_compute_network.spoke1_vpc.self_link,
    google_compute_network.spoke2_vpc.self_link,
  ]
  recordsets = {
    "A " = { type = "A", ttl = 300, records = [local.hub_psc_api_fr_addr] }
  }
}

# onprem zone

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
  client_networks = [google_compute_network.hub_vpc.self_link]
  depends_on      = [time_sleep.hub_dns_forward_to_dns_wait_90s]
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
    google_compute_network.spoke1_vpc.self_link,
    google_compute_network.spoke2_vpc.self_link
  ]
  recordsets = {
    "A ${local.hub_eu_ilb4_dns}"       = { type = "A", ttl = 300, records = [local.hub_eu_ilb4_addr] },
    "A ${local.hub_us_ilb4_dns}"       = { type = "A", ttl = 300, records = [local.hub_us_ilb4_addr] },
    "A ${local.hub_eu_ilb7_dns}"       = { type = "A", ttl = 300, records = [local.hub_eu_ilb7_addr] },
    "A ${local.hub_us_ilb7_dns}"       = { type = "A", ttl = 300, records = [local.hub_us_ilb7_addr] },
    "A ${local.hub_eu_ilb7_https_dns}" = { type = "A", ttl = 300, records = [local.hub_eu_ilb7_https_addr] },
    "A ${local.hub_us_ilb7_https_dns}" = { type = "A", ttl = 300, records = [local.hub_us_ilb7_https_addr] },
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
    google_compute_network.spoke1_vpc.self_link,
    google_compute_network.spoke2_vpc.self_link
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
    google_compute_network.spoke1_vpc.self_link,
    google_compute_network.spoke2_vpc.self_link
  ]
  service_directory_namespace = google_service_directory_namespace.hub_psc.id
}

# instances
#---------------------------------

# eu

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

resource "local_file" "hub_eu_ilb4_vm" {
  content  = google_compute_instance.hub_eu_ilb4_vm.metadata_startup_script
  filename = "_config/hub/${local.hub_prefix}eu-ilb4-vm.sh"
}

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

resource "local_file" "hub_eu_ilb7_vm" {
  content  = google_compute_instance.hub_eu_ilb7_vm.metadata_startup_script
  filename = "_config/hub/${local.hub_prefix}eu-ilb7-vm.sh"
}

# us

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

resource "local_file" "hub_us_ilb4_vm" {
  content  = google_compute_instance.hub_us_ilb4_vm.metadata_startup_script
  filename = "_config/hub/${local.hub_prefix}us-ilb4-vm.sh"
}

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

resource "local_file" "hub_us_ilb7_vm" {
  content  = google_compute_instance.hub_us_ilb7_vm.metadata_startup_script
  filename = "_config/hub/${local.hub_prefix}us-ilb7-vm.sh"
}

# ilb4 - eu
#---------------------------------

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

# ilb4 - us
#---------------------------------

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

# ilb7 - eu
#---------------------------------

locals {
  hub_eu_ilb7_domains = [
    "${local.hub_eu_ilb7_dns}.${local.hub_domain}.${local.cloud_domain}",
    local.hub_eu_psc_https_ctrl_dns
  ]
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
  hub_eu_ilb7_psc_neg_name      = "${local.hub_prefix}eu-ilb7-psc-neg"
  hub_eu_ilb7_psc_neg_self_link = "projects/${var.project_id_hub}/regions/${local.hub_eu_region}/networkEndpointGroups/${local.hub_eu_ilb7_psc_neg_name}"
  hub_eu_ilb7_psc_neg_create = templatefile("scripts/neg/psc7/create.sh", {
    PROJECT_ID     = var.project_id_hub
    NETWORK        = google_compute_network.hub_vpc.self_link
    REGION         = local.hub_eu_region
    NEG_NAME       = local.hub_eu_ilb7_psc_neg_name
    TARGET_SERVICE = local.hub_eu_psc_https_ctrl_dns
  })
  hub_eu_ilb7_psc_neg_delete = templatefile("scripts/neg/psc7/delete.sh", {
    PROJECT_ID = var.project_id_hub
    REGION     = local.hub_eu_region
    NEG_NAME   = local.hub_eu_ilb7_psc_neg_name
  })
}

resource "null_resource" "hub_eu_ilb7_psc_neg" {
  triggers = {
    create = local.hub_eu_ilb7_psc_neg_create
    delete = local.hub_eu_ilb7_psc_neg_delete
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
    ("psc7") = {
      port = local.svc_web.port
      backends = [
        {
          group           = local.hub_eu_ilb7_psc_neg_self_link
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
  depends_on               = [null_resource.hub_eu_ilb7_psc_neg]
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
    path_matcher = "psc7"
    hosts        = [local.hub_eu_psc_https_ctrl_dns]
  }
  path_matcher {
    name            = "main"
    default_service = module.hub_eu_ilb7_bes.backend_service_mig["main"].self_link
  }
  path_matcher {
    name            = "psc7"
    default_service = module.hub_eu_ilb7_bes.backend_service_psc_neg["psc7"].self_link
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
    http = {
      enable  = true
      address = local.hub_eu_ilb7_addr
      port    = 80
    }
    https = {
      enable   = true
      address  = local.hub_eu_ilb7_https_addr
      port     = 443
      ssl      = { self_cert = true, domains = local.hub_eu_ilb7_domains }
      redirect = { enable = false, redirected_port = local.svc_web.port }
    }
  }
}

# ilb7 - us
#---------------------------------

locals {
  hub_us_ilb7_domains = [
    "${local.hub_us_ilb7_dns}.${local.hub_domain}.${local.cloud_domain}",
    local.hub_us_psc_https_ctrl_dns
  ]
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
  hub_us_ilb7_psc_neg_create = templatefile("scripts/neg/psc7/create.sh", {
    PROJECT_ID     = var.project_id_hub
    NETWORK        = google_compute_network.hub_vpc.self_link
    REGION         = local.hub_us_region
    NEG_NAME       = local.hub_us_ilb7_psc_neg_name
    TARGET_SERVICE = local.hub_us_psc_https_ctrl_dns
  })
  hub_us_ilb7_psc_neg_delete = templatefile("scripts/neg/psc7/delete.sh", {
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
    ("psc7") = {
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
    path_matcher = "psc7"
    hosts        = [local.hub_us_psc_https_ctrl_dns]
  }
  path_matcher {
    name            = "main"
    default_service = module.hub_us_ilb7_bes.backend_service_mig["main"].self_link
  }
  path_matcher {
    name            = "psc7"
    default_service = module.hub_us_ilb7_bes.backend_service_psc_neg["psc7"].self_link
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
    http = {
      enable  = true
      address = local.hub_us_ilb7_addr
      port    = 80
    }
    https = {
      enable   = true
      address  = local.hub_us_ilb7_https_addr
      port     = 443
      ssl      = { self_cert = true, domains = local.hub_us_ilb7_domains }
      redirect = { enable = false, redirected_port = local.svc_web.port }
    }
  }
}