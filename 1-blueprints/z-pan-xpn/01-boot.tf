
# common
#---------------------------------

# public dns zone

data "google_dns_managed_zone" "public_zone" {
  project = var.project_id_hub
  name    = "global-public-cloudtuple"
}

# panos ssh

locals {
  private_key_path = pathexpand("~/.ssh/panos${local.prefix}")
  public_key_path  = pathexpand("~/.ssh/panos${local.prefix}.pub")
}

resource "tls_private_key" "panos" {
  algorithm = "RSA"
}

resource "local_file" "panos_private_key" {
  content  = tls_private_key.panos.private_key_pem
  filename = local.private_key_path
}

resource "local_file" "panos_public_key" {
  content  = tls_private_key.panos.public_key_openssh
  filename = local.public_key_path
}

resource "null_resource" "panos_key_permission" {
  depends_on = [local_file.panos_private_key]
  provisioner "local-exec" {
    command = "chmod 400 ${local.private_key_path}"
  }
}

locals {
  prefix          = "f"
  hub_host_run    = module.hub_eu_cloud_run.url
  spoke1_host_run = module.spoke1_eu_cloud_run.url
  spoke2_host_run = module.spoke2_eu_cloud_run.url
  vm_lite_startup = templatefile("scripts/startup/vm_lite.sh", {
    port                  = local.svc_web.port
    health_check_path     = local.uhc_config.request_path
    health_check_response = local.uhc_config.response
  })
  vm_startup = templatefile("scripts/startup/vm.sh", {
    CURL_SCRIPTS = {
      enable      = true
      targets_app = local.targets_app
      targets_psc = local.targets_psc
      targets_pga = local.targets_pga
      targets_td  = local.targets_td
    }
    PING_SCRIPTS = {
      enable  = true
      targets = local.targets_ping
    }
    GCS_SCRIPTS = {
      enable = true
      buckets = {
        ("spoke1") = local.spoke1_gcs_bucket
        ("spoke2") = local.spoke2_gcs_bucket
      }
    }
    WEB_SERVER = {
      enable                = true
      port                  = local.svc_web.port
      health_check_path     = local.uhc_config.request_path
      health_check_response = local.uhc_config.response
    }
    GRPC_SERVER = {
      enable = true
    }
  })
  td_client_startup = templatefile("scripts/startup/client.sh", {
    TD_PROJECT_NUMBER = data.google_project.hub_project_number.number
    TD_NETWORK_NAME   = google_compute_network.hub_int_vpc.name
    TARGETS_GRPC      = local.targets_grpc
    TARGETS_ENVOY     = local.targets_td
  })
  targets_app = [
    "${local.site1_app1_dns}.${local.site1_domain}.${local.onprem_domain}:${local.svc_web.port}",
    "${local.site2_app1_dns}.${local.site2_domain}.${local.onprem_domain}:${local.svc_web.port}",
    "${local.hub_mgt_eu_app1_dns}.${local.hub_domain}.${local.cloud_domain}:${local.svc_web.port}",
    "${local.hub_mgt_us_app1_dns}.${local.hub_domain}.${local.cloud_domain}:${local.svc_web.port}",
    "${local.spoke1_eu_ilb4_dns}.${local.spoke1_domain}.${local.cloud_domain}:${local.svc_web.port}",
    "${local.spoke2_us_ilb4_dns}.${local.spoke2_domain}.${local.cloud_domain}:${local.svc_web.port}",
    "${local.spoke1_eu_ilb7_dns}.${local.spoke1_domain}.${local.cloud_domain}:${local.svc_web.port}",
    "${local.spoke2_us_ilb7_dns}.${local.spoke2_domain}.${local.cloud_domain}:${local.svc_web.port}",
    "${local.hub_ext_eu_nva_ilb4_addr}:${local.hub_svc_8001.port}",
    "${local.hub_ext_eu_nva_ilb4_addr}:${local.hub_svc_8002.port}",
    "${local.hub_ext_us_nva_ilb4_addr}:${local.hub_svc_8001.port}",
    "${local.hub_ext_us_nva_ilb4_addr}:${local.hub_svc_8002.port}",
  ]
  targets_ping = [
    local.site1_router_addr,
    local.site2_router_addr,
    local.hub_ext_eu_router_addr,
    local.hub_ext_us_router_addr,
    local.site1_app1_addr,
    local.site2_app1_addr,
    local.hub_ext_eu_app1_addr,
    local.hub_ext_us_app1_addr,
  ]
  targets_psc = [
    "${local.spoke2_eu_psc_spoke1_dns}.${local.spoke2_psc_domain}:${local.svc_web.port}",
    "${local.hub_ext_eu_psc_spoke1_dns}.${local.hub_psc_domain}:${local.svc_web.port}",
  ]
  targets_pga = [
    "www.googleapis.com/generate_204",
    "storage.googleapis.com/generate_204",
    "https://${local.spoke2_psc_api_ilb7_svc}.${local.spoke2_psc_domain}/generate_204", # custom psc ilb7 access to regional googleapi service
    local.hub_host_run,                                                                 # cloud run in hub project
    local.spoke1_host_run,                                                              # cloud run in spoke1 project
    local.spoke2_host_run,                                                              # cloud run in spoke1 project
    "${local.hub_ext_psc_api_fr_name}.p.googleapis.com/generate_204",                   # psc/api endpoint in hub project
    "${local.spoke1_psc_api_fr_name}.p.googleapis.com/generate_204",                    # psc/api endpoint in spoke1 project
    "${local.spoke2_psc_api_fr_name}.p.googleapis.com/generate_204"                     # psc/api endpoint in spoke2 project
  ]
  targets_td = [
    "${local.spoke2_td_envoy_bridge_ilb4_dns}.${local.spoke2_domain}.${local.cloud_domain}:${local.svc_web.port}",
    "${local.spoke2_td_envoy_cloud_svc}.${local.spoke2_td_domain}:${local.svc_web.port}",
    "${local.spoke2_td_envoy_hybrid_svc}.${local.spoke2_td_domain}:${local.svc_web.port}",
  ]
  targets_grpc = [
    "${local.spoke2_td_grpc_cloud_svc}.${local.spoke2_td_domain}"
  ]
  sql_access_via_local_host = [
    {
      script_name = "sql_local_eu"
      project     = var.project_id_spoke1
      region      = local.spoke1_eu_region
      instance    = local.spoke1_eu_cloudsql_name
      port        = 3306
      user        = "admin"
      password    = local.spoke1_cloudsql_users.admin.password
    },
    {
      script_name = "sql_local_us"
      project     = var.project_id_spoke1
      region      = local.spoke1_us_region
      instance    = local.spoke1_us_cloudsql_name
      port        = 3306
      user        = "admin"
      password    = local.spoke1_cloudsql_users.admin.password
    },
  ]
  sql_access_via_proxy = [
    {
      script_name  = "sql_proxy_eu"
      sql_proxy_ip = local.spoke1_eu_sql_proxy_addr
      port         = 3306
      user         = "admin"
      password     = local.spoke1_cloudsql_users.admin.password
    },
    {
      script_name  = "sql_proxy_us"
      sql_proxy_ip = local.spoke1_us_sql_proxy_addr
      port         = 3306
      user         = "admin"
      password     = local.spoke1_cloudsql_users.admin.password
    },
  ]
}

