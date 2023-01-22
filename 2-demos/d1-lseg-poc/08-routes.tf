
# core
#---------------------------------

locals {
  core_routes = {
    ("to-edge-path2-vm")          = { dest = local.edge_path2_vm_addr, next_hop = module.path2_nva1.instance.self_link }
    ("to-edge-path3-vm")          = { dest = local.edge_path3_vm_addr, next_hop = module.path3_nva1.instance.self_link }
    ("to-client-mcast-via-path2") = { dest = local.client_mcast_vm_addr, next_hop = module.path2_nva1.instance.self_link } # mcast between venue & client pinned to path2
  }
}

resource "google_compute_route" "core_routes" {
  for_each          = local.core_routes
  provider          = google-beta
  project           = var.project_id_hub
  name              = "${local.core_prefix}${each.key}"
  dest_range        = each.value.dest
  network           = google_compute_network.core_vpc.id
  next_hop_instance = each.value.next_hop
  priority          = "100"
}

# transit
#---------------------------------

locals {
  transit_routes = {
    ("to-core-path2-vm")          = { dest = local.core_path2_vm_addr, next_hop = module.path2_nva1.instance.self_link }
    ("to-core-path3-vm")          = { dest = local.core_path3_vm_addr, next_hop = module.path3_nva1.instance.self_link }
    ("to-edge-path2-vm")          = { dest = local.edge_path2_vm_addr, next_hop = module.path2_nva2.instance.self_link }
    ("to-edge-path3-vm")          = { dest = local.edge_path3_vm_addr, next_hop = module.path3_nva2.instance.self_link }
    ("to-venue-mcast-via-path2")  = { dest = local.venue_mcast_vm_addr, next_hop = module.path2_nva1.instance.self_link }  # mcast between venue & client pinned to path2
    ("to-client-mcast-via-path2") = { dest = local.client_mcast_vm_addr, next_hop = module.path2_nva2.instance.self_link } # mcast between venue & client pinned to path2
  }
}

resource "google_compute_route" "transit_routes" {
  for_each          = local.transit_routes
  provider          = google-beta
  project           = var.project_id_hub
  name              = "${local.transit_prefix}${each.key}"
  dest_range        = each.value.dest
  network           = google_compute_network.transit_vpc.id
  next_hop_instance = each.value.next_hop
  priority          = "100"
}

# edge
#---------------------------------

locals {
  edge_routes = {
    ("to-core-path2-vm")         = { dest = local.core_path2_vm_addr, next_hop = module.path2_nva2.instance.self_link }
    ("to-core-path3-vm")         = { dest = local.core_path3_vm_addr, next_hop = module.path3_nva2.instance.self_link }
    ("to-venue-mcast-via-path2") = { dest = local.venue_mcast_vm_addr, next_hop = module.path2_nva2.instance.self_link } # mcast between venue & client pinned to path2
  }
}

resource "google_compute_route" "edge_routes" {
  for_each          = local.edge_routes
  provider          = google-beta
  project           = var.project_id_hub
  name              = "${local.edge_prefix}${each.key}"
  dest_range        = each.value.dest
  network           = google_compute_network.edge_vpc.id
  next_hop_instance = each.value.next_hop
  priority          = "100"
}
