
# common
#---------------------------------

locals {
  prefix = "d1"
}

# venue
#---------------------------------

locals {
  venue_mcast_startup = templatefile("scripts/mcast.sh", {
    WEB_PORT          = local.svc_web.port
    RVD               = "/opt/tibco/tibrv/8.4/bin/rvd64"
    MCAST_SEND_ADDR   = "239.100.1.1"
    MCAST_LISTEN_ADDR = "239.100.1.1"
    MCAST_PORT        = local.svc_mcast.port
    VXLAN_ADDR        = local.venue_vxlan_addr
    VXLAN_MASK        = local.vxlan_mask
    VXLAN_DEV_ADDR    = local.venue_mcast_vm_addr
    VXLAN_PEERS       = [local.client_mcast_vm_addr, ]
    PING_TARGETS      = [local.client_mcast_vm_addr, local.client_vxlan_addr, ]
    CURL_TARGETS      = local.venue_targets
  })
  venue_probe_startup = templatefile("scripts/probe.sh", {
    PROBE_WEB_SERVER_PORT = local.svc_web.port # required if sink is enabled
    CURL_TARGETS          = local.venue_targets
    PROBE_TARGETS         = local.venue_targets
    PING_TARGETS = [
      local.core_path1_vm_addr,
      local.core_path2_vm_addr,
      local.core_path3_vm_addr,
      local.core_path4_vm_addr,
    ]
  })
  venue_targets = [
    "${local.core_path1_vm_addr}:${local.svc_web.port}",
    "${local.core_path2_vm_addr}:${local.svc_web.port}",
    "${local.core_path3_vm_addr}:${local.svc_web.port}",
    "${local.core_path4_vm_addr}:${local.svc_web.port}",
  ]
}

# core
#---------------------------------

locals {
  core_path1_vm_startup = templatefile("scripts/platform.sh", {
    WEB_PORT     = local.svc_web.port
    CURL_TARGETS = local.core_curl_targets
    PING_TARGETS = local.core_ping_targets
    DNAT_TARGETS = [
      { s = local.venue_supernet, p = "tcp", dport = local.svc_web.port, dnat = local.edge_path1_vm_addr },
      { s = local.edge_supernet, p = "tcp", dport = local.svc_web.port, dnat = local.venue_probe_vm_addr },
    ]
  })
  core_path2_vm_startup = templatefile("scripts/platform.sh", {
    WEB_PORT     = local.svc_web.port
    CURL_TARGETS = local.core_curl_targets
    PING_TARGETS = local.core_ping_targets
    DNAT_TARGETS = [
      { s = local.venue_supernet, p = "tcp", dport = local.svc_web.port, dnat = local.edge_path2_vm_addr },
      { s = local.edge_supernet, p = "tcp", dport = local.svc_web.port, dnat = local.venue_probe_vm_addr },
    ]
  })
  core_path3_vm_startup = templatefile("scripts/platform.sh", {
    WEB_PORT     = local.svc_web.port
    CURL_TARGETS = local.core_curl_targets
    PING_TARGETS = local.core_ping_targets
    DNAT_TARGETS = [
      { s = local.venue_supernet, p = "tcp", dport = local.svc_web.port, dnat = local.edge_path3_vm_addr },
      { s = local.edge_supernet, p = "tcp", dport = local.svc_web.port, dnat = local.venue_probe_vm_addr },
    ]
  })
  core_path4_vm_startup = templatefile("scripts/platform.sh", {
    WEB_PORT     = local.svc_web.port
    CURL_TARGETS = local.core_curl_targets
    PING_TARGETS = local.core_ping_targets
    DNAT_TARGETS = [
      { s = local.venue_supernet, p = "tcp", dport = local.svc_web.port, dnat = local.edge_path4_vm_addr },
      { s = local.edge_supernet, p = "tcp", dport = local.svc_web.port, dnat = local.venue_probe_vm_addr },
    ]
  })
  core_curl_targets = [
    "${local.venue_mcast_vm_addr}:${local.svc_web.port}",
    "${local.edge_path1_vm_addr}:${local.svc_web.port}",
    "${local.edge_path2_vm_addr}:${local.svc_web.port}",
    "${local.edge_path3_vm_addr}:${local.svc_web.port}",
    "${local.edge_path4_vm_addr}:${local.svc_web.port}",
  ]
  core_ping_targets = [
    local.venue_mcast_vm_addr,
    local.edge_path1_vm_addr,
    local.edge_path2_vm_addr,
    local.edge_path3_vm_addr,
    local.edge_path4_vm_addr,
  ]
}

