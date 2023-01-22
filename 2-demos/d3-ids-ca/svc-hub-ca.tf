
# common
#----------------------------------------------------

locals {
  hub_xlb7_host_good       = "good.${data.google_dns_managed_zone.public_zone.dns_name}"
  hub_xlb7_host_bad        = "bad.${data.google_dns_managed_zone.public_zone.dns_name}"
  hub_xlb7_host_good_juice = "goodjuice.${data.google_dns_managed_zone.public_zone.dns_name}"
  hub_xlb7_host_bad_juice  = "badjuice.${data.google_dns_managed_zone.public_zone.dns_name}"
  hub_xlb7_domains = [
    local.hub_xlb7_host_good,
    local.hub_xlb7_host_bad,
    local.hub_xlb7_host_good_juice,
    local.hub_xlb7_host_bad_juice
  ]
  hub_ssl_cert_domains = [for x in local.hub_xlb7_domains : trimsuffix(x, ".")]
}

# addresses
#----------------------------------------------------

# local address

data "external" "case1_external_ip" {
  program = ["sh", "scripts/general/external-ip.sh"]
}

# frontend

resource "google_compute_global_address" "hub_xlb7_frontend" {
  project = var.project_id_hub
  name    = "${local.hub_prefix}xlb7-frontend"
}

# traffic sources

resource "google_compute_address" "hub_eu_attack" {
  project = var.project_id_hub
  name    = "${local.hub_prefix}eu-attack"
  region  = local.hub_eu_region
}

resource "google_compute_address" "hub_eu_adaptive" {
  project = var.project_id_hub
  name    = "${local.hub_prefix}eu-adaptive"
  region  = local.hub_eu_region
}

resource "google_compute_address" "hub_eu_baseline" {
  project = var.project_id_hub
  name    = "${local.hub_prefix}eu-baseline"
  region  = local.hub_eu_region
}

resource "google_compute_address" "hub_eu_denied" {
  project = var.project_id_hub
  name    = "${local.hub_prefix}eu-denied"
  region  = local.hub_eu_region
}

# workload
#----------------------------------------------------

locals {
  hub_juice_cos_config = templatefile("scripts/startup/juice.yaml", {
    APP_NAME  = "${local.hub_prefix}juice-shop"
    APP_IMAGE = "bkimminich/juice-shop"
  })
}

# eu

module "hub_eu_xlb7" {
  source        = "../../modules/compute-vm"
  project_id    = var.project_id_hub
  name          = "${local.hub_prefix}eu-xlb7"
  zone          = "${local.hub_eu_region}-b"
  tags          = [local.tag_ssh, local.tag_gfe, "allow-attack", "mirror"]
  instance_type = "e2-medium"
  network_interfaces = [{
    network    = google_compute_network.hub_vpc.self_link
    subnetwork = local.hub_eu_subnet1.self_link
    addresses  = null
    nat        = true
    alias_ips  = null
  }]
  service_account         = module.hub_sa.email
  service_account_scopes  = ["cloud-platform"]
  metadata_startup_script = local.vm_startup
}

resource "local_file" "hub_eu_xlb7" {
  content  = module.hub_eu_xlb7_juice.instance.metadata_startup_script
  filename = "_config/hub/armor/workload/eu-xlb7-juice"
}

module "hub_eu_xlb7_juice" {
  source        = "../../modules/compute-vm"
  project_id    = var.project_id_hub
  name          = "${local.hub_prefix}eu-xlb7-juice"
  zone          = "${local.hub_eu_region}-b"
  tags          = [local.tag_ssh, local.tag_gfe, "allow-attack", ]
  instance_type = "e2-medium"
  boot_disk = {
    image = var.image_cos
    type  = var.disk_type
    size  = var.disk_size
  }
  network_interfaces = [{
    network    = google_compute_network.hub_vpc.self_link
    subnetwork = local.hub_eu_subnet1.self_link
    addresses  = null
    nat        = true
    alias_ips  = null
  }]
  service_account        = module.hub_sa.email
  service_account_scopes = ["cloud-platform"]
  metadata = {
    gce-container-declaration = local.hub_juice_cos_config
    google-logging-enabled    = true
    google-monitoring-enabled = true
  }
}

