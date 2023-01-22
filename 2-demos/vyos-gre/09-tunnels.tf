
locals {
  advertised_prefixes = {
    site1_to_hub  = { (local.site1_router_addr) = "site1 router" }
    site2_to_hub  = { (local.site2_router_addr) = "site2 router" }
    hub_to_site1  = { (local.hub_eu_router_addr) = "hub eu router" }
    hub_to_site2  = { (local.hub_us_router_addr) = "hub us router" }
    spoke2_to_hub = { (local.spoke2_supernet) = "spoke2 supernet" }
    hub_to_spoke2 = {
      (local.hub_supernet)    = "hub supernet"
      (local.site1_supernet)  = "site1 supernet"
      (local.site2_supernet)  = "site2 supernet"
      (local.spoke1_supernet) = "spoke1 supernet"
    }
  }
}

# routers
#------------------------------------

# site1

resource "google_compute_router" "site1_vpn_cr" {
  project = var.project_id_onprem
  name    = "${local.site1_prefix}vpn-cr"
  network = google_compute_network.site1_vpc.self_link
  region  = local.site1_region
  bgp {
    asn               = local.site1_asn
    advertise_mode    = "CUSTOM"
    advertised_groups = null
  }
}

# hub

resource "google_compute_router" "hub_eu_vpn_cr" {
  project = var.project_id_hub
  name    = "${local.hub_prefix}eu-vpn-cr"
  network = google_compute_network.hub_vpc.self_link
  region  = local.hub_eu_region
  bgp {
    asn               = local.hub_eu_vpn_cr_asn
    advertise_mode    = "CUSTOM"
    advertised_groups = null
  }
}

resource "google_compute_router" "hub_us_vpn_cr" {
  project = var.project_id_hub
  name    = "${local.hub_prefix}us-vpn-cr"
  network = google_compute_network.hub_vpc.self_link
  region  = local.hub_us_region
  bgp {
    asn               = local.hub_us_vpn_cr_asn
    advertise_mode    = "CUSTOM"
    advertised_groups = null
  }
}

# vpn gateways
#------------------------------------

# onprem

resource "google_compute_ha_vpn_gateway" "site1_gw" {
  project = var.project_id_onprem
  name    = "${local.site1_prefix}gw"
  network = google_compute_network.site1_vpc.self_link
  region  = local.site1_region
}

# hub

resource "google_compute_ha_vpn_gateway" "hub_eu_gw" {
  project = var.project_id_hub
  name    = "${local.hub_prefix}eu-gw"
  network = google_compute_network.hub_vpc.self_link
  region  = local.hub_eu_region
}

# hub / site1 (ipsec)
#------------------------------------

# hub

module "vpn_hub_eu_to_site1" {
  source             = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-vpn-ha"
  project_id         = var.project_id_hub
  region             = local.hub_eu_region
  network            = google_compute_network.hub_vpc.self_link
  name               = "${local.hub_prefix}eu-to-site1"
  vpn_gateway        = google_compute_ha_vpn_gateway.hub_eu_gw.self_link
  peer_gcp_gateway   = google_compute_ha_vpn_gateway.site1_gw.self_link
  vpn_gateway_create = false
  router_create      = false
  router_name        = google_compute_router.hub_eu_vpn_cr.name

  tunnels = {
    tun-0 = {
      bgp_peer = {
        address = cidrhost(var.bgp_range.cidr1, 1)
        asn     = local.site1_asn
      }
      bgp_peer_options = {
        advertise_groups    = null
        advertise_mode      = "CUSTOM"
        advertise_ip_ranges = local.advertised_prefixes.hub_to_site1
        route_priority      = 100
      }
      bgp_session_range               = "${cidrhost(var.bgp_range.cidr1, 2)}/30"
      ike_version                     = 2
      vpn_gateway_interface           = 0
      peer_external_gateway_interface = null
      router                          = google_compute_router.hub_eu_vpn_cr.name
      shared_secret                   = local.psk
    }
    tun-1 = {
      bgp_peer = {
        address = cidrhost(var.bgp_range.cidr2, 1)
        asn     = local.site1_asn
      }
      bgp_peer_options = {
        advertise_groups    = null
        advertise_mode      = "CUSTOM"
        advertise_ip_ranges = local.advertised_prefixes.hub_to_site1
        route_priority      = 100
      }
      bgp_session_range               = "${cidrhost(var.bgp_range.cidr2, 2)}/30"
      ike_version                     = 2
      vpn_gateway_interface           = 1
      peer_external_gateway_interface = null
      router                          = google_compute_router.hub_eu_vpn_cr.name
      shared_secret                   = local.psk
    }
  }
}

