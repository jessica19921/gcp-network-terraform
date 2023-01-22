
locals {
  spoke1_regions            = [local.spoke1_eu_region, ]
  spoke1_eu_subnet1         = google_compute_subnetwork.spoke1_subnets["${local.spoke1_prefix}eu-subnet1"]
  spoke1_eu_subnet2         = google_compute_subnetwork.spoke1_subnets["${local.spoke1_prefix}eu-subnet2"]
  spoke1_eu_subnet3         = google_compute_subnetwork.spoke1_subnets["${local.spoke1_prefix}eu-subnet3"]
  spoke1_eu_psc_nat_subnet1 = google_compute_subnetwork.spoke1_subnets["${local.spoke1_prefix}eu-psc-nat-subnet1"]
}

# namespace
#---------------------------------

resource "google_service_directory_namespace" "spoke1_td" {
  provider     = google-beta
  project      = var.project_id_spoke1
  namespace_id = "${local.spoke1_prefix}td"
  location     = local.spoke1_eu_region
}

resource "google_service_directory_namespace" "spoke1_psc" {
  provider     = google-beta
  project      = var.project_id_spoke1
  namespace_id = "${local.spoke1_prefix}psc"
  location     = local.spoke1_eu_region
}

# network
#---------------------------------

resource "google_compute_network" "spoke1_vpc" {
  project      = var.project_id_spoke1
  name         = "${local.spoke1_prefix}vpc"
  routing_mode = "GLOBAL"
  mtu          = 1460

  auto_create_subnetworks         = false
  delete_default_routes_on_create = false
}

# subnets
#---------------------------------

