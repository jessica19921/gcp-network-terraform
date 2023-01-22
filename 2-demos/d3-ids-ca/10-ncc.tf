
# hub
#---------------------------------

resource "google_network_connectivity_hub" "ncc_hub" {
  provider    = google-beta
  project     = var.project_id_hub
  name        = "${local.hub_prefix}ncc-hub"
  description = "A sample hub"
  labels = {
    lab = local.hub_prefix
  }
}

# spoke1 (site1 vpn)
#---------------------------------

locals {
  ncc_spoke1_create = templatefile("scripts/ncc/vpn/create.sh", {
    PROJECT_ID = var.project_id_hub
    HUB_NAME   = google_network_connectivity_hub.ncc_hub.name
    SPOKE_NAME = "${local.hub_prefix}ncc-spoke1"
    REGION     = local.site1_region
    TUNNEL1    = module.vpn_hub_eu_to_site1.tunnel_self_links["tun-0"]
    TUNNEL2    = module.vpn_hub_eu_to_site1.tunnel_self_links["tun-1"]
  })
  ncc_spoke1_delete = templatefile("scripts/ncc/vpn/delete.sh", {
    PROJECT_ID = var.project_id_hub
    SPOKE_NAME = "${local.hub_prefix}ncc-spoke1"
    REGION     = local.site1_region
  })
}

resource "null_resource" "ncc_spoke1" {
  triggers = {
    create = local.ncc_spoke1_create
    delete = local.ncc_spoke1_delete
  }
  provisioner "local-exec" {
    command = self.triggers.create
  }
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete
  }
}

# spoke2 (site2 vpn)
#---------------------------------

locals {
  ncc_spoke2_create = templatefile("scripts/ncc/vpn/create.sh", {
    PROJECT_ID = var.project_id_hub
    HUB_NAME   = google_network_connectivity_hub.ncc_hub.name
    SPOKE_NAME = "${local.hub_prefix}ncc-spoke2"
    REGION     = local.site2_region
    TUNNEL1    = module.vpn_hub_us_to_site2.tunnel_self_links["tun-0"]
    TUNNEL2    = module.vpn_hub_us_to_site2.tunnel_self_links["tun-1"]
  })
  ncc_spoke2_delete = templatefile("scripts/ncc/vpn/delete.sh", {
    PROJECT_ID = var.project_id_hub
    SPOKE_NAME = "${local.hub_prefix}ncc-spoke2"
    REGION     = local.site2_region
  })
}

resource "null_resource" "ncc_spoke2" {
  triggers = {
    create = local.ncc_spoke2_create
    delete = local.ncc_spoke2_delete
  }
  provisioner "local-exec" {
    command = self.triggers.create
  }
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete
  }
}

/*
# spoke1 (site1 vpn)
#---------------------------------

resource "google_network_connectivity_spoke" "ncc_spoke1" {
  provider    = google-beta
  project     = var.project_id_hub
  name        = "${local.hub_prefix}ncc-spoke1"
  description = "site1 europe"
  location    = local.site1_region
  hub         = google_network_connectivity_hub.ncc_hub.id
  linked_vpn_tunnels {
    uris                       = [module.vpn_hub_eu_to_site1.tunnel_self_links["tun-0"]]
    site_to_site_data_transfer = true
  }
  labels = {
    lab = local.hub_prefix
  }
}*/