# nva
#---------------------------------

locals {
  path2_nva1_startup = templatefile("scripts/nva.sh", {
    WEB_PORT     = local.svc_web.port
    CURL_TARGETS = local.nva_targets
    PING_TARGETS = []
    ENS5_LINKED_PREFIXES = concat(
      [for k, v in local.edge_subnets : v.ip_cidr_range],  # traffic from core > edge
      [for k, v in local.client_subnets : v.ip_cidr_range] # traffic from venue > client
    )
  })
  path2_nva2_startup = templatefile("scripts/nva.sh", {
    WEB_PORT     = local.svc_web.port
    CURL_TARGETS = local.nva_targets
    PING_TARGETS = []
    ENS5_LINKED_PREFIXES = concat(
      [for k, v in local.core_subnets_region1 : v.ip_cidr_range], # traffic from edge > core
      [for k, v in local.core_subnets_region2 : v.ip_cidr_range], # traffic from edge > core
      [for k, v in local.venue_subnets : v.ip_cidr_range]         # traffic from client > venue
    )
  })
  path3_nva1_startup = templatefile("scripts/nva.sh", {
    WEB_PORT     = local.svc_web.port
    CURL_TARGETS = local.nva_targets
    PING_TARGETS = []
    ENS5_LINKED_PREFIXES = concat(
      [for k, v in local.edge_subnets : v.ip_cidr_range],  # traffic from core > edge
      [for k, v in local.client_subnets : v.ip_cidr_range] # traffic from venue > client
    )
  })
  path3_nva2_startup = templatefile("scripts/nva.sh", {
    WEB_PORT     = local.svc_web.port
    CURL_TARGETS = local.nva_targets
    PING_TARGETS = []
    ENS5_LINKED_PREFIXES = concat(
      [for k, v in local.core_subnets_region1 : v.ip_cidr_range], # traffic from edge > core
      [for k, v in local.core_subnets_region2 : v.ip_cidr_range], # traffic from edge > core
      [for k, v in local.venue_subnets : v.ip_cidr_range]         # traffic from client > venue
    )
  })
  nva_targets = [
    "${local.core_path1_vm_addr}:${local.svc_web.port}",
    "${local.core_path2_vm_addr}:${local.svc_web.port}",
    "${local.core_path3_vm_addr}:${local.svc_web.port}",
    "${local.core_path4_vm_addr}:${local.svc_web.port}",
    "${local.edge_path1_vm_addr}:${local.svc_web.port}",
    "${local.edge_path2_vm_addr}:${local.svc_web.port}",
    "${local.edge_path3_vm_addr}:${local.svc_web.port}",
    "${local.edge_path4_vm_addr}:${local.svc_web.port}",
    "${local.venue_mcast_vm_addr}:${local.svc_web.port}",
    "${local.client_mcast_vm_addr}:${local.svc_web.port}",
  ]
}

# edge
#---------------------------------