# on-premises
#---------------------------------

# unbound config

locals {
  onprem_local_records = [
    { name = ("${local.site1_app1_dns}.${local.site1_domain}.${local.onprem_domain}"), record = local.site1_app1_addr },
    { name = ("${local.site2_app1_dns}.${local.site2_domain}.${local.onprem_domain}"), record = local.site2_app1_addr },
  ]
  onprem_redirected_hosts = [
    {
      hosts  = ["storage.googleapis.com", "bigquery.googleapis.com", "run.app"]
      class  = "IN", ttl = "3600", type = "CNAME"
      record = "${local.hub_ext_psc_api_fr_name}.p.googleapis.com"
    },
  ]
  onprem_forward_zones = [
    { zone = "gcp.", targets = [local.hub_ext_eu_ns_addr, local.hub_ext_us_ns_addr] },
    { zone = "${local.hub_ext_psc_api_fr_name}.p.googleapis.com", targets = [local.hub_ext_eu_ns_addr, local.hub_ext_us_ns_addr] },
    { zone = ".", targets = ["8.8.8.8", "8.8.4.4"] },
  ]
  cloud_forward_zones = [
    { zone = "onprem.", targets = [local.site1_ns_addr, local.site2_ns_addr] },
    { zone = ".", targets = ["169.254.169.254"] },
  ]
}

# site1
#---------------------------------

# unbound config

locals {
  site1_unbound_config = templatefile("scripts/startup/unbound/site.sh", {
    ONPREM_LOCAL_RECORDS = local.onprem_local_records
    REDIRECTED_HOSTS     = local.onprem_redirected_hosts
    CLOUD_PSC_HOST       = "${local.hub_ext_psc_api_fr_name}.p.googleapis.com"
    CLOUD_PSC_ADDR       = local.hub_ext_psc_api_fr_addr
    FORWARD_ZONES        = local.onprem_forward_zones
  })
}

# service account

