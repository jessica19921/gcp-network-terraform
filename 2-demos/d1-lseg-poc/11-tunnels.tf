
locals {
  advertised_prefixes = {
    core_to_venue = merge(
      { for k, v in local.core_subnets_region1 : v.ip_cidr_range => k }, # for traffic aimed at core vms
      { for k, v in local.core_subnets_region2 : v.ip_cidr_range => k }, # for traffic aimed at core vms
      { for k, v in local.client_subnets : v.ip_cidr_range => k }        # for mcast traffic aimed at client
    )
    edge_to_client = merge(
      { for k, v in local.edge_subnets : v.ip_cidr_range => k }, # for traffic aimed at edge vms
      { for k, v in local.venue_subnets : v.ip_cidr_range => k } # for mcast traffic aimed at venue
    )
    venue_to_core  = { for k, v in local.venue_subnets : v.ip_cidr_range => k }
    client_to_edge = { for k, v in local.client_subnets : v.ip_cidr_range => k }
    core_to_nsp1   = { (local.core_path1_vm_addr) = "core path1-vm" }
    core_to_nsp2   = { (local.core_path4_vm_addr) = "core path4-vm" }
    edge_to_nsp1   = { (local.edge_path1_vm_addr) = "edge path1-vm" }
    edge_to_nsp2   = { (local.edge_path4_vm_addr) = "edge path4-vm" }
    nsp1_to_core   = { (local.edge_path1_vm_addr) = "edge path1-vm" }
    nsp2_to_core   = { (local.edge_path4_vm_addr) = "edge path4-vm" }
    nsp1_to_edge   = { (local.core_path1_vm_addr) = "core path1-vm" }
    nsp2_to_edge   = { (local.core_path4_vm_addr) = "core path4-vm" }
  }
}

# routers
#------------------------------

# venue

resource "google_compute_router" "venue_vpn_cr" {
  project = var.project_id_onprem
  name    = "${local.venue_prefix}vpn-cr"
  network = google_compute_network.venue_vpc.self_link
  region  = local.region1
  bgp {
    asn               = local.venue_asn
    advertise_mode    = "CUSTOM"
    advertised_groups = null
  }
}

# core

resource "google_compute_router" "core_region1_vpn_cr" {
  project = var.project_id_hub
  name    = "${local.core_prefix}region1-vpn-cr"
  network = google_compute_network.core_vpc.self_link
  region  = local.region1
  bgp {
    asn               = local.core_region1_vpn_cr_asn
    advertise_mode    = "CUSTOM"
    advertised_groups = null
  }
}

resource "google_compute_router" "core_region2_vpn_cr" {
  project = var.project_id_hub
  name    = "${local.core_prefix}region2-vpn-cr"
  network = google_compute_network.core_vpc.self_link
  region  = local.region2
  bgp {
    asn               = local.core_region2_vpn_cr_asn
    advertise_mode    = "CUSTOM"
    advertised_groups = null
  }
}

# edge

resource "google_compute_router" "edge_vpn_cr" {
  project = var.project_id_hub
  name    = "${local.edge_prefix}vpn-cr"
  network = google_compute_network.edge_vpc.self_link
  region  = local.region3
  bgp {
    asn               = local.edge_vpn_cr_asn
    advertise_mode    = "CUSTOM"
    advertised_groups = null
  }
}

# client

resource "google_compute_router" "client_vpn_cr" {
  project = var.project_id_onprem
  name    = "${local.client_prefix}region3-vpn-cr"
  network = google_compute_network.client_vpc.self_link
  region  = local.region3
  bgp {
    asn               = local.client_asn
    advertise_mode    = "CUSTOM"
    advertised_groups = null
  }
}

# nsp1

resource "google_compute_router" "nsp1_region1_vpn_cr" {
  project = var.project_id_onprem
  name    = "${local.nsp1_prefix}region1-vpn-cr"
  network = google_compute_network.nsp1_vpc.self_link
  region  = local.region1
  bgp {
    asn               = local.nsp1_asn
    advertise_mode    = "CUSTOM"
    advertised_groups = null
  }
}

