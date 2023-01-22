
# common
#---------------------------------

# public dns zone

data "google_dns_managed_zone" "public_zone" {
  project = var.project_id_hub
  name    = "global-public-cloudtuple"
}

# on-premises
#---------------------------------

# unbound config

locals {
  onprem_local_records = [
    { name = ("${local.site2_app1_dns}.${local.site2_domain}.${local.onprem_domain}"), record = local.site2_app1_addr },
  ]
  onprem_redirected_hosts = [
    {
      hosts = ["storage.googleapis.com", "bigquery.googleapis.com", "run.app"]
      class = "IN", ttl = "3600", type = "A", record = local.hub_psc_api_all_fr_addr
    },
    { hosts = [local.hub_us_psc_https_ctrl_dns], class = "IN", ttl = "3600", type = "A", record = local.hub_us_ilb7_https_addr },
    { hosts = [local.spoke2_us_psc_https_ctrl_dns], class = "IN", ttl = "3600", type = "A", record = local.spoke2_us_ilb7_https_addr },
  ]
  onprem_forward_zones = [
    { zone = "gcp.", targets = [local.hub_us_ns_addr] },
    { zone = "${local.hub_psc_api_fr_name}.p.googleapis.com", targets = [local.hub_us_ns_addr] },
    { zone = ".", targets = ["8.8.8.8", "8.8.4.4"] },
  ]
}

# site2
#---------------------------------

# unbound config

locals {
  site2_unbound_config = templatefile("scripts/startup/unbound/site.sh", {
    ONPREM_LOCAL_RECORDS = local.onprem_local_records
    REDIRECTED_HOSTS     = local.onprem_redirected_hosts
    FORWARD_ZONES        = local.onprem_forward_zones
  })
}

# addresses

resource "google_compute_address" "site2_router" {
  project = var.project_id_onprem
  name    = "${local.site2_prefix}router"
  region  = local.site2_region
}

# service account

module "site2_sa" {
  source       = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/iam-service-account"
  project_id   = var.project_id_onprem
  name         = trimsuffix("${local.site2_prefix}sa", "-")
  generate_key = false
  iam_project_roles = {
    (var.project_id_onprem) = ["roles/owner", ]
    (var.project_id_hub)    = ["roles/trafficdirector.client", ]
    (var.project_id_spoke2) = ["roles/trafficdirector.client", ]
  }
}

# hub
#---------------------------------

data "google_project" "hub_project_number" {
  project_id = var.project_id_hub
}

locals {
  hub_unbound_config = templatefile("scripts/startup/unbound/cloud.sh", {
    FORWARD_ZONES = local.cloud_forward_zones
  })
  cloud_forward_zones = [
    { zone = "onprem.", targets = [local.site2_ns_addr] },
    { zone = ".", targets = ["169.254.169.254"] },
  ]
  hub_psc_api_fr_name = (
    local.hub_psc_api_secure ?
    local.hub_psc_api_sec_fr_name :
    local.hub_psc_api_all_fr_name
  )
  hub_psc_api_fr_addr = (
    local.hub_psc_api_secure ?
    local.hub_psc_api_sec_fr_addr :
    local.hub_psc_api_all_fr_addr
  )
  hub_psc_api_fr_target = (
    local.hub_psc_api_secure ?
    "vpc-sc" :
    "all-apis"
  )
  hub_psc_api_secure = false
}

# addresses

resource "google_compute_address" "hub_us_router" {
  project = var.project_id_hub
  name    = "${local.hub_prefix}us-router"
  region  = local.hub_us_region
}

# service account

module "hub_sa" {
  source            = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/iam-service-account"
  project_id        = var.project_id_hub
  name              = trimsuffix("${local.hub_prefix}sa", "-")
  generate_key      = false
  iam_project_roles = { (var.project_id_hub) = ["roles/owner", ] }
}

# storage

module "hub_us_storage_bucket" {
  source        = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/gcs"
  project_id    = var.project_id_hub
  prefix        = ""
  name          = "${local.prefix}-${var.project_id_hub}-us"
  location      = local.hub_us_region
  storage_class = "STANDARD"
  iam = {
    "roles/storage.objectViewer" = [
      "serviceAccount:${module.site2_sa.email}",
      "serviceAccount:${module.hub_sa.email}",
      "serviceAccount:${module.spoke2_sa.email}",
    ]
  }
}

