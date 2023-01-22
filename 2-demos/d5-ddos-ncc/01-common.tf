

# data

data "google_dns_managed_zone" "public_zone" {
  project = var.project_id_dns
  name    = "global-public-cloudtuple"
}

# common
#---------------------------------

data "google_project" "hub_project_number" {
  project_id = var.project_id_hub
}

# common
#----------------------------------------------------

locals {
  prefix            = "demo"
  hub_host_secure   = trimsuffix("secure.${data.google_dns_managed_zone.public_zone.dns_name}", ".")
  hub_host_insecure = trimsuffix("insecure.${data.google_dns_managed_zone.public_zone.dns_name}", ".")
  hub_host_nlb      = "network.${data.google_dns_managed_zone.public_zone.dns_name}"
  hub_domains = [
    "secure.${data.google_dns_managed_zone.public_zone.dns_name}",
    "insecure.${data.google_dns_managed_zone.public_zone.dns_name}"
  ]
  hub_ssl_cert_domains = [for x in local.hub_domains : trimsuffix(x, ".")]
}

# service account

module "hub_sa" {
  source            = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/iam-service-account"
  project_id        = var.project_id_hub
  name              = trimsuffix("${local.hub_prefix}sa", "-")
  generate_key      = false
  iam_project_roles = { (var.project_id_hub) = ["roles/owner", ] }
}

# addresses
#----------------------------------------------------

# local address

data "external" "case1_external_ip" {
  program = ["sh", "scripts/general/external-ipv4.sh"]
}

# gclb

resource "google_compute_global_address" "hub_gclb_frontend" {
  project = var.project_id_hub
  name    = "${local.hub_prefix}gclb-frontend"
}

# nlb

resource "google_compute_address" "hub_us_nlb_frontend" {
  project = var.project_id_hub
  name    = "${local.hub_prefix}us-nlb-frontend"
  region  = local.hub_us_region
}