resource "google_compute_router" "nsp1_region3_vpn_cr" {
  project = var.project_id_onprem
  name    = "${local.nsp1_prefix}region3-vpn-cr"
  network = google_compute_network.nsp1_vpc.self_link
  region  = local.region3
  bgp {
    asn               = local.nsp1_asn
    advertise_mode    = "CUSTOM"
    advertised_groups = null
  }
}

# nsp2

resource "google_compute_router" "nsp2_region2_vpn_cr" {
  project = var.project_id_onprem
  name    = "${local.nsp2_prefix}region2-vpn-cr"
  network = google_compute_network.nsp2_vpc.self_link
  region  = local.region2
  bgp {
    asn               = local.nsp2_asn
    advertise_mode    = "CUSTOM"
    advertised_groups = null
  }
}

resource "google_compute_router" "nsp2_region3_vpn_cr" {
  project = var.project_id_onprem
  name    = "${local.nsp2_prefix}region3-vpn-cr"
  network = google_compute_network.nsp2_vpc.self_link
  region  = local.region3
  bgp {
    asn               = local.nsp2_asn
    advertise_mode    = "CUSTOM"
    advertised_groups = null
  }
}

# vpn gateways
#------------------------------

# venue

resource "google_compute_ha_vpn_gateway" "venue_gw" {
  project = var.project_id_onprem
  name    = "${local.venue_prefix}gw"
  network = google_compute_network.venue_vpc.self_link
  region  = local.region1
}

# core

resource "google_compute_ha_vpn_gateway" "core_region1_gw" {
  project = var.project_id_hub
  name    = "${local.core_prefix}region1-gw"
  network = google_compute_network.core_vpc.self_link
  region  = local.region1
}

resource "google_compute_ha_vpn_gateway" "core_region2_gw" {
  project = var.project_id_hub
  name    = "${local.core_prefix}region2-gw"
  network = google_compute_network.core_vpc.self_link
  region  = local.region2
}

# edge

resource "google_compute_ha_vpn_gateway" "edge_gw" {
  project = var.project_id_hub
  name    = "${local.edge_prefix}gw"
  network = google_compute_network.edge_vpc.self_link
  region  = local.region3
}

# client

resource "google_compute_ha_vpn_gateway" "client_gw" {
  project = var.project_id_onprem
  name    = "${local.client_prefix}gw"
  network = google_compute_network.client_vpc.self_link
  region  = local.region3
}

# nsp1

resource "google_compute_ha_vpn_gateway" "nsp1_region1_gw" {
  project = var.project_id_onprem
  name    = "${local.nsp1_prefix}region1-gw"
  network = google_compute_network.nsp1_vpc.self_link
  region  = local.region1
}

resource "google_compute_ha_vpn_gateway" "nsp1_region3_gw" {
  project = var.project_id_onprem
  name    = "${local.nsp1_prefix}region3-gw"
  network = google_compute_network.nsp1_vpc.self_link
  region  = local.region3
}

# nsp2

resource "google_compute_ha_vpn_gateway" "nsp2_region2_gw" {
  project = var.project_id_onprem
  name    = "${local.nsp2_prefix}region2-gw"
  network = google_compute_network.nsp2_vpc.self_link
  region  = local.region2
}

resource "google_compute_ha_vpn_gateway" "nsp2_region3_gw" {
  project = var.project_id_onprem
  name    = "${local.nsp2_prefix}region3-gw"
  network = google_compute_network.nsp2_vpc.self_link
  region  = local.region3
}

# core / venue
#------------------------------

