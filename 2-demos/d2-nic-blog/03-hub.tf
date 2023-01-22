
locals {
  hub_regions    = [local.hub_us_region, ]
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
    google_compute_network.spoke2_vpc.self_link
  ]
  recordsets = {
    "A ${local.hub_us_ilb7_dns}"       = { type = "A", ttl = 300, records = [local.hub_us_ilb7_addr] },
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
    google_compute_network.spoke2_vpc.self_link
  ]
  service_directory_namespace = google_service_directory_namespace.hub_psc.id
}

# instances
#---------------------------------

# us

locals {
  hub_us_targets_app = [
    "${local.spoke1_eu_ilb4_dns}.${local.spoke1_domain}.${local.cloud_domain}:${local.svc_web.port}",
    "${local.spoke2_us_ilb4_dns}.${local.spoke2_domain}.${local.cloud_domain}:${local.svc_web.port}",
  ]
  hub_us_startup = templatefile("scripts/startup/gce.sh", {
    ENABLE_PROBES = true
    SCRIPTS = {
      targets_app   = local.hub_us_targets_app
      targets_probe = local.hub_us_targets_app
      targets_pga   = []
      targets_bucket = {
        ("spoke2") = module.spoke2_us_storage_bucket.name
      }
    }
    WEB_SERVER = {
      port                  = local.svc_web.port
      health_check_path     = local.uhc_config.request_path
      health_check_response = local.uhc_config.response
    }
  })
}

resource "google_compute_instance" "hub_us_app_vm" {
  project      = var.project_id_hub
  name         = "${local.hub_prefix}us-app-vm"
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
    network_ip = local.hub_us_app_addr
  }
  service_account {
    email  = module.hub_sa.email
    scopes = ["cloud-platform"]
  }
  metadata_startup_script   = local.hub_us_startup
  allow_stopping_for_update = true
}

resource "local_file" "hub_us_app_vm" {
  content  = google_compute_instance.hub_us_app_vm.metadata_startup_script
  filename = "_config/hub/${local.hub_prefix}us-ilb7-vm.sh"
}
