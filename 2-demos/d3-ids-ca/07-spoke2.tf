
locals {
  spoke2_regions            = [local.spoke2_eu_region, local.spoke2_us_region, ]
  spoke2_eu_subnet1         = google_compute_subnetwork.spoke2_subnets["${local.spoke2_prefix}eu-subnet1"]
  spoke2_eu_subnet2         = google_compute_subnetwork.spoke2_subnets["${local.spoke2_prefix}eu-subnet2"]
  spoke2_eu_subnet3         = google_compute_subnetwork.spoke2_subnets["${local.spoke2_prefix}eu-subnet3"]
  spoke2_us_subnet1         = google_compute_subnetwork.spoke2_subnets["${local.spoke2_prefix}us-subnet1"]
  spoke2_us_subnet2         = google_compute_subnetwork.spoke2_subnets["${local.spoke2_prefix}us-subnet2"]
  spoke2_us_subnet3         = google_compute_subnetwork.spoke2_subnets["${local.spoke2_prefix}us-subnet3"]
  spoke2_us_psc_nat_subnet1 = google_compute_subnetwork.spoke2_subnets["${local.spoke2_prefix}us-psc-nat-subnet1"]
}

# namespace
#---------------------------------

resource "google_service_directory_namespace" "spoke2_td" {
  provider     = google-beta
  project      = var.project_id_spoke2
  namespace_id = "${local.spoke2_prefix}td"
  location     = local.spoke2_us_region
}

resource "google_service_directory_namespace" "spoke2_psc" {
  provider     = google-beta
  project      = var.project_id_spoke2
  namespace_id = "${local.spoke2_prefix}psc"
  location     = local.spoke2_us_region
}

# network
#---------------------------------

resource "google_compute_network" "spoke2_vpc" {
  project      = var.project_id_spoke2
  name         = "${local.spoke2_prefix}vpc"
  routing_mode = "GLOBAL"
  mtu          = 1460

  auto_create_subnetworks         = false
  delete_default_routes_on_create = false
}

# subnets
#---------------------------------