module "site1_sa" {
  source       = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/iam-service-account"
  project_id   = var.project_id_onprem
  name         = trimsuffix(local.site1_prefix, "-")
  generate_key = false
  iam_project_roles = {
    (var.project_id_onprem) = ["roles/owner", ]
    (var.project_id_hub)    = ["roles/trafficdirector.client", ]
    (var.project_id_spoke1) = ["roles/trafficdirector.client", ]
    (var.project_id_spoke2) = ["roles/trafficdirector.client", ]
  }
}

# site2
#---------------------------------

# unbound config

locals {
  site2_unbound_config = templatefile("scripts/startup/unbound/site.sh", {
    ONPREM_LOCAL_RECORDS = local.onprem_local_records
    REDIRECTED_HOSTS     = local.onprem_redirected_hosts
    CLOUD_PSC_HOST       = "${local.hub_ext_psc_api_fr_name}.p.googleapis.com"
    CLOUD_PSC_ADDR       = local.hub_ext_psc_api_fr_addr
    FORWARD_ZONES        = local.onprem_forward_zones
  })
}

# service account

module "site2_sa" {
  source       = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/iam-service-account"
  project_id   = var.project_id_onprem
  name         = trimsuffix(local.site2_prefix, "-")
  generate_key = false
  iam_project_roles = {
    (var.project_id_onprem) = ["roles/owner", ]
    (var.project_id_hub)    = ["roles/trafficdirector.client", ]
    (var.project_id_spoke1) = ["roles/trafficdirector.client", ]
    (var.project_id_spoke2) = ["roles/trafficdirector.client", ]
  }
}

# hub
#---------------------------------

data "google_project" "hub_project_number" {
  project_id = var.project_id_hub
}

locals {
  hub_ext_unbound_config = templatefile("scripts/startup/unbound/cloud.sh", {
    FORWARD_ZONES = local.cloud_forward_zones
  })
  hub_ext_psc_api_fr_name = (
    local.hub_ext_psc_api_secure ?
    local.hub_ext_psc_api_sec_fr_name :
    local.hub_ext_psc_api_all_fr_name
  )
  hub_mgt_psc_api_fr_name = (
    local.hub_mgt_psc_api_secure ?
    local.hub_mgt_psc_api_sec_fr_name :
    local.hub_mgt_psc_api_all_fr_name
  )
  hub_int_psc_api_fr_name = (
    local.hub_int_psc_api_secure ?
    local.hub_int_psc_api_sec_fr_name :
    local.hub_int_psc_api_all_fr_name
  )
  hub_ext_psc_api_fr_addr = (
    local.hub_ext_psc_api_secure ?
    local.hub_ext_psc_api_sec_fr_addr :
    local.hub_ext_psc_api_all_fr_addr
  )
  hub_mgt_psc_api_fr_addr = (
    local.hub_mgt_psc_api_secure ?
    local.hub_mgt_psc_api_sec_fr_addr :
    local.hub_mgt_psc_api_all_fr_addr
  )
  hub_int_psc_api_fr_addr = (
    local.hub_int_psc_api_secure ?
    local.hub_int_psc_api_sec_fr_addr :
    local.hub_int_psc_api_all_fr_addr
  )
  hub_ext_psc_api_fr_target = (
    local.hub_ext_psc_api_secure ?
    "vpc-sc" :
    "all-apis"
  )
  hub_mgt_psc_api_fr_target = (
    local.hub_mgt_psc_api_secure ?
    "vpc-sc" :
    "all-apis"
  )
  hub_int_psc_api_fr_target = (
    local.hub_int_psc_api_secure ?
    "vpc-sc" :
    "all-apis"
  )
  hub_ext_psc_api_secure = false
  hub_mgt_psc_api_secure = false
  hub_int_psc_api_secure = false

  # nva startup scripts
  hub_nva_eu_startup = templatefile("scripts/startup/nva.sh", {
    GFE_RANGES           = local.netblocks.gfe
    ENS5_LINKED_NETWORKS = [local.spoke1_supernet]
    ENS6_LINKED_NETWORKS = [local.hub_mgt_us_subnet1.ip_cidr_range] # eu subnet is directly attached and not included
    GCLB_IPTABLE_RULES = [
      { protocol = "tcp", dst_port = local.hub_svc_8001.port, dnat_ip = local.spoke1_eu_ilb4_addr, dnat_port = local.svc_web.port },
      { protocol = "tcp", dst_port = local.hub_svc_8002.port, dnat_ip = local.spoke1_eu_ilb4_addr, dnat_port = local.svc_web.port },
    ]
    HEALTH_CHECK = {
      port     = local.svc_web.port
      path     = local.uhc_config.request_path
      response = local.uhc_config.response
    }
    TARGETS_APP = local.targets_app
    TARGETS_PSC = local.targets_psc
    TARGETS_PGA = local.targets_pga
  })
  hub_nva_us_startup = templatefile("scripts/startup/nva.sh", {
    GFE_RANGES           = local.netblocks.gfe
    ENS5_LINKED_NETWORKS = [local.spoke2_supernet]
    ENS6_LINKED_NETWORKS = [local.hub_mgt_eu_subnet1.ip_cidr_range] # us subnet is directly attached and not included
    GCLB_IPTABLE_RULES = [
      { protocol = "tcp", dst_port = local.hub_svc_8001.port, dnat_ip = local.spoke2_us_ilb4_addr, dnat_port = local.svc_web.port },
      { protocol = "tcp", dst_port = local.hub_svc_8002.port, dnat_ip = local.spoke2_us_ilb4_addr, dnat_port = local.svc_web.port },
    ]
    HEALTH_CHECK = {
      port     = local.svc_web.port
      path     = local.uhc_config.request_path
      response = local.uhc_config.response
    }
    TARGETS_APP = local.targets_app
    TARGETS_PSC = local.targets_psc
    TARGETS_PGA = local.targets_pga
  })
}

