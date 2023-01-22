
# policy
#----------------------------------------------------

locals {
  hub_ca_nlb_policy_create = templatefile("scripts/armor/network/policy/create.sh", {
    PROJECT_ID  = var.project_id_hub
    POLICY_NAME = "${local.hub_prefix}ca-nlb-policy"
    REGION      = local.hub_us_region
  })
  hub_ca_nlb_policy_delete = templatefile("scripts/armor/network/policy/delete.sh", {
    PROJECT_ID  = var.project_id_hub
    POLICY_NAME = "${local.hub_prefix}ca-nlb-policy"
    REGION      = local.hub_us_region
  })
}

resource "null_resource" "hub_us_nlb_policy" {
  triggers = {
    create = local.hub_ca_nlb_policy_create
    delete = local.hub_ca_nlb_policy_delete
  }
  provisioner "local-exec" {
    command = self.triggers.create
  }
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete
  }
}

# service
#----------------------------------------------------

locals {
  hub_ca_nlb_service_create = templatefile("scripts/armor/network/service/create.sh", {
    PROJECT_ID   = var.project_id_hub
    POLICY_NAME  = "${local.hub_prefix}ca-nlb-policy"
    SERVICE_NAME = "${local.hub_prefix}ca-nlb-service"
    REGION       = local.hub_us_region
  })
  hub_ca_nlb_service_delete = templatefile("scripts/armor/network/service/delete.sh", {
    PROJECT_ID   = var.project_id_hub
    POLICY_NAME  = "${local.hub_prefix}ca-nlb-policy"
    SERVICE_NAME = "${local.hub_prefix}ca-nlb-service"
    REGION       = local.hub_us_region
  })
}

resource "null_resource" "hub_ca_nlb_service" {
  depends_on = [null_resource.hub_us_nlb_policy, ]
  triggers = {
    create = local.hub_ca_nlb_service_create
    delete = local.hub_ca_nlb_service_delete
  }
  provisioner "local-exec" {
    command = self.triggers.create
  }
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.delete
  }
}