locals {
  edge_path1_startup = templatefile("scripts/platform.sh", {
    WEB_PORT     = local.svc_web.port
    CURL_TARGETS = local.edge_curl_targets
    PING_TARGETS = local.edge_ping_targets
    DNAT_TARGETS = [
      { s = local.core_supernet, p = "tcp", dport = local.svc_web.port, dnat = local.client_probe_vm_addr },
      { s = local.client_supernet, p = "tcp", dport = local.svc_web.port, dnat = local.core_path1_vm_addr },
    ]
  })
  edge_path2_startup = templatefile("scripts/platform.sh", {
    WEB_PORT     = local.svc_web.port
    CURL_TARGETS = local.edge_curl_targets
    PING_TARGETS = local.edge_ping_targets
    DNAT_TARGETS = [
      { s = local.core_supernet, p = "tcp", dport = local.svc_web.port, dnat = local.client_probe_vm_addr },
      { s = local.client_supernet, p = "tcp", dport = local.svc_web.port, dnat = local.core_path2_vm_addr },
    ]
  })
  edge_path3_startup = templatefile("scripts/platform.sh", {
    WEB_PORT     = local.svc_web.port
    CURL_TARGETS = local.edge_curl_targets
    PING_TARGETS = local.edge_ping_targets
    DNAT_TARGETS = [
      { s = local.core_supernet, p = "tcp", dport = local.svc_web.port, dnat = local.client_probe_vm_addr },
      { s = local.client_supernet, p = "tcp", dport = local.svc_web.port, dnat = local.core_path3_vm_addr },
    ]
  })
  edge_path4_startup = templatefile("scripts/platform.sh", {
    WEB_PORT     = local.svc_web.port
    CURL_TARGETS = local.edge_curl_targets
    PING_TARGETS = local.edge_ping_targets
    DNAT_TARGETS = [
      { s = local.core_supernet, p = "tcp", dport = local.svc_web.port, dnat = local.client_probe_vm_addr },
      { s = local.client_supernet, p = "tcp", dport = local.svc_web.port, dnat = local.core_path4_vm_addr },
    ]
  })
  edge_curl_targets = [
    "${local.client_mcast_vm_addr}:${local.svc_web.port}",
    "${local.core_path1_vm_addr}:${local.svc_web.port}",
    "${local.core_path2_vm_addr}:${local.svc_web.port}",
    "${local.core_path3_vm_addr}:${local.svc_web.port}",
    "${local.core_path4_vm_addr}:${local.svc_web.port}",
  ]
  edge_ping_targets = [
    local.client_mcast_vm_addr,
    local.core_path1_vm_addr,
    local.core_path2_vm_addr,
    local.core_path3_vm_addr,
    local.core_path4_vm_addr,
  ]
}

# client
#---------------------------------

locals {
  client_mcast_startup = templatefile("scripts/mcast.sh", {
    WEB_PORT          = local.svc_web.port
    RVD               = "/opt/tibco/tibrv/8.4/bin/rvd64"
    MCAST_SEND_ADDR   = "239.100.1.1"
    MCAST_LISTEN_ADDR = "239.100.1.1"
    MCAST_PORT        = local.svc_mcast.port
    VXLAN_ADDR        = local.client_vxlan_addr
    VXLAN_MASK        = local.vxlan_mask
    VXLAN_DEV_ADDR    = local.client_mcast_vm_addr
    VXLAN_PEERS       = [local.venue_mcast_vm_addr, ]
    PING_TARGETS      = [local.venue_mcast_vm_addr, local.venue_vxlan_addr, ]
    CURL_TARGETS      = local.client_targets
  })
  client_probe_startup = templatefile("scripts/probe.sh", {
    PROBE_WEB_SERVER_PORT = local.svc_web.port # required if sink is enabled
    CURL_TARGETS          = local.client_targets
    PROBE_TARGETS         = local.client_targets
    PING_TARGETS = [
      local.edge_path1_vm_addr,
      local.edge_path2_vm_addr,
      local.edge_path3_vm_addr,
      local.edge_path4_vm_addr,
    ]
  })
  client_targets = [
    "${local.edge_path1_vm_addr}:${local.svc_web.port}",
    "${local.edge_path2_vm_addr}:${local.svc_web.port}",
    "${local.edge_path3_vm_addr}:${local.svc_web.port}",
    "${local.edge_path4_vm_addr}:${local.svc_web.port}",
  ]
}
