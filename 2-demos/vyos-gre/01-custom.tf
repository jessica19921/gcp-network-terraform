
# common
#---------------------------------

locals {
  prefix       = "c"
  targets_app  = []
  targets_ping = []
  targets_pga  = []
}

# vyos ssh

locals {
  private_key_path = pathexpand("~/.ssh/vyos${local.prefix}")
  public_key_path  = pathexpand("~/.ssh/vyos${local.prefix}.pub")
}

resource "tls_private_key" "vyos_router" {
  algorithm = "RSA"
}

resource "local_file" "vyos_router_private_key" {
  content  = tls_private_key.vyos_router.private_key_pem
  filename = local.private_key_path
}

resource "local_file" "vyos_router_public_key" {
  content  = tls_private_key.vyos_router.public_key_openssh
  filename = local.public_key_path
}

resource "null_resource" "vyos_router_key_permission" {
  depends_on = [local_file.vyos_router_private_key]
  provisioner "local-exec" {
    command = "chmod 400 ${local.private_key_path}"
  }
}