module "vpn_core_region1_to_venue" {
  source             = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-vpn-ha"
  project_id         = var.project_id_hub
  region             = local.region1
  network            = google_compute_network.core_vpc.self_link
  name               = "${local.core_prefix}region1-to-venue"
  vpn_gateway        = google_compute_ha_vpn_gateway.core_region1_gw.self_link
  peer_gcp_gateway   = google_compute_ha_vpn_gateway.venue_gw.self_link
  vpn_gateway_create = false
  router_create      = false
  router_name        = google_compute_router.core_region1_vpn_cr.name
  tunnels = {
    tun-0 = {
      bgp_peer = {
        address = cidrhost(var.bgp_range.cidr1, 1)
        asn     = local.venue_asn
      }
      bgp_peer_options = {
        advertise_groups    = null
        advertise_mode      = "CUSTOM"
        advertise_ip_ranges = local.advertised_prefixes.core_to_venue
        route_priority      = 100
      }
      bgp_session_range               = "${cidrhost(var.bgp_range.cidr1, 2)}/30"
      ike_version                     = 2
      vpn_gateway_interface           = 0
      peer_external_gateway_interface = null
      router                          = google_compute_router.core_region1_vpn_cr.name
      shared_secret                   = local.psk
    }
    tun-1 = {
      bgp_peer = {
        address = cidrhost(var.bgp_range.cidr2, 1)
        asn     = local.venue_asn
      }
      bgp_peer_options = {
        advertise_groups    = null
        advertise_mode      = "CUSTOM"
        advertise_ip_ranges = local.advertised_prefixes.core_to_venue
        route_priority      = 100
      }
      bgp_session_range               = "${cidrhost(var.bgp_range.cidr2, 2)}/30"
      ike_version                     = 2
      vpn_gateway_interface           = 1
      peer_external_gateway_interface = null
      router                          = google_compute_router.core_region1_vpn_cr.name
      shared_secret                   = local.psk
    }
  }
}

module "vpn_venue_to_core_region1" {
  source             = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-vpn-ha"
  project_id         = var.project_id_onprem
  region             = local.region1
  network            = google_compute_network.venue_vpc.self_link
  name               = "${local.venue_prefix}to-core-region1"
  vpn_gateway        = google_compute_ha_vpn_gateway.venue_gw.self_link
  peer_gcp_gateway   = google_compute_ha_vpn_gateway.core_region1_gw.self_link
  vpn_gateway_create = false
  router_create      = false
  router_name        = google_compute_router.venue_vpn_cr.name

  tunnels = {
    tun-0 = {
      bgp_peer = {
        address = cidrhost(var.bgp_range.cidr1, 2)
        asn     = local.core_region1_vpn_cr_asn
      }
      bgp_peer_options = {
        advertise_groups    = null
        advertise_mode      = "CUSTOM"
        advertise_ip_ranges = local.advertised_prefixes.venue_to_core
        route_priority      = 100
      }
      bgp_session_range               = "${cidrhost(var.bgp_range.cidr1, 1)}/30"
      ike_version                     = 2
      vpn_gateway_interface           = 0
      peer_external_gateway_interface = null
      router                          = google_compute_router.venue_vpn_cr.name
      shared_secret                   = local.psk
    }
    tun-1 = {
      bgp_peer = {
        address = cidrhost(var.bgp_range.cidr2, 2)
        asn     = local.core_region1_vpn_cr_asn
      }
      bgp_peer_options = {
        advertise_groups    = null
        advertise_mode      = "CUSTOM"
        advertise_ip_ranges = local.advertised_prefixes.venue_to_core
        route_priority      = 100
      }
      bgp_session_range               = "${cidrhost(var.bgp_range.cidr2, 1)}/30"
      ike_version                     = 2
      vpn_gateway_interface           = 1
      peer_external_gateway_interface = null
      router                          = google_compute_router.venue_vpn_cr.name
      shared_secret                   = local.psk
    }
  }
}

# edge / client
#------------------------------

# edge

module "vpn_edge_to_client" {
  source             = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-vpn-ha"
  project_id         = var.project_id_hub
  region             = local.region3
  network            = google_compute_network.edge_vpc.self_link
  name               = "${local.edge_prefix}to-client"
  vpn_gateway        = google_compute_ha_vpn_gateway.edge_gw.self_link
  peer_gcp_gateway   = google_compute_ha_vpn_gateway.client_gw.self_link
  vpn_gateway_create = false
  router_create      = false
  router_name        = google_compute_router.edge_vpn_cr.name

