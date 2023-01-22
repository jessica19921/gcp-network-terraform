
# instance
#----------------------------------------------------

locals {
  hub_us_gclb_vm_config = templatefile("scripts/startup/juice.yaml", {
    APP_NAME  = "${local.hub_prefix}juice-shop"
    APP_IMAGE = "bkimminich/juice-shop"
  })
  hub_us_gclb_vm_cos = templatefile("scripts/startup/armor/gclb.sh", {
    VCPU = 2
  })
}

module "hub_us_gclb_vm" {
  source        = "../../modules/compute-vm"
  project_id    = var.project_id_hub
  name          = "${local.hub_prefix}us-gclb-vm"
  zone          = "${local.hub_us_region}-b"
  tags          = [local.tag_ssh, local.tag_gfe, "allow-flood4", ]
  instance_type = "e2-standard-4"
  boot_disk = {
    image = var.image_cos
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
  service_account        = module.hub_sa.email
  service_account_scopes = ["cloud-platform"]
  metadata = {
    gce-container-declaration = local.hub_us_gclb_vm_config
    google-logging-enabled    = true
    google-monitoring-enabled = true
  }
}

resource "local_file" "hub_us_gclb_vm_cos" {
  content  = local.hub_us_gclb_vm_cos
  filename = "config/hub/armor/gclb-cos.sh"
}

# instance group
#----------------------------------------------------

# us

resource "google_compute_instance_group" "hub_us_gclb_ig" {
  project   = var.project_id_hub
  zone      = "${local.hub_us_region}-b"
  name      = "${local.hub_prefix}us-gclb-ig"
  instances = [module.hub_us_gclb_vm.self_link, ]
  named_port {
    name = local.svc_juice.name
    port = local.svc_juice.port
  }
}

# backend
#----------------------------------------------------

# backend services

locals {
  hub_gclb_backend_services_mig = {
    ("secure") = {
      port_name       = local.svc_juice.name
      enable_cdn      = false
      security_policy = google_compute_security_policy.hub_backend_sec_policy.name
      backends = [
        { group = google_compute_instance_group.hub_us_gclb_ig.self_link },
      ]
      health_check_config = {
        config  = {}
        logging = true
        check   = { port_specification = "USE_SERVING_PORT" }
      }
    }
  }
}

module "hub_gclb_bes" {
  source                   = "../../modules/backend-global"
  project_id               = var.project_id_hub
  prefix                   = "${local.hub_prefix}gclb"
  network                  = google_compute_network.hub_vpc.self_link
  backend_services_mig     = local.hub_gclb_backend_services_mig
  backend_services_neg     = {}
  backend_services_psc_neg = {}
}

# url map
#----------------------------------------------------

resource "google_compute_url_map" "hub_gclb_url_map" {
  provider        = google-beta
  project         = var.project_id_hub
  name            = "${local.hub_prefix}gclb-url-map"
  default_service = module.hub_gclb_bes.backend_service_mig["secure"].self_link
  host_rule {
    path_matcher = "secure"
    hosts        = [local.hub_host_secure]
  }
  path_matcher {
    name            = "secure"
    default_service = module.hub_gclb_bes.backend_service_mig["secure"].self_link
  }
}

# frontend
#----------------------------------------------------

module "hub_gclb_frontend" {
  source     = "../../modules/xlb7-frontend"
  project_id = var.project_id_hub
  prefix     = trimsuffix(local.hub_prefix, "-")
  network    = google_compute_network.hub_vpc.self_link
  address    = google_compute_global_address.hub_gclb_frontend.address
  url_map    = google_compute_url_map.hub_gclb_url_map.name
  frontend = {
    regional = { enable = false, region = local.hub_us_region }
    ssl      = { self_cert = false, domains = local.hub_ssl_cert_domains }
  }
}
/*
# dns
#----------------------------------------------------

resource "google_dns_record_set" "hub_gclb_frontend_dns" {
  for_each     = toset(local.hub_domains)
  project      = var.project_id_dns
  managed_zone = data.google_dns_managed_zone.public_zone.name
  name         = each.value
  type         = "A"
  ttl          = 300
  rrdatas      = [module.hub_gclb_frontend.forwarding_rule.ip_address]
}*/