resource "local_file" "hub_eu_xlb7_juice" {
  content  = module.hub_eu_xlb7_juice.instance.metadata_startup_script
  filename = "_config/hub/armor/workload/eu-xlb7-juice"
}

# us

module "hub_us_xlb7" {
  source        = "../../modules/compute-vm"
  project_id    = var.project_id_hub
  name          = "${local.hub_prefix}us-xlb7"
  zone          = "${local.hub_us_region}-b"
  tags          = [local.tag_ssh, local.tag_gfe, "allow-attack", ]
  instance_type = "e2-medium"
  boot_disk = {
    image = var.image_debian
    type  = var.disk_type
    size  = var.disk_size
  }
  network_interfaces = [{
    network    = google_compute_network.hub_vpc.self_link
    subnetwork = local.hub_us_subnet1.self_link
    addresses  = null
    nat        = true
    alias_ips  = null
  }]
  service_account         = module.hub_sa.email
  service_account_scopes  = ["cloud-platform"]
  metadata_startup_script = local.vm_startup
}

resource "local_file" "hub_us_xlb7" {
  content  = module.hub_us_xlb7.instance.metadata_startup_script
  filename = "_config/hub/armor/workload/us-xlb7"
}

# firewall

resource "google_compute_firewall" "hub_allow_ddos_attack_to_xlb7" {
  project = var.project_id_hub
  name    = "${local.hub_prefix}allow-ddos-attack-to-xlb7"
  network = google_compute_network.hub_vpc.self_link
  allow {
    protocol = "tcp"
    ports = [
      local.svc_juice.port,
      local.svc_web.port,
    ]
  }
  source_ranges = [
    "0.0.0.0/0", # used due to error on module.hub_eu_attack.external_ip
    #google_compute_address.hub_eu_attack.address, # terraform error will not allow static external ip dependencies
    #data.external.case1_external_ip.result.ip,    # not required if 0.0.0.0/0 is used
  ]
  target_tags = ["allow-attack", ]
}

# traffic gen
#----------------------------------------------------

locals {
  hub_attack_startup = templatefile("scripts/startup/armor/attack.sh", {
    HOST_GOOD_JUICE   = trimsuffix(local.hub_xlb7_host_good_juice, ".")
    HOST_BAD_JUICE    = trimsuffix(local.hub_xlb7_host_bad_juice, ".")
    SYN_FLOOD_VM_IP   = module.hub_eu_xlb7_juice.external_ip
    SYN_FLOOD_VM_PORT = local.svc_juice.port
    SYN_FLOOD_LB_IP   = google_compute_global_address.hub_xlb7_frontend.address
    SYN_FLOOD_LB_PORT = 443
  })
  hub_adaptive_startup = templatefile("scripts/startup/armor/adaptive.sh", { TARGET_URL = local.hub_target_url })
  hub_baseline_startup = templatefile("scripts/startup/armor/baseline.sh", { TARGET_URL = local.hub_target_url })
  hub_denied_startup   = templatefile("scripts/startup/armor/denied.sh", { TARGET_URL = local.hub_target_url })
  hub_target_url       = "https://good.${trimsuffix(data.google_dns_managed_zone.public_zone.dns_name, ".")}/"
}

# attack traffic gen

module "hub_eu_attack" {
  source        = "../../modules/compute-vm"
  project_id    = var.project_id_hub
  name          = "${local.hub_prefix}eu-attack"
  zone          = "${local.hub_eu_region}-b"
  tags          = [local.tag_ssh, ]
  instance_type = "e2-small"
  network_interfaces = [{
    network    = google_compute_network.hub_vpc.self_link
    subnetwork = local.hub_eu_subnet1.self_link
    addresses = {
      external = google_compute_address.hub_eu_attack.address
      internal = null
    }
    nat       = true
    alias_ips = null
  }]
  service_account         = module.hub_sa.email
  service_account_scopes  = ["cloud-platform"]
  metadata_startup_script = local.hub_attack_startup
}

resource "local_file" "hub_eu_attack" {
  content  = local.hub_attack_startup
  filename = "_config/hub/armor/traffic/eu-attack"
}

# adaptive alert traffic gen