  tunnels = {
    tun-0 = {
      bgp_peer = {
        address = cidrhost(var.bgp_range.cidr1, 1)
        asn     = local.client_asn
      }
      bgp_peer_options = {
        advertise_groups    = null
        advertise_mode      = "CUSTOM"
        advertise_ip_ranges = local.advertised_prefixes.edge_to_client
        route_priority      = 100
      }
      bgp_session_range               = "${cidrhost(var.bgp_range.cidr1, 2)}/30"
      ike_version                     = 2
      vpn_gateway_interface           = 0
      peer_external_gateway_interface = null
      router                          = google_compute_router.edge_vpn_cr.name
      shared_secret                   = local.psk
    }
    tun-1 = {
      bgp_peer = {
        address = cidrhost(var.bgp_range.cidr2, 1)
        asn     = local.client_asn
      }
      bgp_peer_options = {
        advertise_groups    = null
        advertise_mode      = "CUSTOM"
        advertise_ip_ranges = local.advertised_prefixes.edge_to_client
        route_priority      = 100
      }
      bgp_session_range               = "${cidrhost(var.bgp_range.cidr2, 2)}/30"
      ike_version                     = 2
      vpn_gateway_interface           = 1
      peer_external_gateway_interface = null
      router                          = google_compute_router.edge_vpn_cr.name
      shared_secret                   = local.psk
    }
  }
}

# client

module "vpn_client_to_edge" {
  source             = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-vpn-ha"
  project_id         = var.project_id_onprem
  region             = local.region3
  network            = google_compute_network.client_vpc.self_link
  name               = "${local.client_prefix}to-edge"
  vpn_gateway        = google_compute_ha_vpn_gateway.client_gw.self_link
  peer_gcp_gateway   = google_compute_ha_vpn_gateway.edge_gw.self_link
  vpn_gateway_create = false
  router_create      = false
  router_name        = google_compute_router.client_vpn_cr.name

  tunnels = {
    tun-0 = {
      bgp_peer = {
        address = cidrhost(var.bgp_range.cidr1, 2)
        asn     = local.edge_vpn_cr_asn
      }
      bgp_peer_options = {
        advertise_groups    = null
        advertise_mode      = "CUSTOM"
        advertise_ip_ranges = local.advertised_prefixes.client_to_edge
        route_priority      = 100
      }
      bgp_session_range               = "${cidrhost(var.bgp_range.cidr1, 1)}/30"
      ike_version                     = 2
      vpn_gateway_interface           = 0
      peer_external_gateway_interface = null
      router                          = google_compute_router.client_vpn_cr.name
      shared_secret                   = local.psk
    }
    tun-1 = {
      bgp_peer = {
        address = cidrhost(var.bgp_range.cidr2, 2)
        asn     = local.edge_vpn_cr_asn
      }
      bgp_peer_options = {
        advertise_groups    = null
        advertise_mode      = "CUSTOM"
        advertise_ip_ranges = local.advertised_prefixes.client_to_edge
        route_priority      = 100
      }
      bgp_session_range               = "${cidrhost(var.bgp_range.cidr2, 1)}/30"
      ike_version                     = 2
      vpn_gateway_interface           = 1
      peer_external_gateway_interface = null
      router                          = google_compute_router.client_vpn_cr.name
      shared_secret                   = local.psk
    }
  }
}

# core / nsp1
#------------------------------

# core

