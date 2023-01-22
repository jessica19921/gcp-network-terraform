
# common
#---------------------------------

locals {
  prefix = "d2"
  targets_pga = [
    "www.googleapis.com/generate_204",
    "storage.googleapis.com/generate_204",
    "https://${local.spoke2_us_psc_https_ctrl_dns}/generate_204",   # custom psc ilb7 access to regional service
    "${local.hub_psc_api_fr_name}.p.googleapis.com/generate_204",   # psc/api endpoint in hub project
    "${local.spoke2_psc_api_fr_name}.p.googleapis.com/generate_204" # psc/api endpoint in spoke2 project
  ]
}