resource "google_storage_bucket_object" "hub_us_file" {
  name    = "${local.hub_prefix}object.txt"
  bucket  = module.hub_us_storage_bucket.name
  content = "<--- HUB US --->"
}

# host
#---------------------------------

data "google_project" "host_project_number" {
  project_id = var.project_id_host
}

# spoke1
#---------------------------------

data "google_project" "spoke1_project_number" {
  project_id = var.project_id_spoke1
}

locals {
  spoke1_psc_api_fr_name = (
    local.spoke1_psc_api_secure ?
    local.spoke1_psc_api_sec_fr_name :
    local.spoke1_psc_api_all_fr_name
  )
  spoke1_psc_api_fr_addr = (
    local.spoke1_psc_api_secure ?
    local.spoke1_psc_api_sec_fr_addr :
    local.spoke1_psc_api_all_fr_addr
  )
  spoke1_psc_api_fr_target = (
    local.spoke1_psc_api_secure ?
    "vpc-sc" :
    "all-apis"
  )
  spoke1_psc_api_secure = true
}

# service account

module "spoke1_sa" {
  source       = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/iam-service-account"
  project_id   = var.project_id_spoke1
  name         = trimsuffix("${local.spoke1_prefix}sa", "-")
  generate_key = false
  iam_project_roles = {
    (var.project_id_spoke1) = ["roles/owner", ]
  }
}

# storage

module "spoke1_eu_storage_bucket" {
  source        = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/gcs"
  project_id    = var.project_id_spoke1
  prefix        = ""
  name          = "${local.prefix}-${var.project_id_spoke1}-eu"
  location      = local.spoke1_eu_region
  storage_class = "STANDARD"
  iam = {
    "roles/storage.objectViewer" = [
      "serviceAccount:${module.site2_sa.email}",
      "serviceAccount:${module.hub_sa.email}",
      "serviceAccount:${module.spoke1_sa.email}",
    ]
  }
}

resource "google_storage_bucket_object" "spoke1_file" {
  name    = "${local.spoke1_prefix}object.txt"
  bucket  = module.spoke1_eu_storage_bucket.name
  content = "<--- SPOKE1 EU --->"
}

# spoke2
#---------------------------------

data "google_project" "spoke2_project_number" {
  project_id = var.project_id_spoke2
}

locals {
  spoke2_psc_api_fr_name = (
    local.spoke2_psc_api_secure ?
    local.spoke2_psc_api_sec_fr_name :
    local.spoke2_psc_api_all_fr_name
  )
  spoke2_psc_api_fr_addr = (
    local.spoke2_psc_api_secure ?
    local.spoke2_psc_api_sec_fr_addr :
    local.spoke2_psc_api_all_fr_addr
  )
  spoke2_psc_api_fr_target = (
    local.spoke2_psc_api_secure ?
    "vpc-sc" :
    "all-apis"
  )
  spoke2_psc_api_secure = true
}

# service account

module "spoke2_sa" {
  source       = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/iam-service-account"
  project_id   = var.project_id_spoke2
  name         = trimsuffix("${local.spoke2_prefix}sa", "-")
  generate_key = false
  iam_project_roles = {
    (var.project_id_spoke2) = ["roles/owner", ]
  }
}

# storage

module "spoke2_us_storage_bucket" {
  source        = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/gcs"
  project_id    = var.project_id_spoke2
  prefix        = ""
  name          = "${local.prefix}-${var.project_id_spoke2}-us"
  location      = local.spoke2_us_region
  storage_class = "STANDARD"
  iam = {
    "roles/storage.objectViewer" = [
      "serviceAccount:${module.site2_sa.email}",
      "serviceAccount:${module.hub_sa.email}",
      "serviceAccount:${module.spoke2_sa.email}",
    ]
  }
}

resource "google_storage_bucket_object" "spoke2_file" {
  name    = "${local.spoke2_prefix}object.txt"
  bucket  = module.spoke2_us_storage_bucket.name
  content = "<--- SPOKE2 US --->"
}