# site1

module "vpn_site1_to_hub_eu" {
  source             = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/net-vpn-ha"
  project_id         = var.project_id_onprem
  region             = local.site1_region
  network            = google_compute_network.site1_vpc.self_link
  name               = "${local.site1_prefix}to-hub-eu"
  vpn_gateway        = google_compute_ha_vpn_gateway.site1_gw.self_link
  peer_gcp_gateway   = google_compute_ha_vpn_gateway.hub_eu_gw.self_link
  vpn_gateway_create = false
  router_create      = false
  router_name        = google_compute_router.site1_vpn_cr.name

  tunnels = {
    tun-0 = {
      bgp_peer = {
        address = cidrhost(var.bgp_range.cidr1, 2)
        asn     = local.hub_eu_vpn_cr_asn
      }
      bgp_peer_options = {
        advertise_groups    = null
        advertise_mode      = "CUSTOM"
        advertise_ip_ranges = local.advertised_prefixes.site1_to_hub
        route_priority      = 100
      }
      bgp_session_range               = "${cidrhost(var.bgp_range.cidr1, 1)}/30"
      ike_version                     = 2
      vpn_gateway_interface           = 0
      peer_external_gateway_interface = null
      router                          = google_compute_router.site1_vpn_cr.name
      shared_secret                   = local.psk
    }
    tun-1 = {
      bgp_peer = {
        address = cidrhost(var.bgp_range.cidr2, 2)
        asn     = local.hub_eu_vpn_cr_asn
      }
      bgp_peer_options = {
        advertise_groups    = null
        advertise_mode      = "CUSTOM"
        advertise_ip_ranges = local.advertised_prefixes.site1_to_hub
        route_priority      = 100
      }
      bgp_session_range               = "${cidrhost(var.bgp_range.cidr2, 1)}/30"
      ike_version                     = 2
      vpn_gateway_interface           = 1
      peer_external_gateway_interface = null
      router                          = google_compute_router.site1_vpn_cr.name
      shared_secret                   = local.psk
    }
  }
}

# hub / site1 (gre)
#------------------------------------

# hub

locals {
  hub_eu_router_startup = templatefile("scripts/vyos/vyos.sh", {
    LOCAL_ASN        = local.hub_eu_router_asn
    LOOPBACK_IP      = local.hub_eu_router_lo_addr
    ENABLE_BGP       = true
    BGP_USE_LOOPBACK = true
    STATIC_ROUTES = [
      { destination = "${local.site1_router_addr}/32", next_hop = cidrhost(local.hub_eu_subnet1.ip_cidr_range, 1) }
    ]
    IPSEC_CONFIG = { enable = false, interface = "eth0" }
    DNAT_CONFIG  = []
    TUNNELS = [{
      enable           = true
      name             = "tun0"
      encapsulation    = "gre"
      tunnel_mask      = split("/", var.gre_range.cidr1).1
      tunnel_addr      = cidrhost(var.gre_range.cidr1, 2)
      peer_tunnel_addr = cidrhost(var.gre_range.cidr1, 1)
      local_ip         = local.hub_eu_router_addr
      remote_ip        = local.site1_router_addr
    }]
    VPN_TUNNELS = []
    PREFIX_LISTS = [
      { enable = true, name = "PL-OUT-SITE", prefix = local.supernet, rule = 10, action = "permit" },
      { enable = true, name = "PL-IN-SITE", prefix = local.site1_supernet, rule = 10, action = "permit" },
      { enable = true, name = "PL-OUT-CR", prefix = local.site1_supernet, rule = 10, action = "permit" },
      { enable = true, name = "PL-IN-CR", prefix = local.supernet, rule = 10, action = "permit" },
    ]
    AS_LISTS = [
      { enable = true, name = "AL-OUT-SITE", rule = 10, regex = "_16550_", action = "deny" },
      { enable = true, name = "AL-OUT-SITE", rule = 20, regex = "_", action = "permit" },
      { enable = true, name = "AL-IN-SITE", rule = 10, regex = "_16550_", action = "deny" },
      { enable = true, name = "AL-IN-SITE", rule = 20, regex = "_", action = "permit" },
      { enable = true, name = "AL-OUT-CR", rule = 10, regex = "_", action = "permit" },
      { enable = true, name = "AL-IN-CR", rule = 10, regex = "_", action = "permit" },
    ]
    ROUTE_MAPS = [
      #{ enable = true, name = "MAP-OUT-SITE", type = "as-list", list = "AL-OUT-SITE", set_metric = 100, rule = 10, action = "permit" },
      #{ enable = true, name = "MAP-IN-SITE", type = "as-list", list = "AL-IN-SITE", set_metric = 100, rule = 10, action = "permit" },
      #{ enable = true, name = "MAP-OUT-CR", type = "as-list", list = "AL-OUT-CR", set_metric = 100, rule = 10, action = "permit" },
      #{ enable = true, name = "MAP-IN-CR", type = "as-list", list = "AL-IN-CR", set_metric = 100, rule = 10, action = "permit" },

      { enable = true, name = "MAP-OUT-SITE", type = "pf-list", list = "PL-OUT-SITE", set_metric = 105, rule = 20, action = "permit" },
      { enable = true, name = "MAP-IN-SITE", type = "pf-list", list = "PL-IN-SITE", set_metric = 105, rule = 20, action = "permit" },
      { enable = true, name = "MAP-OUT-CR", type = "pf-list", list = "PL-OUT-CR", set_metric = 105, rule = 20, action = "permit" },
      { enable = true, name = "MAP-IN-CR", type = "pf-list", list = "PL-IN-CR", set_metric = 105, rule = 20, action = "permit" },
    ]
    BGP_SESSIONS = [
      {
        peer_asn         = local.site1_asn
        peer_ip          = cidrhost(var.gre_range.cidr1, 1)
        multihop         = { enable = true, ttl = 4 }
        route_map_export = { enable = true, map = "MAP-OUT-SITE" }
        route_map_import = { enable = true, map = "MAP-IN-SITE" }
      },
      {
        peer_asn         = local.hub_eu_ncc_cr_asn
        peer_ip          = local.hub_eu_ncc_cr_addr0
        multihop         = { enable = false, ttl = 4 }
        route_map_export = { enable = true, map = "MAP-OUT-CR" }
        route_map_import = { enable = true, map = "MAP-IN-CR" }
      },
      {
        peer_asn         = local.hub_eu_ncc_cr_asn
        peer_ip          = local.hub_eu_ncc_cr_addr1
        multihop         = { enable = false, ttl = 4 }
        route_map_export = { enable = true, map = "MAP-OUT-CR" }
        route_map_import = { enable = true, map = "MAP-IN-CR" }
      }
    ]
    BGP_REDISTRIBUTE_STATIC = { enable = false, metric = 90 }
    BGP_ADVERTISED_NETWORKS = []
  })
}