resource "google_compute_subnetwork" "spoke1_subnets" {
  for_each      = local.spoke1_subnets
  provider      = google-beta
  project       = var.project_id_spoke1
  name          = each.key
  network       = google_compute_network.spoke1_vpc.id
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

module "spoke1_nat" {
  source                = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-cloudnat"
  for_each              = toset(local.spoke1_regions)
  project_id            = var.project_id_spoke1
  region                = each.key
  name                  = "${local.spoke1_prefix}${each.key}"
  router_network        = google_compute_network.spoke1_vpc.self_link
  router_create         = true
  config_source_subnets = "ALL_SUBNETWORKS_ALL_PRIMARY_IP_RANGES"
}

# firewall
#---------------------------------

module "spoke1_vpc_firewall" {
  source              = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-vpc-firewall"
  project_id          = var.project_id_spoke1
  network             = google_compute_network.spoke1_vpc.name
  admin_ranges        = []
  http_source_ranges  = []
  https_source_ranges = []
  custom_rules = {
    "${local.spoke1_prefix}internal" = {
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
    "${local.spoke1_prefix}gfe" = {
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
    "${local.spoke1_prefix}ssh" = {
      description          = "allow ssh"
      direction            = "INGRESS"
      action               = "allow"
      sources              = []
      ranges               = ["0.0.0.0/0"]
      targets              = []
      use_service_accounts = false
      rules                = [{ protocol = "tcp", ports = [22] }]
      extra_attributes     = {}
    }
  }
}

# psc/api
#---------------------------------

resource "google_compute_global_address" "spoke1_psc_api_fr_addr" {
  provider     = google-beta
  project      = var.project_id_spoke1
  name         = "${local.spoke1_prefix}${local.spoke1_psc_api_fr_name}"
  address_type = "INTERNAL"
  purpose      = "PRIVATE_SERVICE_CONNECT"
  network      = google_compute_network.spoke1_vpc.self_link
  address      = local.spoke1_psc_api_fr_addr
}

resource "google_compute_global_forwarding_rule" "spoke1_psc_api_fr" {
  provider              = google-beta
  project               = var.project_id_spoke1
  name                  = local.spoke1_psc_api_fr_name
  target                = local.spoke1_psc_api_fr_target
  network               = google_compute_network.spoke1_vpc.self_link
  ip_address            = google_compute_global_address.spoke1_psc_api_fr_addr.id
  load_balancing_scheme = ""
}

# dns policy
#---------------------------------

resource "google_dns_policy" "spoke1_dns_policy" {
  provider                  = google-beta
  project                   = var.project_id_spoke1
  name                      = "${local.spoke1_prefix}dns-policy"
  enable_inbound_forwarding = false
  enable_logging            = true
  networks { network_url = google_compute_network.spoke1_vpc.self_link }
}

# dns response policy
#---------------------------------

# policy

locals {
  spoke1_dns_rp_create = templatefile("scripts/dns/policy-create.sh", {
    PROJECT     = var.project_id_spoke1
    RP_NAME     = "${local.spoke1_prefix}dns-rp"
    NETWORKS    = join(",", [google_compute_network.spoke1_vpc.self_link, ])
    DESCRIPTION = "dns repsonse policy"
  })
  spoke1_dns_rp_delete = templatefile("scripts/dns/policy-delete.sh", {
    PROJECT = var.project_id_spoke1
    RP_NAME = "${local.spoke1_prefix}dns-rp"
  })
}

resource "null_resource" "spoke1_dns_rp" {
  triggers = {
    create = local.spoke1_dns_rp_create
    delete = local.spoke1_dns_rp_delete
  }
  provisioner "local-exec" {
    command = self.triggers.create
  }
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete
  }
}

# rules local data

locals {
  spoke1_dns_rp_rules_local = {
    ("${local.spoke1_prefix}dns-rp-rule-eu-psc-https-ctrl") = {
      dns_name   = "${local.spoke1_eu_psc_https_ctrl_dns}."
      local_data = "name=${local.spoke1_eu_psc_https_ctrl_dns}.,type=A,ttl=300,rrdatas=${local.spoke1_eu_ilb7_https_addr}"
    }
    ("${local.spoke1_prefix}dns-rp-rule-runapp") = {
      dns_name   = "*.run.app."
      local_data = "name=*.run.app.,type=A,ttl=300,rrdatas=${local.spoke1_psc_api_fr_addr}"
    }
    ("${local.spoke1_prefix}dns-rp-rule-gcr") = {
      dns_name   = "*.gcr.io."
      local_data = "name=*.gcr.io.,type=A,ttl=300,rrdatas=${local.spoke1_psc_api_fr_addr}"
    }
    ("${local.spoke1_prefix}dns-rp-rule-apis") = {
      dns_name   = "*.googleapis.com."
      local_data = "name=*.googleapis.com.,type=A,ttl=300,rrdatas=${local.spoke1_psc_api_fr_addr}"
    }
  }
  spoke1_dns_rp_rules_local_create = templatefile("scripts/dns/rule-create.sh", {
    PROJECT = var.project_id_spoke1
    RP_NAME = "${local.spoke1_prefix}dns-rp"
    RULES   = local.spoke1_dns_rp_rules_local
  })
  spoke1_dns_rp_rules_local_delete = templatefile("scripts/dns/rule-delete.sh", {
    PROJECT = var.project_id_spoke1
    RP_NAME = "${local.spoke1_prefix}dns-rp"
    RULES   = local.spoke1_dns_rp_rules_local
  })
}

resource "null_resource" "spoke1_dns_rp_rules_local" {
  depends_on = [null_resource.spoke1_dns_rp]
  triggers = {
    create = local.spoke1_dns_rp_rules_local_create
    delete = local.spoke1_dns_rp_rules_local_delete
  }
  provisioner "local-exec" {
    command = self.triggers.create
  }
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete
  }
}

# rules bypass

locals {
  spoke1_dns_rp_rules_bypass = {
    ("${local.spoke1_prefix}dns-rp-rule-bypass-www")    = { dns_name = "www.googleapis.com." }
    ("${local.spoke1_prefix}dns-rp-rule-bypass-ouath2") = { dns_name = "oauth2.googleapis.com." }
    ("${local.spoke1_prefix}dns-rp-rule-bypass-psc")    = { dns_name = "*.p.googleapis.com." }
  }
  spoke1_dns_rp_rules_bypass_create = templatefile("scripts/dns/rule-bypass-create.sh", {
    PROJECT = var.project_id_spoke1
    RP_NAME = "${local.spoke1_prefix}dns-rp"
    RULES   = local.spoke1_dns_rp_rules_bypass
  })
  spoke1_dns_rp_rules_bypass_delete = templatefile("scripts/dns/rule-delete.sh", {
    PROJECT = var.project_id_spoke1
    RP_NAME = "${local.spoke1_prefix}dns-rp"
    RULES   = local.spoke1_dns_rp_rules_bypass
  })
}

resource "null_resource" "spoke1_dns_rp_rules_bypass" {
  depends_on = [null_resource.spoke1_dns_rp]
  triggers = {
    create = local.spoke1_dns_rp_rules_bypass_create
    delete = local.spoke1_dns_rp_rules_bypass_delete
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

# psc zone

module "spoke1_dns_psc" {
  source      = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns"
  project_id  = var.project_id_spoke1
  type        = "private"
  name        = "${local.spoke1_prefix}psc"
  domain      = "${local.spoke1_psc_api_fr_name}.p.googleapis.com."
  description = "psc"
  client_networks = [
    google_compute_network.hub_vpc.self_link,
    google_compute_network.spoke1_vpc.self_link,
  ]
  recordsets = {
    "A " = { type = "A", ttl = 300, records = [local.spoke1_psc_api_fr_addr] }
  }
}

# local zone

module "spoke1_dns_private_zone" {
  source      = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns"
  project_id  = var.project_id_spoke1
  type        = "private"
  name        = "${local.spoke1_prefix}private"
  domain      = "${local.spoke1_domain}.${local.cloud_domain}."
  description = "spoke1 network attached"
  client_networks = [
    google_compute_network.hub_vpc.self_link,
    google_compute_network.spoke1_vpc.self_link
  ]
  recordsets = {
    "A ${local.spoke1_eu_ilb4_dns}"       = { type = "A", ttl = 300, records = [local.spoke1_eu_ilb4_addr] },
    "A ${local.spoke1_eu_ilb7_dns}"       = { type = "A", ttl = 300, records = [local.spoke1_eu_ilb7_addr] },
    "A ${local.spoke1_eu_ilb7_https_dns}" = { type = "A", ttl = 300, records = [local.spoke1_eu_ilb7_https_addr] },
  }
}

# onprem zone

module "spoke1_dns_peering_to_hub_to_onprem" {
  source          = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns"
  project_id      = var.project_id_spoke1
  type            = "peering"
  name            = "${local.spoke1_prefix}to-hub-to-onprem"
  domain          = "${local.onprem_domain}."
  description     = "peering to hub for onprem"
  client_networks = [google_compute_network.spoke1_vpc.self_link]
  peer_network    = google_compute_network.hub_vpc.self_link
}

# sd zone

module "spoke1_sd_td" {
  source      = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns"
  project_id  = var.project_id_spoke1
  type        = "service-directory"
  name        = "${local.spoke1_prefix}sd-td"
  domain      = "${local.spoke1_td_domain}."
  description = google_service_directory_namespace.spoke1_td.id
  client_networks = [
    google_compute_network.hub_vpc.self_link,
    google_compute_network.spoke1_vpc.self_link
  ]
  service_directory_namespace = google_service_directory_namespace.spoke1_td.id
}

module "spoke1_sd_psc" {
  source      = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns"
  project_id  = var.project_id_spoke1
  type        = "service-directory"
  name        = "${local.spoke1_prefix}sd-psc"
  domain      = "${local.spoke1_psc_domain}."
  description = google_service_directory_namespace.spoke1_psc.id
  client_networks = [
    google_compute_network.hub_vpc.self_link,
    google_compute_network.spoke1_vpc.self_link
  ]
  service_directory_namespace = google_service_directory_namespace.spoke1_psc.id
}

# dns routing

locals {
  spoke1_dns_rr2 = "${local.spoke1_eu_region}=${local.spoke1_eu_td_envoy_bridge_ilb4_addr}"
  spoke1_dns_routing_data = {
    ("${local.spoke1_td_envoy_bridge_ilb4_dns}.${module.spoke1_dns_private_zone.domain}") = {
      zone        = module.spoke1_dns_private_zone.name,
      policy_type = "GEO", ttl = 300, type = "A",
      policy_data = "${local.spoke1_dns_rr2}"
    }
  }
  spoke1_dns_routing_create = templatefile("scripts/dns/record-create.sh", {
    PROJECT = var.project_id_spoke1
    RECORDS = local.spoke1_dns_routing_data
  })
  spoke1_dns_routing_delete = templatefile("scripts/dns/record-delete.sh", {
    PROJECT = var.project_id_spoke1
    RECORDS = local.spoke1_dns_routing_data
  })
}

resource "null_resource" "spoke1_dns_routing" {
  triggers = {
    create = local.spoke1_dns_routing_create
    delete = local.spoke1_dns_routing_delete
  }
  provisioner "local-exec" {
    command = self.triggers.create
  }
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete
  }
}

# instances
#---------------------------------

locals {
  spoke1_eu_ilb4_vm_targets_app = [
    "${local.site2_app1_dns}.${local.site2_domain}.${local.onprem_domain}:${local.svc_web.port}",
  ]
  spoke1_eu_ilb4_vm_startup = templatefile("scripts/startup/gce.sh", {
    ENABLE_PROBES = true
    SCRIPTS = {
      targets_app   = local.spoke1_eu_ilb4_vm_targets_app
      targets_probe = local.spoke1_eu_ilb4_vm_targets_app
      targets_pga   = []
      targets_bucket = {
        ("spoke1") = module.spoke1_eu_storage_bucket.name
      }
    }
    WEB_SERVER = {
      port                  = local.svc_web.port
      health_check_path     = local.uhc_config.request_path
      health_check_response = local.uhc_config.response
    }
  })
}

resource "google_compute_instance" "spoke1_eu_ilb4_vm" {
  project      = var.project_id_spoke1
  name         = "${local.spoke1_prefix}eu-ilb4-vm"
  zone         = "${local.spoke1_eu_region}-b"
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
    network    = google_compute_network.spoke1_vpc.self_link
    subnetwork = local.spoke1_eu_subnet1.self_link
  }
  service_account {
    email  = module.spoke1_sa.email
    scopes = ["cloud-platform"]
  }
  metadata_startup_script   = local.spoke1_eu_ilb4_vm_startup
  allow_stopping_for_update = true
}

# ilb4
#---------------------------------

# instance group

resource "google_compute_instance_group" "spoke1_eu_ilb4_ig" {
  project   = var.project_id_spoke1
  zone      = "${local.spoke1_eu_region}-b"
  name      = "${local.spoke1_prefix}eu-ilb4-ig"
  instances = [google_compute_instance.spoke1_eu_ilb4_vm.self_link]
  named_port {
    name = local.svc_web.name
    port = local.svc_web.port
  }
}

module "spoke1_eu_ilb4" {
  source        = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-ilb"
  project_id    = var.project_id_spoke1
  region        = local.spoke1_eu_region
  name          = "${local.spoke1_prefix}eu-ilb4"
  service_label = "${local.spoke1_prefix}eu-ilb4"
  network       = google_compute_network.spoke1_vpc.self_link
  subnetwork    = local.spoke1_eu_subnet1.self_link
  address       = local.spoke1_eu_ilb4_addr
  backends = [{
    failover       = false
    group          = google_compute_instance_group.spoke1_eu_ilb4_ig.self_link
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

# config files
#---------------------------------

resource "local_file" "spoke1_eu_ilb4_vm" {
  content  = google_compute_instance.spoke1_eu_ilb4_vm.metadata_startup_script
  filename = "_config/spoke1/${local.spoke1_prefix}eu-ilb4-vm.sh"
}