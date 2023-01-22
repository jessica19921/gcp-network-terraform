
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

# cloud dns
#---------------------------------
/*
# onprem zone

module "spoke1_dns_peering_to_hub_to_onprem" {
  source          = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns"
  project_id      = var.project_id_spoke1
  type            = "peering"
  name            = "${local.spoke1_prefix}to-hub-to-onprem"
  domain          = "${local.onprem_domain}."
  description     = "peering to hub for onprem"
  client_networks = [google_compute_network.hub_int_vpc.self_link, ]
  peer_network    = google_compute_network.hub_vpc.self_link
}*/

# local zone

module "spoke1_dns_private_zone" {
  source      = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns"
  project_id  = var.project_id_spoke1
  type        = "private"
  name        = "${local.spoke1_prefix}private"
  domain      = "${local.spoke1_domain}.${local.cloud_domain}."
  description = "local data"
  client_networks = [
    google_compute_network.hub_vpc.self_link,
    google_compute_network.hub_mgt_vpc.self_link,
    google_compute_network.hub_int_vpc.self_link,
  ]
  recordsets = {
    "A ${local.spoke1_eu_ilb4_dns}" = { type = "A", ttl = 300, records = [local.spoke1_eu_ilb4_addr] },
    "A ${local.spoke1_us_ilb4_dns}" = { type = "A", ttl = 300, records = [local.spoke1_us_ilb4_addr] },
    "A ${local.spoke1_eu_ilb7_dns}" = { type = "A", ttl = 300, records = [local.spoke1_eu_ilb7_addr] },
    "A ${local.spoke1_us_ilb7_dns}" = { type = "A", ttl = 300, records = [local.spoke1_us_ilb7_addr] },
  }
}

# dns routing