module "vpn_core_to_nsp1" {
  source             = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-vpn-ha"
  project_id         = var.project_id_hub
  region             = local.region1
  network            = google_compute_network.core_vpc.self_link
  name               = "${local.core_prefix}to-nsp1"
  vpn_gateway        = google_compute_ha_vpn_gateway.core_region1_gw.self_link
  peer_gcp_gateway   = google_compute_ha_vpn_gateway.nsp1_region1_gw.self_link
  vpn_gateway_create = false
  router_create      = false
  router_name        = google_compute_router.core_region1_vpn_cr.name
  tunnels = {
    tun-0 = {
      bgp_peer = {
        address = cidrhost(var.bgp_range.cidr3, 1)
        asn     = local.nsp1_asn
      }
      bgp_peer_options = {
        advertise_groups    = null
        advertise_mode      = "CUSTOM"
        advertise_ip_ranges = local.advertised_prefixes.core_to_nsp1
        route_priority      = 100
      }
      bgp_session_range               = "${cidrhost(var.bgp_range.cidr3, 2)}/30"
      ike_version                     = 2
      vpn_gateway_interface           = 0
      peer_external_gateway_interface = null
      router                          = google_compute_router.core_region1_vpn_cr.name
      shared_secret                   = local.psk
    }
    tun-1 = {
      bgp_peer = {
        address = cidrhost(var.bgp_range.cidr4, 1)
        asn     = local.nsp1_asn
      }
      bgp_peer_options = {
        advertise_groups    = null
        advertise_mode      = "CUSTOM"
        advertise_ip_ranges = local.advertised_prefixes.core_to_nsp1
        route_priority      = 100
      }
      bgp_session_range               = "${cidrhost(var.bgp_range.cidr4, 2)}/30"
      ike_version                     = 2
      vpn_gateway_interface           = 1
      peer_external_gateway_interface = null
      router                          = google_compute_router.core_region1_vpn_cr.name
      shared_secret                   = local.psk
    }
  }
}

module "vpn_nsp1_region1_to_core" {
  source             = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-vpn-ha"
  project_id         = var.project_id_onprem
  region             = local.region1
  network            = google_compute_network.nsp1_vpc.self_link
  name               = "${local.nsp1_prefix}region1-to-core"
  vpn_gateway        = google_compute_ha_vpn_gateway.nsp1_region1_gw.self_link
  peer_gcp_gateway   = google_compute_ha_vpn_gateway.core_region1_gw.self_link
  vpn_gateway_create = false
  router_create      = false
  router_name        = google_compute_router.nsp1_region1_vpn_cr.name

  tunnels = {
    tun-0 = {
      bgp_peer = {
        address = cidrhost(var.bgp_range.cidr3, 2)
        asn     = local.core_region1_vpn_cr_asn
      }
      bgp_peer_options = {
        advertise_groups    = null
        advertise_mode      = "CUSTOM"
        advertise_ip_ranges = local.advertised_prefixes.nsp1_to_core
        route_priority      = 100
      }
      bgp_session_range               = "${cidrhost(var.bgp_range.cidr3, 1)}/30"
      ike_version                     = 2
      vpn_gateway_interface           = 0
      peer_external_gateway_interface = null
      router                          = google_compute_router.nsp1_region1_vpn_cr.name
      shared_secret                   = local.psk
    }
    tun-1 = {
      bgp_peer = {
        address = cidrhost(var.bgp_range.cidr4, 2)
        asn     = local.core_region1_vpn_cr_asn
      }
      bgp_peer_options = {
        advertise_groups    = null
        advertise_mode      = "CUSTOM"
        advertise_ip_ranges = local.advertised_prefixes.nsp1_to_core
        route_priority      = 100
      }
      bgp_session_range               = "${cidrhost(var.bgp_range.cidr4, 1)}/30"
      ike_version                     = 2
      vpn_gateway_interface           = 1
      peer_external_gateway_interface = null
      router                          = google_compute_router.nsp1_region1_vpn_cr.name
      shared_secret                   = local.psk
    }
  }
}

# core / nsp2
#------------------------------

# core

