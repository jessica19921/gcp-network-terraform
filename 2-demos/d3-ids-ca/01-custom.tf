
# common
#---------------------------------

locals {
  prefix = ""
  targets_app = [
    "${local.site1_app1_dns}.${local.site1_domain}.${local.onprem_domain}:${local.svc_web.port}",
    "${local.site2_app1_dns}.${local.site2_domain}.${local.onprem_domain}:${local.svc_web.port}",
    "${local.hub_eu_ilb4_dns}.${local.hub_domain}.${local.cloud_domain}:${local.svc_web.port}",
    "${local.hub_us_ilb4_dns}.${local.hub_domain}.${local.cloud_domain}:${local.svc_web.port}",
    "${local.spoke1_eu_ilb4_dns}.${local.spoke1_domain}.${local.cloud_domain}:${local.svc_web.port}",
    "${local.spoke2_us_ilb4_dns}.${local.spoke2_domain}.${local.cloud_domain}:${local.svc_web.port}",
    "${local.spoke1_eu_ilb7_dns}.${local.spoke1_domain}.${local.cloud_domain}",
    "${local.spoke2_us_ilb7_dns}.${local.spoke2_domain}.${local.cloud_domain}",
    "https://${local.hub_eu_ilb7_https_dns}.${local.hub_domain}.${local.cloud_domain}",
    "https://${local.hub_us_ilb7_https_dns}.${local.hub_domain}.${local.cloud_domain}",
  ]
  targets_pga = [
    "www.googleapis.com/generate_204",
    "storage.googleapis.com/generate_204",
    "https://${local.spoke1_eu_psc_https_ctrl_dns}/generate_204",    # custom psc ilb7 access to regional service
    "https://${local.spoke2_us_psc_https_ctrl_dns}/generate_204",    # custom psc ilb7 access to regional service
    "${local.hub_host_run}/",                                        # cloud run in hub project
    "${local.spoke1_host_run}/",                                     # cloud run in spoke1 project
    "${local.spoke2_host_run}/",                                     # cloud run in spoke1 project
    "${local.hub_psc_api_fr_name}.p.googleapis.com/generate_204",    # psc/api endpoint in hub project
    "${local.spoke1_psc_api_fr_name}.p.googleapis.com/generate_204", # psc/api endpoint in spoke1 project
    "${local.spoke2_psc_api_fr_name}.p.googleapis.com/generate_204"  # psc/api endpoint in spoke2 project
  ]
}