locals {
  spoke1_dns_rr1 = "${local.spoke1_eu_region}=${local.spoke1_eu_td_envoy_bridge_ilb4_addr}"
  spoke1_dns_rr2 = "${local.spoke1_us_region}=${local.spoke1_us_td_envoy_bridge_ilb4_addr}"
  spoke1_dns_routing_data = {
    ("${local.spoke1_td_envoy_bridge_ilb4_dns}.${module.spoke1_dns_private_zone.domain}") = {
      zone        = module.spoke1_dns_private_zone.name,
      policy_type = "GEO", ttl = 300, type = "A",
      policy_data = "${local.spoke1_dns_rr1};${local.spoke1_dns_rr2}"
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

# ilb4: eu
#---------------------------------

# instance

resource "google_compute_instance" "spoke1_eu_ilb4_vm" {
  project      = var.project_id_spoke1
  name         = "${local.spoke1_prefix}eu-ilb4-vm"
  zone         = "${local.spoke1_eu_region}-b"
  machine_type = var.machine_type
  tags         = [local.tag_ssh, local.tag_gfe, local.tag_hub_int_eu_nva_ilb4]
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
    network    = google_compute_network.hub_int_vpc.self_link
    subnetwork = local.spoke1_eu_subnet1.self_link
  }
  service_account {
    email  = module.spoke1_sa.email
    scopes = ["cloud-platform"]
  }
  metadata_startup_script   = local.vm_startup
  allow_stopping_for_update = true
}

resource "local_file" "spoke1_eu_ilb4_vm" {
  content  = google_compute_instance.spoke1_eu_ilb4_vm.metadata_startup_script
  filename = "_config/spoke1/${local.spoke1_prefix}eu-ilb4-vm.sh"
}

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

# ilb4

module "spoke1_eu_ilb4" {
  source        = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-ilb"
  project_id    = var.project_id_spoke1
  region        = local.spoke1_eu_region
  name          = "${local.spoke1_prefix}eu-ilb4"
  service_label = "${local.spoke1_prefix}eu-ilb4"
  network       = google_compute_network.hub_int_vpc.self_link
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

# ilb7: spoke1-eu
#---------------------------------

# domains

locals {
  spoke1_eu_ilb7_domains = [
    "${local.spoke1_eu_ilb7_dns}.${local.spoke1_domain}.${local.cloud_domain}",
    local.spoke1_eu_psc_https_ctrl_run_dns
  ]
}

# instance

resource "google_compute_instance" "spoke1_eu_ilb7_vm" {
  project      = var.project_id_spoke1
  name         = "${local.spoke1_prefix}eu-ilb7-vm"
  zone         = "${local.spoke1_eu_region}-b"
  machine_type = var.machine_type
  tags         = [local.tag_ssh, local.tag_gfe, local.tag_hub_int_eu_nva_ilb4]
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
    network    = google_compute_network.hub_int_vpc.self_link
    subnetwork = local.spoke1_eu_subnet1.self_link
  }
  service_account {
    email  = module.spoke1_sa.email
    scopes = ["cloud-platform"]
  }
  metadata_startup_script   = local.vm_startup
  allow_stopping_for_update = true
}

resource "local_file" "spoke1_eu_ilb7_vm" {
  content  = google_compute_instance.spoke1_eu_ilb7_vm.metadata_startup_script
  filename = "_config/spoke1/${local.spoke1_prefix}eu-ilb7-vm.sh"
}

# instance group

resource "google_compute_instance_group" "spoke1_eu_ilb7_ig" {
  project   = var.project_id_spoke1
  zone      = "${local.spoke1_eu_region}-b"
  name      = "${local.spoke1_prefix}eu-ilb7-ig"
  instances = [google_compute_instance.spoke1_eu_ilb7_vm.self_link]
  named_port {
    name = local.svc_web.name
    port = local.svc_web.port
  }
}

# psc api neg

locals {
  spoke1_eu_ilb7_psc_api_neg_name      = "${local.spoke1_prefix}eu-ilb7-psc-api-neg"
  spoke1_eu_ilb7_psc_api_neg_self_link = "projects/${var.project_id_spoke1}/regions/${local.spoke1_eu_region}/networkEndpointGroups/${local.spoke1_eu_ilb7_psc_api_neg_name}"
  spoke1_eu_ilb7_psc_api_neg_create = templatefile("scripts/neg/psc/create.sh", {
    PROJECT_ID     = var.project_id_spoke1
    NETWORK        = google_compute_network.hub_int_vpc.self_link
    REGION         = local.spoke1_eu_region
    NEG_NAME       = local.spoke1_eu_ilb7_psc_api_neg_name
    TARGET_SERVICE = local.spoke1_eu_psc_https_ctrl_run_dns
  })
  spoke1_eu_ilb7_psc_api_neg_delete = templatefile("scripts/neg/psc/delete.sh", {
    PROJECT_ID = var.project_id_spoke1
    REGION     = local.spoke1_eu_region
    NEG_NAME   = local.spoke1_eu_ilb7_psc_api_neg_name
  })
}

resource "null_resource" "spoke1_eu_ilb7_psc_api_neg" {
  triggers = {
    create = local.spoke1_eu_ilb7_psc_api_neg_create
    delete = local.spoke1_eu_ilb7_psc_api_neg_delete
  }
  provisioner "local-exec" {
    command = self.triggers.create
  }
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete
  }
}

# psc vpc neg
/*
locals {
  spoke1_us_ilb7_psc_vpc_neg_name      = "${local.spoke1_prefix}us-ilb7-psc-vpc-neg"
  spoke1_us_ilb7_psc_vpc_neg_self_link = "projects/${var.project_id_spoke1}/regions/${local.spoke1_us_region}/networkEndpointGroups/${local.spoke1_us_ilb7_psc_vpc_neg_name}"
  spoke1_us_ilb7_psc_vpc_neg_create = templatefile("scripts/neg/psc/create.sh", {
    PROJECT_ID     = var.project_id_spoke1
    NETWORK        = google_compute_network.spoke1_vpc.self_link
    REGION         = local.spoke1_us_region
    NEG_NAME       = local.spoke1_us_ilb7_psc_vpc_neg_name
    TARGET_SERVICE = local.spoke1_us_psc_https_ctrl_run_dns
    #TARGET_SERVICE = google_compute_service_attachment.spoke2_us_producer_svc_attach.self_link
  })
  spoke1_us_ilb7_psc_vpc_neg_delete = templatefile("scripts/neg/psc/delete.sh", {
    PROJECT_ID = var.project_id_spoke1
    REGION     = local.spoke1_us_region
    NEG_NAME   = local.spoke1_us_ilb7_psc_vpc_neg_name
  })
}

resource "null_resource" "spoke1_us_ilb7_psc_vpc_neg" {
  triggers = {
    create = local.spoke1_us_ilb7_psc_vpc_neg_create
    delete = local.spoke1_us_ilb7_psc_vpc_neg_delete
  }
  provisioner "local-exec" {
    command = self.triggers.create
  }
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete
  }
}*/

# backend

locals {
  spoke1_eu_ilb7_backend_services_mig = {
    ("main") = {
      port_name = local.svc_web.name
      backends = [
        {
          group                 = google_compute_instance_group.spoke1_eu_ilb7_ig.self_link
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
  spoke1_eu_ilb7_backend_services_psc_neg = {
    ("api") = {
      port = local.svc_web.port
      backends = [
        {
          group           = local.spoke1_eu_ilb7_psc_api_neg_self_link
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
  spoke1_eu_ilb7_backend_services_neg = {}
}

# backend services

module "spoke1_eu_ilb7_bes" {
  depends_on               = [null_resource.spoke1_eu_ilb7_psc_api_neg]
  source                   = "../../modules/backend-region"
  project_id               = var.project_id_spoke1
  prefix                   = "${local.spoke1_prefix}eu-ilb7"
  network                  = google_compute_network.hub_int_vpc.self_link
  region                   = local.spoke1_eu_region
  backend_services_mig     = local.spoke1_eu_ilb7_backend_services_mig
  backend_services_neg     = local.spoke1_eu_ilb7_backend_services_neg
  backend_services_psc_neg = local.spoke1_eu_ilb7_backend_services_psc_neg
}

# url map

resource "google_compute_region_url_map" "spoke1_eu_ilb7_url_map" {
  provider        = google-beta
  project         = var.project_id_spoke1
  name            = "${local.spoke1_prefix}eu-ilb7-url-map"
  region          = local.spoke1_eu_region
  default_service = module.spoke1_eu_ilb7_bes.backend_service_mig["main"].id
  host_rule {
    path_matcher = "main"
    hosts        = ["${local.spoke1_eu_ilb7_dns}.${local.spoke1_domain}.${local.cloud_domain}"]
  }
  host_rule {
    path_matcher = "api"
    hosts        = [local.spoke1_eu_psc_https_ctrl_run_dns]
  }
  path_matcher {
    name            = "main"
    default_service = module.spoke1_eu_ilb7_bes.backend_service_mig["main"].self_link
  }
  path_matcher {
    name            = "api"
    default_service = module.spoke1_eu_ilb7_bes.backend_service_psc_neg["api"].self_link
  }
}

# frontend

module "spoke1_eu_ilb7_frontend" {
  source           = "../../modules/ilb7-frontend"
  project_id       = var.project_id_spoke1
  prefix           = "${local.spoke1_prefix}eu-ilb7"
  network          = google_compute_network.hub_int_vpc.self_link
  subnetwork       = local.spoke1_eu_subnet1.self_link
  proxy_subnetwork = [local.spoke1_eu_subnet3]
  region           = local.spoke1_eu_region
  url_map          = google_compute_region_url_map.spoke1_eu_ilb7_url_map.id
  frontend = {
    address = local.spoke1_eu_ilb7_addr
    ssl     = { self_cert = true, domains = local.spoke1_eu_ilb7_domains }
  }
}