module "vpn_core_to_nsp2" {
  source             = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-vpn-ha"
  project_id         = var.project_id_hub
  region             = local.region2
  network            = google_compute_network.core_vpc.self_link
  name               = "${local.core_prefix}to-nsp2"
  vpn_gateway        = google_compute_ha_vpn_gateway.core_region2_gw.self_link
  peer_gcp_gateway   = google_compute_ha_vpn_gateway.nsp2_region2_gw.self_link
  vpn_gateway_create = false
  router_create      = false
  router_name        = google_compute_router.core_region2_vpn_cr.name
  tunnels = {
    tun-0 = {
      bgp_peer = {
        address = cidrhost(var.bgp_range.cidr5, 1)
        asn     = local.nsp2_asn
      }
      bgp_peer_options = {
        advertise_groups    = null
        advertise_mode      = "CUSTOM"
        advertise_ip_ranges = local.advertised_prefixes.core_to_nsp2
        route_priority      = 100
      }
      bgp_session_range               = "${cidrhost(var.bgp_range.cidr5, 2)}/30"
      ike_version                     = 2
      vpn_gateway_interface           = 0
      peer_external_gateway_interface = null
      router                          = google_compute_router.core_region2_vpn_cr.name
      shared_secret                   = local.psk
    }
    tun-1 = {
      bgp_peer = {
        address = cidrhost(var.bgp_range.cidr6, 1)
        asn     = local.nsp2_asn
      }
      bgp_peer_options = {
        advertise_groups    = null
        advertise_mode      = "CUSTOM"
        advertise_ip_ranges = local.advertised_prefixes.core_to_nsp2
        route_priority      = 100
      }
      bgp_session_range               = "${cidrhost(var.bgp_range.cidr6, 2)}/30"
      ike_version                     = 2
      vpn_gateway_interface           = 1
      peer_external_gateway_interface = null
      router                          = google_compute_router.core_region2_vpn_cr.name
      shared_secret                   = local.psk
    }
  }
}

module "vpn_nsp2_region2_to_core" {
  source             = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-vpn-ha"
  project_id         = var.project_id_onprem
  region             = local.region2
  network            = google_compute_network.nsp2_vpc.self_link
  name               = "${local.nsp2_prefix}region2-to-core"
  vpn_gateway        = google_compute_ha_vpn_gateway.nsp2_region2_gw.self_link
  peer_gcp_gateway   = google_compute_ha_vpn_gateway.core_region2_gw.self_link
  vpn_gateway_create = false
  router_create      = false
  router_name        = google_compute_router.nsp2_region2_vpn_cr.name

  tunnels = {
    tun-0 = {
      bgp_peer = {
        address = cidrhost(var.bgp_range.cidr5, 2)
        asn     = local.core_region2_vpn_cr_asn
      }
      bgp_peer_options = {
        advertise_groups    = null
        advertise_mode      = "CUSTOM"
        advertise_ip_ranges = local.advertised_prefixes.nsp2_to_core
        route_priority      = 100
      }
      bgp_session_range               = "${cidrhost(var.bgp_range.cidr5, 1)}/30"
      ike_version                     = 2
      vpn_gateway_interface           = 0
      peer_external_gateway_interface = null
      router                          = google_compute_router.nsp2_region2_vpn_cr.name
      shared_secret                   = local.psk
    }
    tun-1 = {
      bgp_peer = {
        address = cidrhost(var.bgp_range.cidr6, 2)
        asn     = local.core_region2_vpn_cr_asn
      }
      bgp_peer_options = {
        advertise_groups    = null
        advertise_mode      = "CUSTOM"
        advertise_ip_ranges = local.advertised_prefixes.nsp2_to_core
        route_priority      = 100
      }
      bgp_session_range               = "${cidrhost(var.bgp_range.cidr6, 1)}/30"
      ike_version                     = 2
      vpn_gateway_interface           = 1
      peer_external_gateway_interface = null
      router                          = google_compute_router.nsp2_region2_vpn_cr.name
      shared_secret                   = local.psk
    }
  }
}

# edge / nsp1
#------------------------------

# edge