module "hub_eu_adaptive" {
  source        = "../../modules/compute-vm"
  project_id    = var.project_id_hub
  name          = "${local.hub_prefix}eu-adaptive"
  zone          = "${local.hub_eu_region}-b"
  tags          = [local.tag_ssh, ]
  instance_type = "e2-small"
  network_interfaces = [{
    network    = google_compute_network.hub_vpc.self_link
    subnetwork = local.hub_eu_subnet1.self_link
    addresses = {
      external = google_compute_address.hub_eu_adaptive.address
      internal = null
    }
    nat       = true
    alias_ips = null
  }]
  service_account         = module.hub_sa.email
  service_account_scopes  = ["cloud-platform"]
  metadata_startup_script = local.hub_adaptive_startup
}

resource "local_file" "hub_eu_adaptive" {
  content  = local.hub_adaptive_startup
  filename = "_config/hub/armor/traffic/eu-adaptive"
}

# baseline traffic gen

module "hub_eu_baseline" {
  source     = "../../modules/compute-vm"
  project_id = var.project_id_hub
  name       = "${local.hub_prefix}eu-baseline"
  zone       = "${local.hub_eu_region}-b"
  tags       = [local.tag_ssh, ]
  network_interfaces = [{
    network    = google_compute_network.hub_vpc.self_link
    subnetwork = local.hub_eu_subnet1.self_link
    addresses = {
      external = google_compute_address.hub_eu_baseline.address
      internal = null
    }
    nat       = true
    alias_ips = null
  }]
  service_account         = module.hub_sa.email
  service_account_scopes  = ["cloud-platform"]
  metadata_startup_script = local.hub_baseline_startup
}

resource "local_file" "hub_eu_baseline" {
  content  = local.hub_baseline_startup
  filename = "_config/hub/armor/traffic/eu-baseline"
}

# denied traffic gen

module "hub_eu_denied" {
  source     = "../../modules/compute-vm"
  project_id = var.project_id_hub
  name       = "${local.hub_prefix}eu-denied"
  zone       = "${local.hub_eu_region}-b"
  tags       = [local.tag_ssh, ]
  network_interfaces = [{
    network    = google_compute_network.hub_vpc.self_link
    subnetwork = local.hub_eu_subnet1.self_link
    addresses = {
      external = google_compute_address.hub_eu_denied.address
      internal = null
    }
    nat       = true
    alias_ips = null
  }]
  service_account         = module.hub_sa.email
  service_account_scopes  = ["cloud-platform"]
  metadata_startup_script = local.hub_denied_startup
}

resource "local_file" "hub_eu_denied" {
  content  = local.hub_denied_startup
  filename = "_config/hub/armor/traffic/eu-denied"
}

# hybrid gfe proxy instances
#----------------------------------------------------

# eu

locals {
  hub_eu_xlb7_hc_proxy_startup = templatefile("scripts/startup/proxy_hc.sh", {
    GFE_RANGES = local.netblocks.gfe
    DNAT_IP    = local.site1_app1_addr
  })
}

module "hub_eu_xlb7_hc_proxy" {
  source     = "../../modules/compute-vm"
  project_id = var.project_id_hub
  name       = "${local.hub_prefix}eu-xlb7-hc-proxy"
  zone       = "${local.hub_eu_region}-b"
  tags       = [local.tag_ssh, local.tag_gfe]
  network_interfaces = [{
    network    = google_compute_network.hub_vpc.self_link
    subnetwork = local.hub_eu_subnet1.self_link
    addresses = {
      internal = local.hub_eu_hybrid_hc_proxy_addr
      external = null
    }
    nat       = false
    alias_ips = null
  }]
  service_account         = module.hub_sa.email
  service_account_scopes  = ["cloud-platform"]
  metadata_startup_script = local.hub_eu_xlb7_hc_proxy_startup
}

resource "local_file" "hub_eu_xlb7_hc_proxy" {
  content  = module.hub_eu_xlb7_hc_proxy.instance.metadata_startup_script
  filename = "_config/hub/armor/hc-proxy/eu-xlb7-hc-proxy"
}

# us

locals {
  hub_us_xlb7_hc_proxy_startup = templatefile("scripts/startup/proxy_hc.sh", {
    GFE_RANGES = local.netblocks.gfe
    DNAT_IP    = local.site2_app1_addr
  })
}

