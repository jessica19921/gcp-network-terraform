
locals {
  site2_regions = [local.site2_region, ]
  site2_subnet1 = google_compute_subnetwork.site2_subnets["${local.site2_prefix}subnet1"]
}

# network
#---------------------------------

resource "google_compute_network" "site2_vpc" {
  project      = var.project_id_onprem
  name         = "${local.site2_prefix}vpc"
  routing_mode = "GLOBAL"
  mtu          = 1460

  auto_create_subnetworks         = false
  delete_default_routes_on_create = false
}

# subnets
#---------------------------------

resource "google_compute_subnetwork" "site2_subnets" {
  for_each      = local.site2_subnets
  provider      = google-beta
  project       = var.project_id_onprem
  name          = each.key
  network       = google_compute_network.site2_vpc.id
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

module "site2_nat" {
  source                = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-cloudnat"
  for_each              = toset(local.site2_regions)
  project_id            = var.project_id_onprem
  region                = each.key
  name                  = "${local.site2_prefix}${each.key}"
  router_network        = google_compute_network.site2_vpc.self_link
  router_create         = true
  config_source_subnets = "ALL_SUBNETWORKS_ALL_PRIMARY_IP_RANGES"
}

# firewall
#---------------------------------

module "site2_vpc_firewall" {
  source              = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-vpc-firewall"
  project_id          = var.project_id_onprem
  network             = google_compute_network.site2_vpc.name
  admin_ranges        = []
  http_source_ranges  = []
  https_source_ranges = []
  custom_rules = {
    "${local.site2_prefix}internal" = {
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
    "${local.site2_prefix}ssh" = {
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
    "${local.site2_prefix}dns-egress" = {
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
  }
}

# custom dns
#---------------------------------

resource "google_compute_instance" "site2_dns" {
  project      = var.project_id_onprem
  name         = "${local.site2_prefix}dns"
  machine_type = "e2-micro"
  zone         = "${local.site2_region}-b"
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
    network    = google_compute_network.site2_vpc.self_link
    subnetwork = local.site2_subnet1.self_link
    network_ip = local.site2_ns_addr
  }
  service_account {
    email  = module.site2_sa.email
    scopes = ["cloud-platform"]
  }
  metadata_startup_script   = local.site2_unbound_config
  allow_stopping_for_update = true
}

# cloud dns
#---------------------------------

resource "time_sleep" "site2_dns_forward_to_dns_wait_90s" {
  create_duration = "90s"
  depends_on      = [google_compute_instance.site2_dns]
}

module "site2_dns_forward_to_dns" {
  source          = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/dns"
  project_id      = var.project_id_onprem
  type            = "forwarding"
  name            = "${local.site2_prefix}to-dns"
  description     = "forward all dns queries to custom resolvers"
  domain          = "."
  client_networks = [google_compute_network.site2_vpc.self_link]
  forwarders = {
    (local.site2_ns_addr) = "private"
    (local.site2_ns_addr) = "private"
  }
  depends_on = [time_sleep.site2_dns_forward_to_dns_wait_90s]
}

# workload
#---------------------------------

# app

locals {
  site2_targets_app = [
    "${local.spoke1_eu_ilb4_dns}.${local.spoke1_domain}.${local.cloud_domain}:${local.svc_web.port}",
    "${local.spoke2_us_ilb4_dns}.${local.spoke2_domain}.${local.cloud_domain}:${local.svc_web.port}",
    "${local.hub_us_app_addr}:${local.svc_web.port}"
  ]
  site2_startup = templatefile("scripts/startup/gce.sh", {
    ENABLE_PROBES = true
    SCRIPTS = {
      targets_app   = local.site2_targets_app
      targets_probe = local.site2_targets_app
      targets_pga   = local.targets_pga
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

resource "google_compute_instance" "site2_vm" {
  project      = var.project_id_onprem
  name         = "${local.site2_prefix}vm"
  machine_type = "e2-micro"
  zone         = "${local.site2_region}-b"
  tags         = [local.tag_ssh, local.tag_http]
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-10"
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
    network    = google_compute_network.site2_vpc.self_link
    subnetwork = local.site2_subnet1.self_link
    network_ip = local.site2_app1_addr
  }
  service_account {
    email  = module.site2_sa.email
    scopes = ["cloud-platform"]
  }
  metadata_startup_script   = local.site2_startup
  allow_stopping_for_update = true
}

# config files
#---------------------------------

resource "local_file" "site2_dns" {
  content  = google_compute_instance.site2_dns.metadata_startup_script
  filename = "_config/onprem/${local.site2_prefix}dns.sh"
}

resource "local_file" "site2_vm" {
  content  = google_compute_instance.site2_vm.metadata_startup_script
  filename = "_config/onprem/${local.site2_prefix}vm.sh"
}