module "vpn_edge_to_nsp1_region3" {
  source             = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-vpn-ha"
  project_id         = var.project_id_hub
  region             = local.region3
  network            = google_compute_network.edge_vpc.self_link
  name               = "${local.edge_prefix}to-nsp1-region3"
  vpn_gateway        = google_compute_ha_vpn_gateway.edge_gw.self_link
  peer_gcp_gateway   = google_compute_ha_vpn_gateway.nsp1_region3_gw.self_link
  vpn_gateway_create = false
  router_create      = false
  router_name        = google_compute_router.edge_vpn_cr.name

  tunnels = {
    tun-0 = {
      bgp_peer = {
        address = cidrhost(var.bgp_range.cidr3, 1)
        asn     = local.nsp1_asn
      }
      bgp_peer_options = {
        advertise_groups    = null
        advertise_mode      = "CUSTOM"
        advertise_ip_ranges = local.advertised_prefixes.edge_to_nsp1
        route_priority      = 100
      }
      bgp_session_range               = "${cidrhost(var.bgp_range.cidr3, 2)}/30"
      ike_version                     = 2
      vpn_gateway_interface           = 0
      peer_external_gateway_interface = null
      router                          = google_compute_router.edge_vpn_cr.name
      shared_secret                   = local.psk
    }
    tun-1 = {
      bgp_peer = {
        address = cidrhost(var.bgp_range.cidr4, 1)
        asn     = local.nsp1_asn
      }
      bgp_peer_options = {
        advertise_groups    = null
        advertise_mode      = "CUSTOM"
        advertise_ip_ranges = local.advertised_prefixes.edge_to_nsp1
        route_priority      = 100
      }
      bgp_session_range               = "${cidrhost(var.bgp_range.cidr4, 2)}/30"
      ike_version                     = 2
      vpn_gateway_interface           = 1
      peer_external_gateway_interface = null
      router                          = google_compute_router.edge_vpn_cr.name
      shared_secret                   = local.psk
    }
  }
}

# nsp1

module "vpn_nsp1_region_to_edge" {
  source             = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-vpn-ha"
  project_id         = var.project_id_onprem
  region             = local.region3
  network            = google_compute_network.nsp1_vpc.self_link
  name               = "${local.nsp1_prefix}to-edge"
  vpn_gateway        = google_compute_ha_vpn_gateway.nsp1_region3_gw.self_link
  peer_gcp_gateway   = google_compute_ha_vpn_gateway.edge_gw.self_link
  vpn_gateway_create = false
  router_create      = false
  router_name        = google_compute_router.nsp1_region3_vpn_cr.name

  tunnels = {
    tun-0 = {
      bgp_peer = {
        address = cidrhost(var.bgp_range.cidr3, 2)
        asn     = local.edge_vpn_cr_asn
      }
      bgp_peer_options = {
        advertise_groups    = null
        advertise_mode      = "CUSTOM"
        advertise_ip_ranges = local.advertised_prefixes.nsp1_to_edge
        route_priority      = 100
      }
      bgp_session_range               = "${cidrhost(var.bgp_range.cidr3, 1)}/30"
      ike_version                     = 2
      vpn_gateway_interface           = 0
      peer_external_gateway_interface = null
      router                          = google_compute_router.nsp1_region3_vpn_cr.name
      shared_secret                   = local.psk
    }
    tun-1 = {
      bgp_peer = {
        address = cidrhost(var.bgp_range.cidr4, 2)
        asn     = local.edge_vpn_cr_asn
      }
      bgp_peer_options = {
        advertise_groups    = null
        advertise_mode      = "CUSTOM"
        advertise_ip_ranges = local.advertised_prefixes.nsp1_to_edge
        route_priority      = 100
      }
      bgp_session_range               = "${cidrhost(var.bgp_range.cidr4, 1)}/30"
      ike_version                     = 2
      vpn_gateway_interface           = 1
      peer_external_gateway_interface = null
      router                          = google_compute_router.nsp1_region3_vpn_cr.name
      shared_secret                   = local.psk
    }
  }
}

# edge / nsp2
#------------------------------

# edge

