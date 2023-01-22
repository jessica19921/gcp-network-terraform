
# path2

module "path2_nva1" {
  source         = "../../modules/compute-vm"
  project_id     = var.project_id_hub
  name           = "${local.prefix}-path2-nva1"
  zone           = "${local.region1}-b"
  tags           = [local.tag_ssh, ]
  can_ip_forward = true
  network_interfaces = [
    {
      network    = google_compute_network.core_vpc.self_link
      subnetwork = local.core_subnet_region1.self_link
      addresses = {
        internal = local.core_path2_nva_addr
        external = null
      }
      nat = false, alias_ips = null
    },
    {
      network    = google_compute_network.transit_vpc.self_link
      subnetwork = local.transit_subnet_region1.self_link
      addresses = {
        internal = local.transit_path2_nva1_addr
        external = null
      }
      nat = false, alias_ips = null
    }
  ]
  metadata_startup_script = local.path2_nva1_startup
}

resource "local_file" "path2_nva1" {
  content  = module.path2_nva1.instance.metadata_startup_script
  filename = "_config/path2-nva1"
}

module "path2_nva2" {
  source         = "../../modules/compute-vm"
  project_id     = var.project_id_hub
  name           = "${local.prefix}-path2-nva2"
  zone           = "${local.region3}-b"
  tags           = [local.tag_ssh, ]
  can_ip_forward = true
  network_interfaces = [
    {
      network    = google_compute_network.edge_vpc.self_link
      subnetwork = local.edge_subnet.self_link
      addresses = {
        internal = local.edge_path2_nva_addr
        external = null
      }
      nat = false, alias_ips = null
    },
    {
      network    = google_compute_network.transit_vpc.self_link
      subnetwork = local.transit_subnet_region3.self_link
      addresses = {
        internal = local.transit_path2_nva2_addr
        external = null
      }
      nat = false, alias_ips = null
    }
  ]
  metadata_startup_script = local.path2_nva2_startup
}

resource "local_file" "path2_nva2" {
  content  = module.path2_nva2.instance.metadata_startup_script
  filename = "_config/path2-nva2"
}

# path3

module "path3_nva1" {
  source         = "../../modules/compute-vm"
  project_id     = var.project_id_hub
  name           = "${local.prefix}-path3-nva1"
  zone           = "${local.region2}-b"
  tags           = [local.tag_ssh, ]
  can_ip_forward = true
  network_interfaces = [
    {
      network    = google_compute_network.core_vpc.self_link
      subnetwork = local.core_subnet_region2.self_link
      addresses = {
        internal = local.core_path3_nva_addr
        external = null
      }
      nat = false, alias_ips = null
    },
    {
      network    = google_compute_network.transit_vpc.self_link
      subnetwork = local.transit_subnet_region2.self_link
      addresses = {
        internal = local.transit_path3_nva1_addr
        external = null
      }
      nat = false, alias_ips = null
    }
  ]
  metadata_startup_script = local.path3_nva1_startup
}

resource "local_file" "path3_nva1" {
  content  = module.path3_nva1.instance.metadata_startup_script
  filename = "_config/path3-nva1"
}

module "path3_nva2" {
  source         = "../../modules/compute-vm"
  project_id     = var.project_id_hub
  name           = "${local.prefix}-path3-nva2"
  zone           = "${local.region3}-b"
  tags           = [local.tag_ssh, ]
  can_ip_forward = true
  network_interfaces = [
    {
      network    = google_compute_network.edge_vpc.self_link
      subnetwork = local.edge_subnet.self_link
      addresses = {
        internal = local.edge_path3_nva_addr
        external = null
      }
      nat = false, alias_ips = null
    },
    {
      network    = google_compute_network.transit_vpc.self_link
      subnetwork = local.transit_subnet_region3.self_link
      addresses = {
        internal = local.transit_path3_nva2_addr
        external = null
      }
      nat = false, alias_ips = null
    }
  ]
  metadata_startup_script = local.path3_nva2_startup
}

resource "local_file" "path3_nva2" {
  content  = module.path3_nva2.instance.metadata_startup_script
  filename = "_config/path3-nva2"
}
