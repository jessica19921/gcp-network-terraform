
# netblocks

data "google_netblock_ip_ranges" "dns_forwarders" { range_type = "dns-forwarders" }
data "google_netblock_ip_ranges" "private_googleapis" { range_type = "private-googleapis" }
data "google_netblock_ip_ranges" "restricted_googleapis" { range_type = "restricted-googleapis" }
data "google_netblock_ip_ranges" "health_checkers" { range_type = "health-checkers" }
data "google_netblock_ip_ranges" "iap_forwarders" { range_type = "iap-forwarders" }

# common
#=====================================================

locals {
  supernet     = "10.0.0.0/8"
  cloud_domain = "gcp"
  psk          = "changeme"
  tag_router   = "router"
  tag_gfe      = "gfe"
  tag_dns      = "dns"
  tag_ssh      = "ssh"
  tag_http     = "http-server"
  tag_https    = "https-server"
  netblocks = {
    dns      = data.google_netblock_ip_ranges.dns_forwarders.cidr_blocks_ipv4
    gfe      = data.google_netblock_ip_ranges.health_checkers.cidr_blocks_ipv4
    iap      = data.google_netblock_ip_ranges.iap_forwarders.cidr_blocks_ipv4
    internal = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  }
  uhc_config = {
    host         = "probe.${local.cloud_domain}"
    request_path = "healthz"
    response     = "pass"
  }
  svc_juice = {
    name = "http3000"
    port = 3000
  }
}

resource "random_id" "random" {
  byte_length = 2
}

# hub
#=====================================================

locals {
  hub_prefix    = local.prefix == "" ? "" : join("-", [local.prefix, ""])
  hub_eu_region = "europe-west2"
  hub_us_region = "us-east1"
  hub_supernet  = "10.1.0.0/16"
  hub_subnets = {
    ("${local.hub_prefix}eu-subnet1") = {
      region                     = local.hub_eu_region
      ip_cidr_range              = "10.1.11.0/24"
      secondary_ip_range         = null
      subnet_flow_logs           = false
      log_config                 = null
      private_google_access      = true
      private_ipv6_google_access = false
      purpose                    = "PRIVATE"
      role                       = null
    }
    ("${local.hub_prefix}us-subnet1") = {
      region                     = local.hub_us_region
      ip_cidr_range              = "10.1.21.0/24"
      secondary_ip_range         = null
      subnet_flow_logs           = false
      log_config                 = null
      private_google_access      = true
      private_ipv6_google_access = false
      purpose                    = "PRIVATE"
      role                       = null
    }
  }
}
