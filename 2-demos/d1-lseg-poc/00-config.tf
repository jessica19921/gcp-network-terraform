
# common
#--------------------------------

locals {
  supernet     = "10.0.0.0/8"
  region1      = "us-central1"
  region2      = "us-east4"
  region3      = "northamerica-northeast2"
  cloud_domain = "gcp"
  psk          = "changeme"
  tag_router   = "router"
  tag_ssh      = "ssh"
  netblocks = {
    dns      = data.google_netblock_ip_ranges.dns_forwarders.cidr_blocks_ipv4
    gfe      = data.google_netblock_ip_ranges.health_checkers.cidr_blocks_ipv4
    iap      = data.google_netblock_ip_ranges.iap_forwarders.cidr_blocks_ipv4
    internal = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  }
  svc_web     = { name = "http8080", port = 8080 }
  svc_mcast   = { port = 8001 }
  vxlan_range = "192.168.0.0/24"
  vxlan_mask  = split("/", local.vxlan_range).1
}

resource "random_id" "random" {
  byte_length = 2
}

# netblocks

data "google_netblock_ip_ranges" "dns_forwarders" { range_type = "dns-forwarders" }
data "google_netblock_ip_ranges" "private_googleapis" { range_type = "private-googleapis" }
data "google_netblock_ip_ranges" "restricted_googleapis" { range_type = "restricted-googleapis" }
data "google_netblock_ip_ranges" "health_checkers" { range_type = "health-checkers" }
data "google_netblock_ip_ranges" "iap_forwarders" { range_type = "iap-forwarders" }

# venue
#--------------------------------

locals {
  venue_prefix   = local.prefix == "" ? "venue-" : join("-", [local.prefix, "venue-"])
  venue_asn      = "65010"
  venue_supernet = "10.10.0.0/16"
  venue_subnets = {
    ("${local.venue_prefix}subnet") = {
      region                = local.region1
      ip_cidr_range         = "10.10.1.0/24"
      secondary_ip_range    = null
      subnet_flow_logs      = false
      log_config            = null
      private_google_access = false
      purpose               = "PRIVATE"
      role                  = null
    }
  }
  venue_probe_vm_addr = cidrhost(local.venue_subnets["${local.venue_prefix}subnet"].ip_cidr_range, 8)
  venue_mcast_vm_addr = cidrhost(local.venue_subnets["${local.venue_prefix}subnet"].ip_cidr_range, 9)
  venue_vxlan_addr    = cidrhost(local.vxlan_range, 1)
}

# core
#--------------------------------

locals {
  core_prefix             = local.prefix == "" ? "core-" : join("-", [local.prefix, "core-"])
  core_region1_vpn_cr_asn = 65101
  core_region1_ncc_cr_asn = 65102
  core_region2_vpn_cr_asn = 65103
  core_region2_ncc_cr_asn = 65104
  core_supernet           = "10.1.0.0/16"
  core_subnets_region1 = {
    ("${local.core_prefix}subnet-region1") = {
      region                     = local.region1
      ip_cidr_range              = "10.1.1.0/24"
      secondary_ip_range         = null
      subnet_flow_logs           = false
      log_config                 = null
      private_google_access      = true
      private_ipv6_google_access = false
      purpose                    = "PRIVATE"
      role                       = null
    }
  }
  core_subnets_region2 = {
    ("${local.core_prefix}subnet-region2") = {
      region                     = local.region2
      ip_cidr_range              = "10.1.2.0/24"
      secondary_ip_range         = null
      subnet_flow_logs           = false
      log_config                 = null
      private_google_access      = true
      private_ipv6_google_access = false
      purpose                    = "PRIVATE"
      role                       = null
    }
  }
  core_path2_nva_addr = cidrhost(local.core_subnets_region1["${local.core_prefix}subnet-region1"].ip_cidr_range, 2)
  core_path3_nva_addr = cidrhost(local.core_subnets_region2["${local.core_prefix}subnet-region2"].ip_cidr_range, 2)
  core_path1_vm_addr  = cidrhost(local.core_subnets_region1["${local.core_prefix}subnet-region1"].ip_cidr_range, 10)
  core_path2_vm_addr  = cidrhost(local.core_subnets_region1["${local.core_prefix}subnet-region1"].ip_cidr_range, 20)
  core_path3_vm_addr  = cidrhost(local.core_subnets_region2["${local.core_prefix}subnet-region2"].ip_cidr_range, 30)
  core_path4_vm_addr  = cidrhost(local.core_subnets_region2["${local.core_prefix}subnet-region2"].ip_cidr_range, 40)
}

# transit
#--------------------------------