module "vpn_edge_to_nsp2_region3" {
  source             = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-vpn-ha"
  project_id         = var.project_id_hub
  region             = local.region3
  network            = google_compute_network.edge_vpc.self_link
  name               = "${local.edge_prefix}to-nsp2-region3"
  vpn_gateway        = google_compute_ha_vpn_gateway.edge_gw.self_link
  peer_gcp_gateway   = google_compute_ha_vpn_gateway.nsp2_region3_gw.self_link
  vpn_gateway_create = false
  router_create      = false
  router_name        = google_compute_router.edge_vpn_cr.name

  tunnels = {
    tun-0 = {
      bgp_peer = {
        address = cidrhost(var.bgp_range.cidr5, 1)
        asn     = local.nsp2_asn
      }
      bgp_peer_options = {
        advertise_groups    = null
        advertise_mode      = "CUSTOM"
        advertise_ip_ranges = local.advertised_prefixes.edge_to_nsp2
        route_priority      = 100
      }
      bgp_session_range               = "${cidrhost(var.bgp_range.cidr5, 2)}/30"
      ike_version                     = 2
      vpn_gateway_interface           = 0
      peer_external_gateway_interface = null
      router                          = google_compute_router.edge_vpn_cr.name
      shared_secret                   = local.psk
    }
    tun-1 = {
      bgp_peer = {
        address = cidrhost(var.bgp_range.cidr6, 1)
        asn     = local.nsp2_asn
      }
      bgp_peer_options = {
        advertise_groups    = null
        advertise_mode      = "CUSTOM"
        advertise_ip_ranges = local.advertised_prefixes.edge_to_nsp2
        route_priority      = 100
      }
      bgp_session_range               = "${cidrhost(var.bgp_range.cidr6, 2)}/30"
      ike_version                     = 2
      vpn_gateway_interface           = 1
      peer_external_gateway_interface = null
      router                          = google_compute_router.edge_vpn_cr.name
      shared_secret                   = local.psk
    }
  }
}

# nsp2

module "vpn_nsp2_region_to_edge" {
  source             = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-vpn-ha"
  project_id         = var.project_id_onprem
  region             = local.region3
  network            = google_compute_network.nsp2_vpc.self_link
  name               = "${local.nsp2_prefix}to-edge"
  vpn_gateway        = google_compute_ha_vpn_gateway.nsp2_region3_gw.self_link
  peer_gcp_gateway   = google_compute_ha_vpn_gateway.edge_gw.self_link
  vpn_gateway_create = false
  router_create      = false
  router_name        = google_compute_router.nsp2_region3_vpn_cr.name

  tunnels = {
    tun-0 = {
      bgp_peer = {
        address = cidrhost(var.bgp_range.cidr5, 2)
        asn     = local.edge_vpn_cr_asn
      }
      bgp_peer_options = {
        advertise_groups    = null
        advertise_mode      = "CUSTOM"
        advertise_ip_ranges = local.advertised_prefixes.nsp2_to_edge
        route_priority      = 100
      }
      bgp_session_range               = "${cidrhost(var.bgp_range.cidr5, 1)}/30"
      ike_version                     = 2
      vpn_gateway_interface           = 0
      peer_external_gateway_interface = null
      router                          = google_compute_router.nsp2_region3_vpn_cr.name
      shared_secret                   = local.psk
    }
    tun-1 = {
      bgp_peer = {
        address = cidrhost(var.bgp_range.cidr6, 2)
        asn     = local.edge_vpn_cr_asn
      }
      bgp_peer_options = {
        advertise_groups    = null
        advertise_mode      = "CUSTOM"
        advertise_ip_ranges = local.advertised_prefixes.nsp2_to_edge
        route_priority      = 100
      }
      bgp_session_range               = "${cidrhost(var.bgp_range.cidr6, 1)}/30"
      ike_version                     = 2
      vpn_gateway_interface           = 1
      peer_external_gateway_interface = null
      router                          = google_compute_router.nsp2_region3_vpn_cr.name
      shared_secret                   = local.psk
    }
  }
}