# hub2

locals {
  hub2_psc_api_fr_name = (
    local.hub2_psc_api_secure ?
    local.hub2_psc_api_sec_fr_name :
    local.hub2_psc_api_all_fr_name
  )
  hub2_psc_api_fr_addr = (
    local.hub2_psc_api_secure ?
    local.hub2_psc_api_sec_fr_addr :
    local.hub2_psc_api_all_fr_addr
  )
  hub2_psc_api_fr_target = (
    local.hub2_psc_api_secure ?
    "vpc-sc" :
    "all-apis"
  )
  hub2_psc_api_secure = false
}

# service account

module "hub_sa" {
  source       = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/iam-service-account"
  project_id   = var.project_id_hub
  name         = trimsuffix("${local.hub_prefix}-sa", "-")
  generate_key = false
  iam_project_roles = {
    (var.project_id_hub) = ["roles/owner", ]
  }
}

# cloud run

locals {
  hub_run_gcr_host = "gcr.io"
}

module "hub_eu_cloud_run" {
  source     = "../../modules/cloud-run"
  project_id = var.project_id_hub
  name       = "${local.hub_prefix}run-flasky"
  region     = local.hub_eu_region
  image = {
    repo           = "${local.hub_run_gcr_host}/${var.project_id_hub}/flasky:v1"
    gcr_host       = local.hub_run_gcr_host
    dockerfile     = "templates/run/flasky"
    container_port = 8080
  }
}

# spoke1
#---------------------------------

data "google_project" "spoke1_roject_number" {
  project_id = var.project_id_spoke1
}

locals {
  spoke1_gcs_bucket = "${local.prefix}-${var.project_id_spoke1}"
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
  source            = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/iam-service-account"
  project_id        = var.project_id_spoke1
  name              = trimsuffix(local.spoke1_prefix, "-")
  generate_key      = false
  iam_project_roles = { (var.project_id_spoke1) = ["roles/owner", ] }
}

# cloud run

locals {
  spoke1_run_gcr_host = "gcr.io"
}

module "spoke1_eu_cloud_run" {
  source     = "../../modules/cloud-run"
  project_id = var.project_id_spoke1
  name       = "${local.spoke1_prefix}run-flasky"
  region     = local.spoke1_eu_region
  image = {
    repo           = "${local.spoke1_run_gcr_host}/${var.project_id_spoke1}/flasky:v1"
    gcr_host       = local.spoke1_run_gcr_host
    dockerfile     = "templates/run/flasky"
    container_port = 8080
  }
}

# spoke2
#---------------------------------

data "google_project" "spoke2_project_number" {
  project_id = var.project_id_spoke2
}

locals {
  spoke2_gcs_bucket = "${local.prefix}-${var.project_id_spoke2}"
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
  source            = "github.com/terraform-google-modules/cloud-foundation-fabric//modules/iam-service-account"
  project_id        = var.project_id_spoke2
  name              = trimsuffix(local.spoke2_prefix, "-")
  generate_key      = false
  iam_project_roles = { (var.project_id_spoke2) = ["roles/owner", ] }
}

# cloud run

locals {
  spoke2_run_gcr_host = "gcr.io"
}

module "spoke2_eu_cloud_run" {
  source     = "../../modules/cloud-run"
  project_id = var.project_id_spoke2
  name       = "${local.spoke2_prefix}run-flasky"
  region     = local.spoke2_eu_region
  image = {
    repo           = "${local.spoke2_run_gcr_host}/${var.project_id_spoke2}/flasky:v1"
    gcr_host       = local.spoke2_run_gcr_host
    dockerfile     = "templates/run/flasky"
    container_port = 8080
  }
}
