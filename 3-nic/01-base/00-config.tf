
# Configuration parameters and values

# Common
#---------------------------------------------

provider "google" {
  project = var.project_id_main
}

provider "google-beta" {
  project = var.project_id_main
}

data "google_netblock_ip_ranges" "private_googleapis" { range_type = "private-googleapis" }
data "google_netblock_ip_ranges" "health_checkers" { range_type = "health-checkers" }
data "google_netblock_ip_ranges" "iap_forwarders" { range_type = "iap-forwarders" }

locals {
  supernet   = "10.0.0.0/8"
  psk        = "changeme"
  tags       = { gfe = "gfe", ssh = "ssh", http = "http" }
  named_port = { name = "http80", port = 80 }
  netblocks = {
    private_googleapis = data.google_netblock_ip_ranges.private_googleapis.cidr_blocks_ipv4
    health_check       = data.google_netblock_ip_ranges.health_checkers.cidr_blocks_ipv4
    iap                = data.google_netblock_ip_ranges.iap_forwarders.cidr_blocks_ipv4
    internal           = [local.supernet]
  }
  eu_region1 = "europe-west2"
  eu_region2 = "europe-west3"
  eu_region3 = "europe-west4"

  us_region1 = "us-east1"
  us_region2 = "us-east4"
  us_region3 = "us-central1"
  us_region4 = "us-west1"
  us_region5 = "us-west2"
  us_region6 = "us-west3"

  ap_region1 = "asia-east1"
  ap_region2 = "asia-east2"
  ap_region3 = "asia-southeast1"
}