module "hub_us_xlb7_hc_proxy" {
  source     = "../../modules/compute-vm"
  project_id = var.project_id_hub
  name       = "${local.hub_prefix}us-xlb7-hc-proxy"
  zone       = "${local.hub_us_region}-b"
  tags       = [local.tag_ssh, local.tag_gfe]
  network_interfaces = [{
    network    = google_compute_network.hub_vpc.self_link
    subnetwork = local.hub_us_subnet1.self_link
    addresses = {
      internal = local.hub_us_hybrid_hc_proxy_addr
      external = null
    }
    nat       = false
    alias_ips = null
  }]
  service_account         = module.hub_sa.email
  service_account_scopes  = ["cloud-platform"]
  metadata_startup_script = local.hub_us_xlb7_hc_proxy_startup
}

resource "local_file" "hub_us_xlb7_hc_proxy" {
  content  = module.hub_us_xlb7_hc_proxy.instance.metadata_startup_script
  filename = "_config/hub/armor/hc-proxy/us-xlb7-hc-proxy"
}

# instance group
#----------------------------------------------------

# eu

resource "google_compute_instance_group" "hub_eu_xlb7_ig" {
  project   = var.project_id_hub
  zone      = "${local.hub_eu_region}-b"
  name      = "${local.hub_prefix}eu-xlb7-ig"
  instances = [module.hub_eu_xlb7.self_link, ]
  named_port {
    name = local.svc_web.name
    port = local.svc_web.port
  }
}

resource "google_compute_instance_group" "hub_eu_xlb7_juice_ig" {
  project   = var.project_id_hub
  zone      = "${local.hub_eu_region}-b"
  name      = "${local.hub_prefix}eu-xlb7-juice-ig"
  instances = [module.hub_eu_xlb7_juice.self_link, ]
  named_port {
    name = local.svc_juice.name
    port = local.svc_juice.port
  }
}

# us

resource "google_compute_instance_group" "hub_us_xlb7_ig" {
  project   = var.project_id_hub
  zone      = "${local.hub_us_region}-b"
  name      = "${local.hub_prefix}us-xlb7-ig"
  instances = [module.hub_us_xlb7.self_link, ]
  named_port {
    name = local.svc_web.name
    port = local.svc_web.port
  }
}

# neg
#----------------------------------------------------

# eu

locals {
  hub_eu_xlb7_hybrid_neg_create = templatefile("scripts/neg/hybrid/create.sh", {
    PROJECT_ID  = var.project_id_hub
    NETWORK     = google_compute_network.hub_vpc.name
    SUBNET      = local.hub_eu_subnet1.name
    NEG_NAME    = "${local.hub_prefix}eu-xlb7-hybrid-neg"
    ZONE        = "${local.hub_eu_region}-c"
    NE_TYPE     = "non-gcp-private-ip-port"
    REMOTE_IP   = local.hub_eu_hybrid_hc_proxy_addr
    REMOTE_PORT = local.svc_web.port
  })
  hub_eu_xlb7_hybrid_neg_delete = templatefile("scripts/neg/hybrid/delete.sh", {
    PROJECT_ID = var.project_id_hub
    NEG_NAME   = "${local.hub_prefix}eu-xlb7-hybrid-neg"
    ZONE       = "${local.hub_eu_region}-c"
  })
}

resource "null_resource" "hub_eu_xlb7_hybrid_neg" {
  triggers = {
    create = local.hub_eu_xlb7_hybrid_neg_create
    delete = local.hub_eu_xlb7_hybrid_neg_delete
  }
  provisioner "local-exec" {
    command = self.triggers.create
  }
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete
  }
}

data "google_compute_network_endpoint_group" "hub_eu_xlb7_hybrid_neg" {
  depends_on = [null_resource.hub_eu_xlb7_hybrid_neg]
  project    = var.project_id_hub
  name       = "${local.hub_prefix}eu-xlb7-hybrid-neg"
  zone       = "${local.hub_eu_region}-c"
}

# security policy - backend
#----------------------------------------------------

# create sec policy to allow all traffic
# rules will be configured after

resource "google_compute_security_policy" "hub_xlb7_be_sec_policy" {
  provider    = google-beta
  project     = var.project_id_hub
  name        = "${local.hub_prefix}xlb7-be-sec-policy"
  description = "CLOUD_ARMOR"
  adaptive_protection_config {
    layer_7_ddos_defense_config {
      enable          = true
      rule_visibility = "STANDARD"
    }
  }
}