locals {
  transit_prefix             = local.prefix == "" ? "transit-" : join("-", [local.prefix, "transit-"])
  transit_region1_vpn_cr_asn = 65201
  transit_region1_ncc_cr_asn = 65202
  transit_region2_vpn_cr_asn = 65203
  transit_region2_ncc_cr_asn = 65204
  transit_region3_vpn_cr_asn = 65205
  transit_region3_ncc_cr_asn = 65206
  transit_supernet           = "10.2.0.0/16"
  transit_subnets_region1 = {
    ("${local.transit_prefix}subnet-region1") = {
      region                     = local.region1
      ip_cidr_range              = "10.2.1.0/24"
      secondary_ip_range         = null
      subnet_flow_logs           = false
      log_config                 = null
      private_google_access      = true
      private_ipv6_google_access = false
      purpose                    = "PRIVATE"
      role                       = null
    }
  }
  transit_subnets_region2 = {
    ("${local.transit_prefix}subnet-region2") = {
      region                     = local.region2
      ip_cidr_range              = "10.2.2.0/24"
      secondary_ip_range         = null
      subnet_flow_logs           = false
      log_config                 = null
      private_google_access      = true
      private_ipv6_google_access = false
      purpose                    = "PRIVATE"
      role                       = null
    }
  }
  transit_subnets_region3 = {
    ("${local.transit_prefix}subnet-region3") = {
      region                     = local.region3
      ip_cidr_range              = "10.2.3.0/24"
      secondary_ip_range         = null
      subnet_flow_logs           = false
      log_config                 = null
      private_google_access      = true
      private_ipv6_google_access = false
      purpose                    = "PRIVATE"
      role                       = null
    }
  }
  transit_path2_nva1_addr = cidrhost(local.transit_subnets_region1["${local.transit_prefix}subnet-region1"].ip_cidr_range, 2)
  transit_path2_nva2_addr = cidrhost(local.transit_subnets_region3["${local.transit_prefix}subnet-region3"].ip_cidr_range, 2)
  transit_path3_nva1_addr = cidrhost(local.transit_subnets_region2["${local.transit_prefix}subnet-region2"].ip_cidr_range, 2)
  transit_path3_nva2_addr = cidrhost(local.transit_subnets_region3["${local.transit_prefix}subnet-region3"].ip_cidr_range, 3)
}

# edge
#--------------------------------

locals {
  edge_prefix     = local.prefix == "" ? "edge-" : join("-", [local.prefix, "edge-"])
  edge_vpn_cr_asn = 65301
  edge_ncc_cr_asn = 65302
  edge_supernet   = "10.3.0.0/16"
  edge_subnets = {
    ("${local.edge_prefix}subnet") = {
      region                     = local.region3
      ip_cidr_range              = "10.3.3.0/24"
      secondary_ip_range         = null
      subnet_flow_logs           = false
      log_config                 = null
      private_google_access      = true
      private_ipv6_google_access = false
      purpose                    = "PRIVATE"
      role                       = null
    }
  }
  edge_path2_nva_addr = cidrhost(local.edge_subnets["${local.edge_prefix}subnet"].ip_cidr_range, 2)
  edge_path3_nva_addr = cidrhost(local.edge_subnets["${local.edge_prefix}subnet"].ip_cidr_range, 3)
  edge_path1_vm_addr  = cidrhost(local.edge_subnets["${local.edge_prefix}subnet"].ip_cidr_range, 10)
  edge_path2_vm_addr  = cidrhost(local.edge_subnets["${local.edge_prefix}subnet"].ip_cidr_range, 20)
  edge_path3_vm_addr  = cidrhost(local.edge_subnets["${local.edge_prefix}subnet"].ip_cidr_range, 30)
  edge_path4_vm_addr  = cidrhost(local.edge_subnets["${local.edge_prefix}subnet"].ip_cidr_range, 40)
}

# client
#--------------------------------

locals {
  client_prefix   = local.prefix == "" ? "client-" : join("-", [local.prefix, "client-"])
  client_asn      = "65020"
  client_supernet = "10.20.0.0/16"
  client_subnets = {
    ("${local.client_prefix}subnet") = {
      region                = local.region3
      ip_cidr_range         = "10.20.1.0/24"
      secondary_ip_range    = null
      subnet_flow_logs      = false
      log_config            = null
      private_google_access = false
      purpose               = "PRIVATE"
      role                  = null
    }
  }
  client_probe_vm_addr = cidrhost(local.client_subnets["${local.client_prefix}subnet"].ip_cidr_range, 8)
  client_mcast_vm_addr = cidrhost(local.client_subnets["${local.client_prefix}subnet"].ip_cidr_range, 9)
  client_vxlan_addr    = cidrhost(local.vxlan_range, 2)
}

# path1
#--------------------------------

locals {
  nsp1_prefix = local.prefix == "" ? "nsp1-" : join("-", [local.prefix, "nsp1-"])
  nsp1_asn    = "65030"
}

# path4
#--------------------------------

locals {
  nsp2_prefix = local.prefix == "" ? "nsp2-" : join("-", [local.prefix, "nsp2-"])
  nsp2_asn    = "65040"
}