resource "google_compute_instance" "hub_eu_router" {
  project        = var.project_id_hub
  name           = "${local.hub_prefix}eu-router"
  machine_type   = "e2-medium"
  zone           = "${local.hub_eu_region}-b"
  tags           = [local.tag_router]
  can_ip_forward = true
  boot_disk {
    initialize_params {
      image = var.image_vyos
      size  = var.disk_size
      type  = var.disk_type
    }
  }
  network_interface {
    network    = google_compute_network.hub_vpc.self_link
    subnetwork = local.hub_eu_subnet1.self_link
    network_ip = local.hub_eu_router_addr
    access_config {
      nat_ip = google_compute_address.hub_eu_router.address
    }
  }
  service_account {
    scopes = ["cloud-platform"]
  }
  metadata = {
    ssh-keys                 = "vyos:${tls_private_key.vyos_router.public_key_openssh}"
    google-monitoring-enable = 0
    google-logging-enable    = 0
    enable-oslogin           = false
  }
}

resource "null_resource" "deploy_hub_eu_router" {
  triggers = {}
  connection {
    type        = "ssh"
    user        = "vyos"
    private_key = chomp(tls_private_key.vyos_router.private_key_pem)
    host        = google_compute_instance.hub_eu_router.network_interface.0.access_config.0.nat_ip
  }
  provisioner "file" {
    content     = local.hub_eu_router_startup
    destination = "/var/tmp/vyos.sh"
  }
  provisioner "remote-exec" {
    inline = ["/bin/vbash /var/tmp/vyos.sh"]
  }
}

resource "local_file" "hub_eu_router_startup" {
  content  = local.hub_eu_router_startup
  filename = "_config/vyos/hub-eu.sh"
}

# site1