# security policy - edge
#----------------------------------------------------

# create sec policy to allow all traffic
# rules will be configured after

locals {
  hub_xlb7_edge_sec_policy = "${local.hub_prefix}xlb7-edge-sec-policy"
  hub_xlb7_edge_sec_policy_create = templatefile("scripts/armor/edge/policy/create.sh", {
    PROJECT_ID  = var.project_id_hub
    POLICY_NAME = local.hub_xlb7_edge_sec_policy
    POLICY_TYPE = "CLOUD_ARMOR_EDGE"
  })
  hub_xlb7_edge_sec_policy_delete = templatefile("scripts/armor/edge/policy/delete.sh", {
    PROJECT_ID  = var.project_id_hub
    POLICY_NAME = local.hub_xlb7_edge_sec_policy
  })
}

resource "null_resource" "hub_xlb7_edge_sec_policy" {
  triggers = {
    create = local.hub_xlb7_edge_sec_policy_create
    delete = local.hub_xlb7_edge_sec_policy_delete
  }
  provisioner "local-exec" {
    command = self.triggers.create
  }
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete
  }
}

# local files

resource "local_file" "hub_xlb7_edge_sec_policy_create" {
  content  = local.hub_xlb7_edge_sec_policy_create
  filename = "_config/hub/armor/edge/policy/create.sh"
}

resource "local_file" "hub_xlb7_edge_sec_policy_delete" {
  content  = local.hub_xlb7_edge_sec_policy_delete
  filename = "_config/hub/armor/edge/policy/delete.sh"
}

# backend
#----------------------------------------------------

# backend services

locals {
  hub_xlb7_backend_services_mig = {
    ("good") = {
      port_name       = local.svc_web.name
      enable_cdn      = true
      security_policy = google_compute_security_policy.hub_xlb7_be_sec_policy.name
      backends = [
        { group = google_compute_instance_group.hub_eu_xlb7_ig.self_link },
        { group = google_compute_instance_group.hub_us_xlb7_ig.self_link }
      ]
      health_check_config = {
        config  = {}
        logging = true
        check   = { port_specification = "USE_SERVING_PORT" }
      }
    }
    ("bad") = {
      port_name       = local.svc_web.name
      security_policy = null
      enable_cdn      = false
      backends = [
        { group = google_compute_instance_group.hub_eu_xlb7_ig.self_link },
        { group = google_compute_instance_group.hub_us_xlb7_ig.self_link }
      ]
      health_check_config = {
        config  = {}
        logging = true
        check   = { port_specification = "USE_SERVING_PORT" }
      }
    }
  }
  hub_xlb7_backend_services_mig_juice = {
    ("goodjuice") = {
      port_name       = local.svc_juice.name
      enable_cdn      = true
      security_policy = google_compute_security_policy.hub_xlb7_be_sec_policy.name
      backends = [
        { group = google_compute_instance_group.hub_eu_xlb7_juice_ig.self_link },
      ]
      health_check_config = {
        config  = {}
        logging = true
        check   = { port_specification = "USE_SERVING_PORT" }
      }
    }
    ("badjuice") = {
      port_name       = local.svc_juice.name
      security_policy = null
      enable_cdn      = false
      backends = [
        { group = google_compute_instance_group.hub_eu_xlb7_juice_ig.self_link },
      ]
      health_check_config = {
        config  = {}
        logging = true
        check   = { port_specification = "USE_SERVING_PORT" }
      }
    }
  }
  hub_xlb7_backend_services_neg = {
    ("good") = {
      port            = local.svc_web.port
      security_policy = google_compute_security_policy.hub_xlb7_be_sec_policy.name
      enable_cdn      = true
      backends = [
        { group = data.google_compute_network_endpoint_group.hub_eu_xlb7_hybrid_neg.id }
      ]
      health_check_config = {
        config  = {}
        logging = true
        check = {
          #port_specification = "USE_SERVING_PORT"
          port = local.svc_web.port
          #host         = local.uhc_config.host
          #request_path = "/${local.uhc_config.request_path}"
          #response     = local.uhc_config.response
        }
      }
    }
  }
}

