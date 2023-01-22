
# addresses
#---------------------------------

locals {
  flood4_count = 0
  flood7_count = 0
}

resource "google_compute_address" "hub_flood4_vm" {
  count   = local.flood4_count
  project = var.project_id_hub
  name    = "${local.hub_prefix}flood4-vm${count.index}"
  region  = local.hub_us_region
}

resource "google_compute_address" "hub_flood7_vm" {
  count   = local.flood7_count
  project = var.project_id_hub
  name    = "${local.hub_prefix}flood7-vm${count.index}"
  region  = local.hub_us_region
}

resource "google_compute_address" "hub_baseline_vm" {
  project = var.project_id_hub
  name    = "${local.hub_prefix}baseline-vm"
  region  = local.hub_us_region
}

resource "google_compute_address" "hub_denied_vm" {
  project = var.project_id_hub
  name    = "${local.hub_prefix}denied-vm"
  region  = local.hub_us_region
}

# instances
#---------------------------------

locals {
  hub_flood4_vm_startup = templatefile("scripts/startup/armor/flood4.sh", {
    TARGET_NLB_VIP   = google_compute_address.hub_us_nlb_frontend.address
    TARGET_NLB_PORT  = local.svc_juice.port
    TARGET_GCLB_VIP  = google_compute_global_address.hub_gclb_frontend.address
    TARGET_GCLB_PORT = 443
  })
  hub_flood7_vm_startup = templatefile("scripts/startup/armor/flood7.sh", {
    HOST             = local.hub_host_secure
    TARGET_VM_IP     = module.hub_us_gclb_vm.external_ip
    TARGET_VM_PORT   = local.svc_juice.port
    TARGET_GCLB_VIP  = google_compute_global_address.hub_gclb_frontend.address
    TARGET_GCLB_PORT = 443
    TARGET_URL       = local.hub_target_url_gclb
  })
  hub_baseline_vm_startup = templatefile("scripts/startup/armor/baseline.sh", {
    TARGETS_URL = [local.hub_target_url_gclb, ]
  })
  hub_denied_vm_startup = templatefile("scripts/startup/armor/denied.sh", {
    TARGET_URL = local.hub_target_url_gclb
  })
  hub_target_url_gclb = "https://${local.hub_host_secure}/"
}

# ddos l4 traffic gen

module "hub_flood4_vm" {
  count         = local.flood4_count
  source        = "../../modules/compute-vm"
  project_id    = var.project_id_hub
  name          = "${local.hub_prefix}flood4-vm${count.index}"
  zone          = "${local.hub_us_region}-b"
  tags          = [local.tag_ssh, ]
  instance_type = "e2-standard-4"
  network_interfaces = [{
    network    = google_compute_network.hub_vpc.self_link
    subnetwork = local.hub_us_subnet1.self_link
    addresses = {
      external = google_compute_address.hub_flood4_vm[count.index].address
      internal = null
    }
    nat       = true
    alias_ips = null
  }]
  service_account         = module.hub_sa.email
  service_account_scopes  = ["cloud-platform"]
  metadata_startup_script = local.hub_flood4_vm_startup
}

resource "local_file" "hub_flood4_vm" {
  count    = local.flood4_count
  content  = local.hub_flood4_vm_startup
  filename = "config/flood4-vm${count.index}"
}

# flood7 alert traffic gen

module "hub_flood7_vm" {
  count         = local.flood7_count
  source        = "../../modules/compute-vm"
  project_id    = var.project_id_hub
  name          = "${local.hub_prefix}flood7-vm${count.index}"
  zone          = "${local.hub_us_region}-b"
  tags          = [local.tag_ssh, ]
  instance_type = "e2-standard-2"
  network_interfaces = [{
    network    = google_compute_network.hub_vpc.self_link
    subnetwork = local.hub_us_subnet1.self_link
    addresses = {
      external = google_compute_address.hub_flood7_vm[count.index].address
      internal = null
    }
    nat       = true
    alias_ips = null
  }]
  service_account         = module.hub_sa.email
  service_account_scopes  = ["cloud-platform"]
  metadata_startup_script = local.hub_flood7_vm_startup
}

resource "local_file" "hub_flood7_vm" {
  count    = local.flood7_count
  content  = local.hub_flood7_vm_startup
  filename = "config/flood7-vm${count.index}"
}

# baseline traffic gen

module "hub_baseline_vm" {
  source        = "../../modules/compute-vm"
  project_id    = var.project_id_hub
  name          = "${local.hub_prefix}baseline-vm"
  zone          = "${local.hub_us_region}-b"
  tags          = [local.tag_ssh, ]
  instance_type = "e2-standard-2"
  network_interfaces = [{
    network    = google_compute_network.hub_vpc.self_link
    subnetwork = local.hub_us_subnet1.self_link
    addresses = {
      external = google_compute_address.hub_baseline_vm.address
      internal = null
    }
    nat       = true
    alias_ips = null
  }]
  service_account         = module.hub_sa.email
  service_account_scopes  = ["cloud-platform"]
  metadata_startup_script = local.hub_baseline_vm_startup
}

resource "local_file" "hub_baseline_vm" {
  content  = local.hub_baseline_vm_startup
  filename = "config/baseline-vm"
}

# denied traffic gen

module "hub_denied_vm" {
  source        = "../../modules/compute-vm"
  project_id    = var.project_id_hub
  name          = "${local.hub_prefix}denied-vm"
  zone          = "${local.hub_us_region}-b"
  tags          = [local.tag_ssh, ]
  instance_type = "e2-medium"
  network_interfaces = [{
    network    = google_compute_network.hub_vpc.self_link
    subnetwork = local.hub_us_subnet1.self_link
    addresses = {
      external = google_compute_address.hub_denied_vm.address
      internal = null
    }
    nat       = true
    alias_ips = null
  }]
  service_account         = module.hub_sa.email
  service_account_scopes  = ["cloud-platform"]
  metadata_startup_script = local.hub_denied_vm_startup
}

resource "local_file" "hub_denied_vm" {
  content  = local.hub_denied_vm_startup
  filename = "config/denied-vm"
}