locals {
  site1_router_startup = templatefile("scripts/vyos/vyos.sh", {
    LOCAL_ASN        = local.site1_asn
    LOOPBACK_IP      = local.site1_router_lo_addr
    ENABLE_BGP       = true
    BGP_USE_LOOPBACK = true
    STATIC_ROUTES = [
      { destination = local.site1_supernet, next_hop = cidrhost(local.site1_subnet1.ip_cidr_range, 1) },
      { destination = "${local.hub_eu_router_addr}/32", next_hop = cidrhost(local.site1_subnet1.ip_cidr_range, 1) },
    ]
    IPSEC_CONFIG = { enable = false, interface = "eth0" }
    DNAT_CONFIG = [{
      enable              = false
      rule                = 10
      outbound_interface  = "eth0"
      destination_address = ""
      translation_address = ""
    }]
    TUNNELS = [{
      enable           = true
      name             = "tun0"
      encapsulation    = "gre"
      tunnel_mask      = split("/", var.gre_range.cidr1).1
      tunnel_addr      = cidrhost(var.gre_range.cidr1, 1)
      peer_tunnel_addr = cidrhost(var.gre_range.cidr1, 2)
      local_ip         = local.site1_router_addr
      remote_ip        = local.hub_eu_router_addr
    }]
    VPN_TUNNELS = []
    PREFIX_LISTS = [
      { enable = true, name = "PL-OUT-HUB", prefix = local.site1_supernet, rule = 10, action = "permit" },
      { enable = true, name = "PL-IN-HUB", prefix = local.supernet, rule = 10, action = "permit" },
    ]
    AS_LISTS = [
      { enable = true, name = "AL-OUT-HUB", rule = 10, regex = "_", action = "permit" },
      { enable = true, name = "AL-IN-HUB", rule = 10, regex = "_", action = "permit" },
    ]
    ROUTE_MAPS = [
      { enable = true, name = "MAP-OUT-HUB", type = "as-list", list = "AL-OUT-HUB", set_metric = 100, rule = 10, action = "permit" },
      { enable = true, name = "MAP-OUT-HUB", type = "pf-list", list = "PL-OUT-HUB", set_metric = 105, rule = 20, action = "permit" },
      { enable = true, name = "MAP-IN-HUB", type = "as-list", list = "AL-IN-HUB", set_metric = 100, rule = 10, action = "permit" },
      { enable = true, name = "MAP-IN-HUB", type = "pf-list", list = "PL-IN-HUB", set_metric = 105, rule = 20, action = "permit" },
    ]
    BGP_SESSIONS = [{
      peer_asn         = local.hub_eu_router_asn
      peer_ip          = cidrhost(var.gre_range.cidr1, 2)
      multihop         = { enable = true, ttl = 4 }
      route_map_export = { enable = true, map = "MAP-OUT-HUB" }
      route_map_import = { enable = true, map = "MAP-IN-HUB" }
    }]
    BGP_REDISTRIBUTE_STATIC = { enable = true, metric = 90 }
    BGP_ADVERTISED_NETWORKS = []
  })
}

resource "google_compute_instance" "site1_router" {
  project        = var.project_id_onprem
  name           = "${local.site1_prefix}router"
  machine_type   = "e2-medium"
  zone           = "${local.site1_region}-b"
  tags           = [local.tag_router]
  can_ip_forward = true
  boot_disk {
    initialize_params {
      image = var.image_vyos
      size  = var.disk_size
      type  = var.disk_type
    }
  }
  network_interface {
    network    = google_compute_network.site1_vpc.self_link
    subnetwork = local.site1_subnet1.self_link
    network_ip = local.site1_router_addr
    access_config {
      nat_ip = google_compute_address.site1_router.address
    }
  }
  service_account {
    scopes = ["cloud-platform"]
  }
  metadata = {
    ssh-keys                 = "vyos:${tls_private_key.vyos_router.public_key_openssh}"
    google-monitoring-enable = 0
    google-logging-enable    = 0
    enable-oslogin           = false
  }
}

resource "null_resource" "deploy_site1_router" {
  triggers = {}
  connection {
    type        = "ssh"
    user        = "vyos"
    private_key = chomp(tls_private_key.vyos_router.private_key_pem)
    host        = google_compute_instance.site1_router.network_interface.0.access_config.0.nat_ip
  }
  provisioner "file" {
    content     = local.site1_router_startup
    destination = "/var/tmp/vyos.sh"
  }
  provisioner "remote-exec" {
    inline = ["/bin/vbash /var/tmp/vyos.sh"]
  }
}

resource "local_file" "site1_router_startup" {
  content  = local.site1_router_startup
  filename = "_config/vyos/site1.sh"
}

## static routes

locals {
  site1_router_routes = { "supernet" = local.supernet }
}

resource "google_compute_route" "site1_router_routes" {
  for_each               = local.site1_router_routes
  provider               = google-beta
  project                = var.project_id_onprem
  name                   = "${local.site1_prefix}${each.key}"
  dest_range             = each.value
  network                = google_compute_network.site1_vpc.self_link
  next_hop_instance      = google_compute_instance.site1_router.id
  next_hop_instance_zone = "${local.site1_region}-b"
  priority               = "100"
}