module "hub_xlb7_bes" {
  source                   = "../../modules/backend-global"
  project_id               = var.project_id_hub
  prefix                   = "${local.hub_prefix}xlb7"
  network                  = google_compute_network.hub_vpc.self_link
  backend_services_mig     = local.hub_xlb7_backend_services_mig
  backend_services_neg     = local.hub_xlb7_backend_services_neg
  backend_services_psc_neg = {}
}

module "hub_xlb7_bes_juice" {
  source                   = "../../modules/backend-global"
  project_id               = var.project_id_hub
  prefix                   = "${local.hub_prefix}xlb7-juice"
  network                  = google_compute_network.hub_vpc.self_link
  backend_services_mig     = local.hub_xlb7_backend_services_mig_juice
  backend_services_neg     = {}
  backend_services_psc_neg = {}
}

# backend bucket

module "hub_gcs_ca" {
  source        = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/gcs"
  project_id    = var.project_id_hub
  prefix        = ""
  name          = "${local.hub_prefix}gcs-ca"
  location      = local.hub_eu_region
  storage_class = "STANDARD"
  iam           = { "roles/storage.objectViewer" = ["allUsers"] }
}

resource "google_storage_bucket_object" "hub_gcs_ca_file" {
  name    = "error.txt"
  bucket  = module.hub_gcs_ca.name
  content = "ERROR !!!"
}

resource "google_compute_backend_bucket" "hub_xlb7_beb" {
  provider    = google-beta
  project     = var.project_id_hub
  name        = "${local.hub_prefix}beb"
  bucket_name = module.hub_gcs_ca.name
  enable_cdn  = true
}

# url map
#----------------------------------------------------

locals {
  hub_xlb7_url_map_name = "${local.hub_prefix}xlb7-url-map"
  hub_xlb7_url_map_yaml = templatefile("scripts/startup/armor/url-map-01.yaml", {
    URL_MAP_NAME = local.hub_xlb7_url_map_name
    # default
    HOST_GOOD    = trimsuffix(local.hub_xlb7_host_good, ".")
    HOST_BAD     = trimsuffix(local.hub_xlb7_host_bad, ".")
    BES_MIG_GOOD = module.hub_xlb7_bes.backend_service_mig["good"].self_link
    BES_NEG_GOOD = module.hub_xlb7_bes.backend_service_neg["good"].self_link
    BES_MIG_BAD  = module.hub_xlb7_bes.backend_service_mig["bad"].self_link
    # juice
    HOST_GOOD_JUICE    = trimsuffix(local.hub_xlb7_host_good_juice, ".")
    HOST_BAD_JUICE     = trimsuffix(local.hub_xlb7_host_bad_juice, ".")
    BES_MIG_GOOD_JUICE = module.hub_xlb7_bes_juice.backend_service_mig["goodjuice"].self_link
    BES_MIG_BAD_JUICE  = module.hub_xlb7_bes_juice.backend_service_mig["badjuice"].self_link
  })
  hub_xlb7_url_map_create = templatefile("scripts/url/create.sh", {
    PROJECT_ID   = var.project_id_hub
    URL_MAP_NAME = local.hub_xlb7_url_map_name
    YAML         = local.hub_xlb7_url_map_yaml
  })
  hub_xlb7_url_map_delete = templatefile("scripts/url/delete.sh", {
    PROJECT_ID   = var.project_id_hub
    URL_MAP_NAME = local.hub_xlb7_url_map_name
  })
}

resource "null_resource" "hub_xlb7_url_map" {
  triggers = {
    create = local.hub_xlb7_url_map_create
    delete = local.hub_xlb7_url_map_delete
  }
  provisioner "local-exec" {
    command = self.triggers.create
  }
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete
  }
}

# frontend
#----------------------------------------------------

module "hub_xlb7_frontend" {
  depends_on = [null_resource.hub_xlb7_url_map]
  source     = "../../modules/xlb7-frontend"
  project_id = var.project_id_hub
  prefix     = "${local.hub_prefix}xlb7"
  network    = google_compute_network.hub_vpc.self_link
  address    = google_compute_global_address.hub_xlb7_frontend.address
  url_map    = local.hub_xlb7_url_map_name
  frontend = {
    http = {
      enable   = false
      port     = 80
      regional = { enable = false, region = local.hub_eu_region }
    }
    https = {
      enable   = true
      port     = 443
      ssl      = { self_cert = true, domains = local.hub_ssl_cert_domains }
      redirect = { enable = true, redirected_port = 80 }
      regional = { enable = false, region = local.hub_eu_region }
    }
  }
}

