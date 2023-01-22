
# instance
#----------------------------------------------------

locals {
  hub_us_nlb_vm_config = templatefile("scripts/startup/juice.yaml", {
    APP_NAME  = "${local.hub_prefix}juice-shop"
    APP_IMAGE = "bkimminich/juice-shop"
  })
  hub_us_nlb_vm_cos = templatefile("scripts/startup/armor/nlb.sh", {
    NLB_VIP = google_compute_address.hub_us_nlb_frontend.address
    VM_IP   = module.hub_us_nlb_vm.internal_ip
    PORT    = local.svc_juice.port
    VCPU    = 2
  })
}

module "hub_us_nlb_vm" {
  source        = "../../modules/compute-vm"
  project_id    = var.project_id_hub
  name          = "${local.hub_prefix}us-nlb-vm"
  zone          = "${local.hub_us_region}-b"
  tags          = [local.tag_ssh, local.tag_gfe, "allow-flood4", ]
  instance_type = "e2-standard-4"
  boot_disk = {
    image = var.image_cos
    type  = var.disk_type
    size  = var.disk_size
  }
  network_interfaces = [{
    network    = google_compute_network.hub_vpc.self_link
    subnetwork = local.hub_us_subnet1.self_link
    addresses  = null
    nat        = true
    alias_ips  = null
  }]
  service_account        = module.hub_sa.email
  service_account_scopes = ["cloud-platform"]
  metadata = {
    gce-container-declaration = local.hub_us_nlb_vm_config
    google-logging-enabled    = true
    google-monitoring-enabled = true
  }
}

resource "local_file" "hub_us_nlb_vm_cos" {
  content  = local.hub_us_nlb_vm_cos
  filename = "config/hub/armor/nlb-cos.sh"
}

# instance group
#----------------------------------------------------

# us

resource "google_compute_instance_group" "hub_us_nlb_ig" {
  project   = var.project_id_hub
  zone      = "${local.hub_us_region}-b"
  name      = "${local.hub_prefix}us-nlb-ig"
  instances = [module.hub_us_nlb_vm.self_link, ]
  named_port {
    name = local.svc_juice.name
    port = local.svc_juice.port
  }
}

# nlb
#----------------------------------------------------

# tcp

module "hub_us_nlb_tcp" {
  source     = "../../modules/network-lb"
  project_id = var.project_id_hub
  region     = local.hub_us_region
  name       = "${local.hub_prefix}us-nlb-tcp"
  address    = google_compute_address.hub_us_nlb_frontend.address
  protocol   = "TCP"
  ports      = [local.svc_juice.port, ]
  backends = [{
    group          = google_compute_instance_group.hub_us_nlb_ig.self_link
    balancing_mode = "CONNECTION"
    failover       = false
  }]
  health_check_config = {
    type    = "tcp"
    config  = {}
    logging = true
    check   = { port = local.svc_juice.port }
  }
}

module "hub_us_nlb_udp" {
  source     = "../../modules/network-lb"
  project_id = var.project_id_hub
  region     = local.hub_us_region
  name       = "${local.hub_prefix}us-nlb-udp"
  address    = google_compute_address.hub_us_nlb_frontend.address
  ports      = [local.svc_juice.port]
  protocol   = "UDP"
  backends = [{
    group          = google_compute_instance_group.hub_us_nlb_ig.self_link
    balancing_mode = "CONNECTION"
    failover       = false
  }]
  health_check_config = {
    type    = "tcp"
    config  = {}
    logging = true
    check   = { port = local.svc_juice.port }
  }
}

# dns
#----------------------------------------------------

resource "google_dns_record_set" "hub_us_nlb_dns" {
  project      = var.project_id_dns
  managed_zone = data.google_dns_managed_zone.public_zone.name
  name         = local.hub_host_nlb
  type         = "A"
  ttl          = 300
  rrdatas      = [module.hub_us_nlb_tcp.forwarding_rule.ip_address]
}
