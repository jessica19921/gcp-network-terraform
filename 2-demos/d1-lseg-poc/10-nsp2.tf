
# network
#---------------------------------

resource "google_compute_network" "nsp2_vpc" {
  project      = var.project_id_onprem
  name         = "${local.nsp2_prefix}vpc"
  routing_mode = "GLOBAL"
  mtu          = 1460

  auto_create_subnetworks         = false
  delete_default_routes_on_create = false
}