# dns
#----------------------------------------------------

resource "google_dns_record_set" "hub_xlb7_dns" {
  for_each     = toset(local.hub_xlb7_domains)
  project      = var.project_id_hub
  managed_zone = data.google_dns_managed_zone.public_zone.name
  name         = each.value
  type         = "A"
  ttl          = 300
  rrdatas      = [module.hub_xlb7_frontend.forwarding_rule.ip_address]
}

# security policy - sources
#----------------------------------------------------

locals {
  hub_sec_rule_ip_ranges_allowed_list = [
    "${data.external.case1_external_ip.result.ip}",
    google_compute_address.hub_eu_attack.address,
    google_compute_address.hub_eu_adaptive.address,
    google_compute_address.hub_eu_denied.address,
    google_compute_address.hub_eu_baseline.address,
  ]
  hub_sec_rule_ip_ranges_allowed_string = join(",", local.hub_sec_rule_ip_ranges_allowed_list)
  _hub_sec_rule_ip_ranges_allowed_list = join(
    ",", [for s in local.hub_sec_rule_ip_ranges_allowed_list : format("%q", s)]
  )
}

# security policy - edge
#----------------------------------------------------

# null_resource script to:
# 1) deny all ip ranges
# 2) allow selected ip ranges
# 3) in the future add custom rules when available for edge policy

locals {
  hub_xlb7_edge_sec_rules = {
    ("ranges") = { preview = false, priority = 100, action = "allow", ip = true, src_ip_ranges = local._hub_sec_rule_ip_ranges_allowed_list }
  }
  hub_xlb7_edge_sec_backends = [
    module.hub_xlb7_bes.backend_service_mig["good"].name,
    module.hub_xlb7_bes.backend_service_neg["good"].name,
    module.hub_xlb7_bes_juice.backend_service_mig["goodjuice"].name,
  ]
  hub_xlb7_edge_sec_rules_create = templatefile("scripts/armor/edge/rules/create.sh", {
    PROJECT_ID  = var.project_id_hub
    POLICY_NAME = local.hub_xlb7_edge_sec_policy
    RULES       = local.hub_xlb7_edge_sec_rules
    BACKENDS    = local.hub_xlb7_edge_sec_backends
    ENABLE      = true
  })
  hub_xlb7_edge_sec_rules_delete = templatefile("scripts/armor/edge/rules/delete.sh", {
    PROJECT_ID  = var.project_id_hub
    POLICY_NAME = local.hub_xlb7_edge_sec_policy
    RULES       = local.hub_xlb7_edge_sec_rules
    BACKENDS    = local.hub_xlb7_edge_sec_backends
    ENABLE      = true
  })
}

resource "null_resource" "hub_xlb7_edge_sec_rules" {
  depends_on = [null_resource.hub_xlb7_edge_sec_policy]
  triggers = {
    create = local.hub_xlb7_edge_sec_rules_create
    delete = local.hub_xlb7_edge_sec_rules_delete
  }
  provisioner "local-exec" {
    command = self.triggers.create
  }
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete
  }
}

# local files

resource "local_file" "hub_xlb7_edge_sec_rules_create" {
  content  = local.hub_xlb7_edge_sec_rules_create
  filename = "_config/hub/armor/edge/rules/create.sh"
}

resource "local_file" "hub_xlb7_edge_sec_rules_delete" {
  content  = local.hub_xlb7_edge_sec_rules_delete
  filename = "_config/hub/armor/edge/rules/delete.sh"
}

# security policy - backend rules
#----------------------------------------------------

# null_resource script to apply YAML to:
# 1) deny all ip ranges
# 2) allow selected ip ranges
# 3) specify custom rules not yet available in edge sec policy

