
# common
#---------------------------------

locals {
  vm_startup = templatefile("scripts/startup/gce.sh", {
    ENABLE_PROBES = true
    SCRIPTS = {
      targets_app        = []
      targets_ping       = []
      targets_pga        = []
      targets_psc        = []
      targets_probe      = []
      targets_bucket     = {}
      targets_ai_project = []
    }
    WEB_SERVER = {
      port                  = local.svc_web.port
      health_check_path     = local.uhc_config.request_path
      health_check_response = local.uhc_config.response
    }
  })
}

# site1
#---------------------------------

# addresses

resource "google_compute_address" "site1_router" {
  project = var.project_id_onprem
  name    = "${local.site1_prefix}router"
  region  = local.site1_region
}

# service account

module "site1_sa" {
  source       = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/iam-service-account"
  project_id   = var.project_id_onprem
  name         = trimsuffix("${local.site1_prefix}sa", "-")
  generate_key = false
  iam_project_roles = {
    (var.project_id_onprem) = ["roles/owner", ]
    (var.project_id_hub)    = ["roles/owner", ]
    (var.project_id_spoke1) = ["roles/owner", ]
    (var.project_id_spoke2) = ["roles/owner", ]
  }
}

# site2
#---------------------------------

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
    (var.project_id_hub)    = ["roles/owner", ]
    (var.project_id_spoke1) = ["roles/owner", ]
    (var.project_id_spoke2) = ["roles/owner", ]
  }
}

# hub
#---------------------------------

data "google_project" "hub_project_number" {
  project_id = var.project_id_hub
}

# addresses

resource "google_compute_address" "hub_eu_router" {
  project = var.project_id_hub
  name    = "${local.hub_prefix}eu-router"
  region  = local.hub_eu_region
}

resource "google_compute_address" "hub_us_router" {
  project = var.project_id_hub
  name    = "${local.hub_prefix}us-router"
  region  = local.hub_us_region
}

# service account

module "hub_sa" {
  source       = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/iam-service-account"
  project_id   = var.project_id_hub
  name         = trimsuffix("${local.hub_prefix}sa", "-")
  generate_key = false
  iam_project_roles = {
    (var.project_id_onprem) = ["roles/owner", ]
    (var.project_id_hub)    = ["roles/owner", ]
    (var.project_id_spoke1) = ["roles/owner", ]
    (var.project_id_spoke2) = ["roles/owner", ]
  }
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

# service account

module "spoke1_sa" {
  source       = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/iam-service-account"
  project_id   = var.project_id_spoke1
  name         = trimsuffix("${local.spoke1_prefix}sa", "-")
  generate_key = false
  iam_project_roles = {
    (var.project_id_onprem) = ["roles/owner", ]
    (var.project_id_hub)    = ["roles/owner", ]
    (var.project_id_spoke1) = ["roles/owner", ]
    (var.project_id_spoke2) = ["roles/owner", ]
  }
}

# spoke2
#---------------------------------

data "google_project" "spoke2_project_number" {
  project_id = var.project_id_spoke2
}

# service account

module "spoke2_sa" {
  source       = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/iam-service-account"
  project_id   = var.project_id_spoke2
  name         = trimsuffix("${local.spoke2_prefix}sa", "-")
  generate_key = false
  iam_project_roles = {
    (var.project_id_onprem) = ["roles/owner", ]
    (var.project_id_hub)    = ["roles/owner", ]
    (var.project_id_spoke1) = ["roles/owner", ]
    (var.project_id_spoke2) = ["roles/owner", ]
  }
}
