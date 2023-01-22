
locals {
  edge_regions = [local.region3, ]
  edge_subnet  = google_compute_subnetwork.edge_subnets["${local.edge_prefix}subnet"]
}

# network
#---------------------------------

resource "google_compute_network" "edge_vpc" {
  project      = var.project_id_hub
  name         = "${local.edge_prefix}vpc"
  routing_mode = "GLOBAL"
  mtu          = 1460

  auto_create_subnetworks         = false
  delete_default_routes_on_create = false
}

# subnets
#---------------------------------

resource "google_compute_subnetwork" "edge_subnets" {
  for_each      = local.edge_subnets
  provider      = google-beta
  project       = var.project_id_hub
  name          = each.key
  network       = google_compute_network.edge_vpc.id
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

module "edge_nat" {
  source                = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-cloudnat"
  for_each              = toset(local.edge_regions)
  project_id            = var.project_id_hub
  region                = each.key
  name                  = "${local.edge_prefix}${each.key}"
  router_network        = google_compute_network.edge_vpc.self_link
  router_create         = true
  config_source_subnets = "ALL_SUBNETWORKS_ALL_PRIMARY_IP_RANGES"
}

# firewall
#---------------------------------

module "edge_firewall" {
  source              = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-vpc-firewall"
  project_id          = var.project_id_hub
  network             = google_compute_network.edge_vpc.name
  admin_ranges        = []
  http_source_ranges  = []
  https_source_ranges = []
  custom_rules = {
    "${local.edge_prefix}internal" = {
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
  }
}

# workload
#---------------------------------

# vm1

module "edge_path1_vm" {
  source     = "../../modules/compute-vm"
  project_id = var.project_id_hub
  name       = "${local.edge_prefix}path1-vm"
  zone       = "${local.region3}-b"
  tags       = [local.tag_ssh, ]
  network_interfaces = [{
    network    = google_compute_network.edge_vpc.self_link
    subnetwork = local.edge_subnet.self_link
    addresses = {
      internal = local.edge_path1_vm_addr
      external = null
    }
    nat = false, alias_ips = null
  }]
  metadata_startup_script = local.edge_path1_startup
}

resource "local_file" "edge_path1_vm" {
  content  = module.edge_path1_vm.instance.metadata_startup_script
  filename = "_config/edge-path1-vm.sh"
}

# vm2

module "edge_path2_vm" {
  source     = "../../modules/compute-vm"
  project_id = var.project_id_hub
  name       = "${local.edge_prefix}path2-vm"
  zone       = "${local.region3}-b"
  tags       = [local.tag_ssh, ]
  network_interfaces = [{
    network    = google_compute_network.edge_vpc.self_link
    subnetwork = local.edge_subnet.self_link
    addresses = {
      internal = local.edge_path2_vm_addr
      external = null
    }
    nat = false, alias_ips = null
  }]
  metadata_startup_script = local.edge_path2_startup
}

resource "local_file" "edge_path2_vm" {
  content  = module.edge_path2_vm.instance.metadata_startup_script
  filename = "_config/edge-path2-vm.sh"
}

# vm3

module "edge_path3_vm" {
  source     = "../../modules/compute-vm"
  project_id = var.project_id_hub
  name       = "${local.edge_prefix}path3-vm"
  zone       = "${local.region3}-b"
  tags       = [local.tag_ssh, ]
  network_interfaces = [{
    network    = google_compute_network.edge_vpc.self_link
    subnetwork = local.edge_subnet.self_link
    addresses = {
      internal = local.edge_path3_vm_addr
      external = null
    }
    nat = false, alias_ips = null
  }]
  metadata_startup_script = local.edge_path3_startup
}

resource "local_file" "edge_path3_vm" {
  content  = module.edge_path3_vm.instance.metadata_startup_script
  filename = "_config/edge-path3-vm.sh"
}

# vm4

module "edge_path4_vm" {
  source     = "../../modules/compute-vm"
  project_id = var.project_id_hub
  name       = "${local.edge_prefix}path4-vm"
  zone       = "${local.region3}-b"
  tags       = [local.tag_ssh, ]
  network_interfaces = [{
    network    = google_compute_network.edge_vpc.self_link
    subnetwork = local.edge_subnet.self_link
    addresses = {
      internal = local.edge_path4_vm_addr
      external = null
    }
    nat = false, alias_ips = null
  }]
  metadata_startup_script = local.edge_path4_startup
}

resource "local_file" "edge_path4_vm" {
  content  = module.edge_path4_vm.instance.metadata_startup_script
  filename = "_config/edge-path4-vm.sh"
}