locals {
  hub_xlb7_sec_rule_sqli_excluded_crs = join(",", [
    "'owasp-crs-v030001-id942421-sqli'",
    "'owasp-crs-v030001-id942200-sqli'",
    "'owasp-crs-v030001-id942260-sqli'",
    "'owasp-crs-v030001-id942340-sqli'",
    "'owasp-crs-v030001-id942430-sqli'",
    "'owasp-crs-v030001-id942431-sqli'",
    "'owasp-crs-v030001-id942432-sqli'",
    "'owasp-crs-v030001-id942420-sqli'",
    "'owasp-crs-v030001-id942440-sqli'",
    "'owasp-crs-v030001-id942450-sqli'",
  ])
  hub_xlb7_sec_rule_preconfigured_sqli_tuned = "evaluatePreconfiguredExpr('sqli-stable',[${local.hub_xlb7_sec_rule_sqli_excluded_crs}])"
  hub_xlb7_sec_rule_custom_hacker            = "origin.region_code == 'US' && request.headers['Referer'].contains('hacker')"
}

locals {
  hub_xlb7_backend_sec_rules = {
    ("lfi")      = { preview = false, priority = 10, action = "deny-403", ip = false, expression = "evaluatePreconfiguredExpr('lfi-stable')" }
    ("rce")      = { preview = false, priority = 20, action = "deny-403", ip = false, expression = "evaluatePreconfiguredExpr('rce-stable')" }
    ("scanners") = { preview = false, priority = 30, action = "deny-403", ip = false, expression = "evaluatePreconfiguredExpr('scannerdetection-stable')" }
    ("protocol") = { preview = false, priority = 40, action = "deny-403", ip = false, expression = "evaluatePreconfiguredExpr('protocolattack-stable')" }
    ("session")  = { preview = false, priority = 50, action = "deny-403", ip = false, expression = "evaluatePreconfiguredExpr('sessionfixation-stable')" }
    ("sqli")     = { preview = false, priority = 60, action = "deny-403", ip = false, expression = local.hub_xlb7_sec_rule_preconfigured_sqli_tuned }
    ("hacker")   = { preview = true, priority = 70, action = "deny-403", ip = false, expression = local.hub_xlb7_sec_rule_custom_hacker }
    ("xss")      = { preview = true, priority = 80, action = "deny-403", ip = false, expression = "evaluatePreconfiguredExpr('xss-stable')" }
    ("ranges")   = { preview = false, priority = 90, action = "allow", ip = true, src_ip_ranges = local._hub_sec_rule_ip_ranges_allowed_list }
  }
  hub_xlb7_backend_sec_backends = [
    module.hub_xlb7_bes.backend_service_mig["good"].name,
    module.hub_xlb7_bes.backend_service_neg["good"].name,
    module.hub_xlb7_bes_juice.backend_service_mig["goodjuice"].name,
  ]
  hub_xlb7_backend_sec_rules_create = templatefile("scripts/armor/backend/rules/create.sh", {
    PROJECT_ID  = var.project_id_hub
    POLICY_NAME = google_compute_security_policy.hub_xlb7_be_sec_policy.name
    RULES       = local.hub_xlb7_backend_sec_rules
    BACKENDS    = local.hub_xlb7_backend_sec_backends
    ENABLE      = true
  })
  hub_xlb7_backend_sec_rules_delete = templatefile("scripts/armor/backend/rules/delete.sh", {
    PROJECT_ID  = var.project_id_hub
    POLICY_NAME = google_compute_security_policy.hub_xlb7_be_sec_policy.name
    RULES       = local.hub_xlb7_backend_sec_rules
    BACKENDS    = local.hub_xlb7_backend_sec_backends
    ENABLE      = true
  })
}

resource "null_resource" "hub_xlb7_be_sec_policy" {
  triggers = {
    create = local.hub_xlb7_backend_sec_rules_create
    delete = local.hub_xlb7_backend_sec_rules_delete
  }
  provisioner "local-exec" {
    command = self.triggers.create
  }
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete
  }
}

# local files

resource "local_file" "hub_xlb7_backend_sec_rules_create" {
  content  = local.hub_xlb7_backend_sec_rules_create
  filename = "_config/hub/armor/backend/rules/create.sh"
}

resource "local_file" "hub_xlb7_backend_sec_rules_delete" {
  content  = local.hub_xlb7_backend_sec_rules_delete
  filename = "_config/hub/armor/backend/rules/delete.sh"
}