resource "google_compute_subnetwork" "spoke2_subnets" {
  for_each      = local.spoke2_subnets
  provider      = google-beta
  project       = var.project_id_spoke2
  name          = each.key
  network       = google_compute_network.spoke2_vpc.id
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

module "spoke2_nat" {
  source                = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-cloudnat"
  for_each              = toset(local.spoke2_regions)
  project_id            = var.project_id_spoke2
  region                = each.key
  name                  = "${local.spoke2_prefix}${each.key}"
  router_network        = google_compute_network.spoke2_vpc.self_link
  router_create         = true
  config_source_subnets = "ALL_SUBNETWORKS_ALL_PRIMARY_IP_RANGES"
}

# firewall
#---------------------------------

module "spoke2_vpc_firewall" {
  source              = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-vpc-firewall"
  project_id          = var.project_id_spoke2
  network             = google_compute_network.spoke2_vpc.name
  admin_ranges        = []
  http_source_ranges  = []
  https_source_ranges = []
  custom_rules = {
    "${local.spoke2_prefix}internal" = {
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
    "${local.spoke2_prefix}gfe" = {
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
    "${local.spoke2_prefix}ssh" = {
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

resource "google_compute_global_address" "spoke2_psc_api_fr_addr" {
  provider     = google-beta
  project      = var.project_id_spoke2
  name         = "${local.spoke2_prefix}${local.spoke2_psc_api_fr_name}"
  address_type = "INTERNAL"
  purpose      = "PRIVATE_SERVICE_CONNECT"
  network      = google_compute_network.spoke2_vpc.self_link
  address      = local.spoke2_psc_api_fr_addr
}

resource "google_compute_global_forwarding_rule" "spoke2_psc_api_fr" {
  provider              = google-beta
  project               = var.project_id_spoke2
  name                  = local.spoke2_psc_api_fr_name
  target                = local.spoke2_psc_api_fr_target
  network               = google_compute_network.spoke2_vpc.self_link
  ip_address            = google_compute_global_address.spoke2_psc_api_fr_addr.id
  load_balancing_scheme = ""
}

# dns policy
#---------------------------------

resource "google_dns_policy" "spoke2_dns_policy" {
  provider                  = google-beta
  project                   = var.project_id_spoke2
  name                      = "${local.spoke2_prefix}dns-policy"
  enable_inbound_forwarding = false
  enable_logging            = true
  networks { network_url = google_compute_network.spoke2_vpc.self_link }
}

# dns response policy
#---------------------------------

# policy

locals {
  spoke2_dns_rp_create = templatefile("scripts/dns/policy-create.sh", {
    PROJECT     = var.project_id_spoke2
    RP_NAME     = "${local.spoke2_prefix}dns-rp"
    NETWORKS    = join(",", [google_compute_network.spoke2_vpc.self_link, ])
    DESCRIPTION = "dns repsonse policy"
  })
  spoke2_dns_rp_delete = templatefile("scripts/dns/policy-delete.sh", {
    PROJECT = var.project_id_spoke2
    RP_NAME = "${local.spoke2_prefix}dns-rp"
  })
}

resource "null_resource" "spoke2_dns_rp" {
  triggers = {
    create = local.spoke2_dns_rp_create
    delete = local.spoke2_dns_rp_delete
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
  spoke2_dns_rp_rules_local = {
    ("${local.spoke2_prefix}dns-rp-rule-eu-psc-https-ctrl") = {
      dns_name   = "${local.spoke2_eu_psc_https_ctrl_dns}."
      local_data = "name=${local.spoke2_eu_psc_https_ctrl_dns}.,type=A,ttl=300,rrdatas=${local.spoke2_eu_ilb7_https_addr}"
    }
    ("${local.spoke2_prefix}dns-rp-rule-us-psc-https-ctrl") = {
      dns_name   = "${local.spoke2_us_psc_https_ctrl_dns}."
      local_data = "name=${local.spoke2_us_psc_https_ctrl_dns}.,type=A,ttl=300,rrdatas=${local.spoke2_us_ilb7_https_addr}"
    }
    ("${local.spoke2_prefix}dns-rp-rule-runapp") = {
      dns_name   = "*.run.app."
      local_data = "name=*.run.app.,type=A,ttl=300,rrdatas=${local.spoke2_psc_api_fr_addr}"
    }
    ("${local.spoke2_prefix}dns-rp-rule-gcr") = {
      dns_name   = "*.gcr.io."
      local_data = "name=*.gcr.io.,type=A,ttl=300,rrdatas=${local.spoke2_psc_api_fr_addr}"
    }
    ("${local.spoke2_prefix}dns-rp-rule-apis") = {
      dns_name   = "*.googleapis.com."
      local_data = "name=*.googleapis.com.,type=A,ttl=300,rrdatas=${local.spoke2_psc_api_fr_addr}"
    }
  }
  spoke2_dns_rp_rules_local_create = templatefile("scripts/dns/rule-create.sh", {
    PROJECT = var.project_id_spoke2
    RP_NAME = "${local.spoke2_prefix}dns-rp"
    RULES   = local.spoke2_dns_rp_rules_local
  })
  spoke2_dns_rp_rules_local_delete = templatefile("scripts/dns/rule-delete.sh", {
    PROJECT = var.project_id_spoke2
    RP_NAME = "${local.spoke2_prefix}dns-rp"
    RULES   = local.spoke2_dns_rp_rules_local
  })
}

resource "null_resource" "spoke2_dns_rp_rules_local" {
  depends_on = [null_resource.spoke2_dns_rp]
  triggers = {
    create = local.spoke2_dns_rp_rules_local_create
    delete = local.spoke2_dns_rp_rules_local_delete
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
  spoke2_dns_rp_rules_bypass = {
    ("${local.spoke2_prefix}dns-rp-rule-bypass-www")    = { dns_name = "www.googleapis.com." }
    ("${local.spoke2_prefix}dns-rp-rule-bypass-ouath2") = { dns_name = "oauth2.googleapis.com." }
    ("${local.spoke2_prefix}dns-rp-rule-bypass-psc")    = { dns_name = "*.p.googleapis.com." }
  }
  spoke2_dns_rp_rules_bypass_create = templatefile("scripts/dns/rule-bypass-create.sh", {
    PROJECT = var.project_id_spoke2
    RP_NAME = "${local.spoke2_prefix}dns-rp"
    RULES   = local.spoke2_dns_rp_rules_bypass
  })
  spoke2_dns_rp_rules_bypass_delete = templatefile("scripts/dns/rule-delete.sh", {
    PROJECT = var.project_id_spoke2
    RP_NAME = "${local.spoke2_prefix}dns-rp"
    RULES   = local.spoke2_dns_rp_rules_bypass
  })
}

resource "null_resource" "spoke2_dns_rp_rules_bypass" {
  depends_on = [null_resource.spoke2_dns_rp]
  triggers = {
    create = local.spoke2_dns_rp_rules_bypass_create
    delete = local.spoke2_dns_rp_rules_bypass_delete
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

module "spoke2_dns_psc" {
  source      = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns"
  project_id  = var.project_id_spoke2
  type        = "private"
  name        = "${local.spoke2_prefix}psc"
  domain      = "${local.spoke2_psc_api_fr_name}.p.googleapis.com."
  description = "psc"
  client_networks = [
    google_compute_network.hub_vpc.self_link,
    google_compute_network.spoke1_vpc.self_link,
    google_compute_network.spoke2_vpc.self_link,
  ]
  recordsets = {
    "A " = { type = "A", ttl = 300, records = [local.spoke2_psc_api_fr_addr] }
  }
}

# local zone

module "spoke2_dns_private_zone" {
  source      = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns"
  project_id  = var.project_id_spoke2
  type        = "private"
  name        = "${local.spoke2_prefix}private"
  domain      = "${local.spoke2_domain}.${local.cloud_domain}."
  description = "spoke2 network attached"
  client_networks = [
    google_compute_network.hub_vpc.self_link,
    google_compute_network.spoke1_vpc.self_link,
    google_compute_network.spoke2_vpc.self_link
  ]
  recordsets = {
    "A ${local.spoke2_eu_ilb4_dns}"       = { type = "A", ttl = 300, records = [local.spoke2_eu_ilb4_addr] },
    "A ${local.spoke2_us_ilb4_dns}"       = { type = "A", ttl = 300, records = [local.spoke2_us_ilb4_addr] },
    "A ${local.spoke2_eu_ilb7_dns}"       = { type = "A", ttl = 300, records = [local.spoke2_eu_ilb7_addr] },
    "A ${local.spoke2_us_ilb7_dns}"       = { type = "A", ttl = 300, records = [local.spoke2_us_ilb7_addr] },
    "A ${local.spoke2_eu_ilb7_https_dns}" = { type = "A", ttl = 300, records = [local.spoke2_eu_ilb7_https_addr] },
    "A ${local.spoke2_us_ilb7_https_dns}" = { type = "A", ttl = 300, records = [local.spoke2_us_ilb7_https_addr] },
  }
}

# onprem zone

module "spoke2_dns_peering_to_hub_to_onprem" {
  source          = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns"
  project_id      = var.project_id_spoke2
  type            = "peering"
  name            = "${local.spoke2_prefix}to-hub-to-onprem"
  domain          = "${local.onprem_domain}."
  description     = "peering to hub for onprem"
  client_networks = [google_compute_network.spoke2_vpc.self_link]
  peer_network    = google_compute_network.hub_vpc.self_link
}

# sd zone

module "spoke2_sd_td" {
  source      = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns"
  project_id  = var.project_id_spoke2
  type        = "service-directory"
  name        = "${local.spoke2_prefix}sd-td"
  domain      = "${local.spoke2_td_domain}."
  description = google_service_directory_namespace.spoke2_td.id
  client_networks = [
    google_compute_network.hub_vpc.self_link,
    google_compute_network.spoke1_vpc.self_link,
    google_compute_network.spoke2_vpc.self_link
  ]
  service_directory_namespace = google_service_directory_namespace.spoke2_td.id
}

module "spoke2_sd_psc" {
  source      = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns"
  project_id  = var.project_id_spoke2
  type        = "service-directory"
  name        = "${local.spoke2_prefix}sd-psc"
  domain      = "${local.spoke2_psc_domain}."
  description = google_service_directory_namespace.spoke2_psc.id
  client_networks = [
    google_compute_network.hub_vpc.self_link,
    google_compute_network.spoke1_vpc.self_link,
    google_compute_network.spoke2_vpc.self_link
  ]
  service_directory_namespace = google_service_directory_namespace.spoke2_psc.id
}

# dns routing

locals {
  spoke2_dns_rr1 = "${local.spoke2_eu_region}=${local.spoke2_eu_td_envoy_bridge_ilb4_addr}"
  spoke2_dns_rr2 = "${local.spoke2_us_region}=${local.spoke2_us_td_envoy_bridge_ilb4_addr}"
  spoke2_dns_routing_data = {
    ("${local.spoke2_td_envoy_bridge_ilb4_dns}.${module.spoke2_dns_private_zone.domain}") = {
      zone        = module.spoke2_dns_private_zone.name,
      policy_type = "GEO", ttl = 300, type = "A",
      policy_data = "${local.spoke2_dns_rr1};${local.spoke2_dns_rr2}"
    }
  }
  spoke2_dns_routing_create = templatefile("scripts/dns/record-create.sh", {
    PROJECT = var.project_id_spoke2
    RECORDS = local.spoke2_dns_routing_data
  })
  spoke2_dns_routing_delete = templatefile("scripts/dns/record-delete.sh", {
    PROJECT = var.project_id_spoke2
    RECORDS = local.spoke2_dns_routing_data
  })
}

resource "null_resource" "spoke2_dns_routing" {
  triggers = {
    create = local.spoke2_dns_routing_create
    delete = local.spoke2_dns_routing_delete
  }
  provisioner "local-exec" {
    command = self.triggers.create
  }
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete
  }
}

# reverse zone

locals {
  _spoke2_eu_test_vm_google_reverse_internal = google_compute_instance.spoke2_eu_test_vm.network_interface.0.network_ip
  _spoke2_eu_subnet1_reverse_custom          = split("/", local.spoke2_subnets["${local.spoke2_prefix}eu-subnet1"].ip_cidr_range).0
  _spoke2_us_subnet1_reverse_custom          = split("/", local.spoke2_subnets["${local.spoke2_prefix}us-subnet1"].ip_cidr_range).0
  spoke2_eu_test_vm_google_reverse_internal = (format("%s.%s.%s.%s.in-addr.arpa.",
    element(split(".", local._spoke2_eu_test_vm_google_reverse_internal), 3),
    element(split(".", local._spoke2_eu_test_vm_google_reverse_internal), 2),
    element(split(".", local._spoke2_eu_test_vm_google_reverse_internal), 1),
    element(split(".", local._spoke2_eu_test_vm_google_reverse_internal), 0),
  ))
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
}

# reverse lookup zone (self-managed reverse lookup zones)

module "spoke2_eu_subnet1_reverse_custom" {
  source      = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns"
  project_id  = var.project_id_spoke2
  type        = "private"
  name        = "${local.spoke2_prefix}eu-subnet1-reverse-custom"
  domain      = local.spoke2_eu_subnet1_reverse_custom
  description = "eu-subnet1 reverse custom zone"
  client_networks = [
    google_compute_network.hub_vpc.self_link,
    google_compute_network.spoke1_vpc.self_link,
    google_compute_network.spoke2_vpc.self_link
  ]
  recordsets = {
    "PTR 30" = { type = "PTR", ttl = 300, records = ["${local.spoke2_eu_ilb4_dns}.${local.spoke2_domain}.${local.cloud_domain}."] },
    "PTR 40" = { type = "PTR", ttl = 300, records = ["${local.spoke2_eu_ilb7_dns}.${local.spoke2_domain}.${local.cloud_domain}."] },
  }
}

module "spoke2_us_subnet1_reverse_custom" {
  source      = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns"
  project_id  = var.project_id_spoke2
  type        = "private"
  name        = "${local.spoke2_prefix}us-subnet1-reverse-custom"
  domain      = local.spoke2_us_subnet1_reverse_custom
  description = "us-subnet1 reverse custom zone"
  client_networks = [
    google_compute_network.hub_vpc.self_link,
    google_compute_network.spoke1_vpc.self_link,
    google_compute_network.spoke2_vpc.self_link
  ]
  recordsets = {
    "PTR 30" = { type = "PTR", ttl = 300, records = ["${local.spoke2_us_ilb4_dns}.${local.spoke2_domain}.${local.cloud_domain}."] },
    "PTR 40" = { type = "PTR", ttl = 300, records = ["${local.spoke2_us_ilb7_dns}.${local.spoke2_domain}.${local.cloud_domain}."] },
  }
}

# reverse zone (google-managed reverse lookup for everything else)

resource "google_dns_managed_zone" "spoke2_eu_test_vm_google_reverse_internal" {
  provider       = google-beta
  project        = var.project_id_spoke2
  name           = "${local.spoke2_prefix}eu-test-vm-google-reverse-internal"
  dns_name       = local.spoke2_eu_test_vm_google_reverse_internal
  description    = "eu-test-vm reverse internal zone"
  visibility     = "private"
  reverse_lookup = true
  private_visibility_config {
    networks { network_url = google_compute_network.hub_vpc.self_link }
    networks { network_url = google_compute_network.spoke1_vpc.self_link }
    networks { network_url = google_compute_network.spoke2_vpc.self_link }
  }
}

# instances
#---------------------------------

resource "google_compute_instance" "spoke2_eu_test_vm" {
  project      = var.project_id_spoke2
  name         = "${local.spoke2_prefix}eu-test-vm"
  zone         = "${local.spoke2_eu_region}-b"
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
    network    = google_compute_network.spoke2_vpc.self_link
    subnetwork = local.spoke2_eu_subnet1.self_link
  }
  service_account {
    email  = module.spoke2_sa.email
    scopes = ["cloud-platform"]
  }
  metadata_startup_script   = local.vm_startup
  allow_stopping_for_update = true
}

resource "google_compute_instance" "spoke2_us_ilb4_vm" {
  project      = var.project_id_spoke2
  name         = "${local.spoke2_prefix}us-ilb4-vm"
  zone         = "${local.spoke2_us_region}-b"
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
    network    = google_compute_network.spoke2_vpc.self_link
    subnetwork = local.spoke2_us_subnet1.self_link
  }
  service_account {
    email  = module.spoke2_sa.email
    scopes = ["cloud-platform"]
  }
  metadata_startup_script   = local.vm_startup
  allow_stopping_for_update = true
}

resource "google_compute_instance" "spoke2_us_ilb7_vm" {
  project      = var.project_id_spoke2
  name         = "${local.spoke2_prefix}us-ilb7-vm"
  zone         = "${local.spoke2_us_region}-b"
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
    network    = google_compute_network.spoke2_vpc.self_link
    subnetwork = local.spoke2_us_subnet1.self_link
  }
  service_account {
    email  = module.spoke2_sa.email
    scopes = ["cloud-platform"]
  }
  metadata_startup_script   = local.vm_startup
  allow_stopping_for_update = true
}

# ilb4
#---------------------------------

# instance group

resource "google_compute_instance_group" "spoke2_us_ilb4_ig" {
  project   = var.project_id_spoke2
  zone      = "${local.spoke2_us_region}-b"
  name      = "${local.spoke2_prefix}us-ilb4-ig"
  instances = [google_compute_instance.spoke2_us_ilb4_vm.self_link]
  named_port {
    name = local.svc_web.name
    port = local.svc_web.port
  }
}

module "spoke2_us_ilb4" {
  source        = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-ilb"
  project_id    = var.project_id_spoke2
  region        = local.spoke2_us_region
  name          = "${local.spoke2_prefix}us-ilb4"
  service_label = "${local.spoke2_prefix}us-ilb4"
  network       = google_compute_network.spoke2_vpc.self_link
  subnetwork    = local.spoke2_us_subnet1.self_link
  address       = local.spoke2_us_ilb4_addr
  backends = [{
    failover       = false
    group          = google_compute_instance_group.spoke2_us_ilb4_ig.self_link
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

# ilb7
#---------------------------------

locals {
  spoke2_us_ilb7_domains = [
    "${local.spoke2_us_ilb7_dns}.${local.spoke2_domain}.${local.cloud_domain}",
    local.spoke2_us_psc_https_ctrl_dns
  ]
}

# ig

resource "google_compute_instance_group" "spoke2_us_ilb7_ig" {
  project   = var.project_id_spoke2
  zone      = "${local.spoke2_us_region}-b"
  name      = "${local.spoke2_prefix}us-ilb7-ig"
  instances = [google_compute_instance.spoke2_us_ilb7_vm.self_link]
  named_port {
    name = local.svc_web.name
    port = local.svc_web.port
  }
}

# psc neg

locals {
  spoke2_us_ilb7_psc_neg_name      = "${local.spoke2_prefix}us-ilb7-psc-neg"
  spoke2_us_ilb7_psc_neg_self_link = "projects/${var.project_id_spoke2}/regions/${local.spoke2_us_region}/networkEndpointGroups/${local.spoke2_us_ilb7_psc_neg_name}"
  spoke2_us_ilb7_psc_neg_create = templatefile("scripts/neg/psc7/create.sh", {
    PROJECT_ID     = var.project_id_spoke2
    NETWORK        = google_compute_network.spoke2_vpc.self_link
    REGION         = local.spoke2_us_region
    NEG_NAME       = local.spoke2_us_ilb7_psc_neg_name
    TARGET_SERVICE = local.spoke2_us_psc_https_ctrl_dns
  })
  spoke2_us_ilb7_psc_neg_delete = templatefile("scripts/neg/psc7/delete.sh", {
    PROJECT_ID = var.project_id_spoke2
    REGION     = local.spoke2_us_region
    NEG_NAME   = local.spoke2_us_ilb7_psc_neg_name
  })
}

resource "null_resource" "spoke2_us_ilb7_psc_neg" {
  triggers = {
    create = local.spoke2_us_ilb7_psc_neg_create
    delete = local.spoke2_us_ilb7_psc_neg_delete
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
  spoke2_us_ilb7_backend_services_mig = {
    ("main") = {
      port_name = local.svc_web.name
      backends = [
        {
          group                 = google_compute_instance_group.spoke2_us_ilb7_ig.self_link
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
  spoke2_us_ilb7_backend_services_psc_neg = {
    ("psc7") = {
      port = local.svc_web.port
      backends = [
        {
          group           = local.spoke2_us_ilb7_psc_neg_self_link
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
  spoke2_us_ilb7_backend_services_neg = {}
}

module "spoke2_us_ilb7_bes" {
  depends_on               = [null_resource.spoke2_us_ilb7_psc_neg]
  source                   = "../../modules/backend-region"
  project_id               = var.project_id_spoke2
  prefix                   = "${local.spoke2_prefix}us-ilb7"
  network                  = google_compute_network.spoke2_vpc.self_link
  region                   = local.spoke2_us_region
  backend_services_mig     = local.spoke2_us_ilb7_backend_services_mig
  backend_services_neg     = local.spoke2_us_ilb7_backend_services_neg
  backend_services_psc_neg = local.spoke2_us_ilb7_backend_services_psc_neg
}

# url map

resource "google_compute_region_url_map" "spoke2_us_ilb7_url_map" {
  provider        = google-beta
  project         = var.project_id_spoke2
  name            = "${local.spoke2_prefix}us-ilb7-url-map"
  region          = local.spoke2_us_region
  default_service = module.spoke2_us_ilb7_bes.backend_service_mig["main"].id
  host_rule {
    path_matcher = "main"
    hosts        = ["${local.spoke2_us_ilb7_dns}.${local.spoke2_domain}.${local.cloud_domain}"]
  }
  host_rule {
    path_matcher = "psc7"
    hosts        = [local.spoke2_us_psc_https_ctrl_dns]
  }
  path_matcher {
    name            = "main"
    default_service = module.spoke2_us_ilb7_bes.backend_service_mig["main"].self_link
  }
  path_matcher {
    name            = "psc7"
    default_service = module.spoke2_us_ilb7_bes.backend_service_psc_neg["psc7"].self_link
  }
}

# frontend

module "spoke2_us_ilb7_frontend" {
  source           = "../../modules/ilb7-frontend"
  project_id       = var.project_id_spoke2
  prefix           = "${local.spoke2_prefix}us-ilb7"
  network          = google_compute_network.spoke2_vpc.self_link
  subnetwork       = local.spoke2_us_subnet1.self_link
  proxy_subnetwork = [local.spoke2_us_subnet3]
  region           = local.spoke2_us_region
  url_map          = google_compute_region_url_map.spoke2_us_ilb7_url_map.id
  frontend = {
    http = {
      enable  = true
      address = local.spoke2_us_ilb7_addr
      port    = 80
    }
    https = {
      enable   = true
      address  = local.spoke2_us_ilb7_https_addr
      port     = 443
      ssl      = { self_cert = true, domains = local.spoke2_us_ilb7_domains }
      redirect = { enable = false, redirected_port = local.svc_web.port }
    }
  }
}

# config files
#---------------------------------

resource "local_file" "spoke2_us_ilb4_vm" {
  content  = google_compute_instance.spoke2_us_ilb4_vm.metadata_startup_script
  filename = "_config/spoke2/${local.spoke2_prefix}us-ilb4-vm.sh"
}

resource "local_file" "spoke2_us_ilb7_vm" {
  content  = google_compute_instance.spoke2_us_ilb7_vm.metadata_startup_script
  filename = "_config/spoke2/${local.spoke2_prefix}us-ilb7-vm.sh"
}

resource "local_file" "spoke2_eu_test_vm" {
  content  = google_compute_instance.spoke2_eu_test_vm.metadata_startup_script
  filename = "_config/spoke2/${local.spoke2_prefix}eu-test-vm.sh"
}
