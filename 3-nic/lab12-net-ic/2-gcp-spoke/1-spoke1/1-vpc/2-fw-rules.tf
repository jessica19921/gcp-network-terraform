
# firewall rules

resource "google_compute_firewall" "spoke1_allow_iap" {
  name    = "spoke1-allow-iap"
  network = google_compute_network.vpc_spoke1.self_link

  allow {
    protocol = "tcp"
  }

  source_ranges = ["35.235.240.0/20"]
}

resource "google_compute_firewall" "spoke1_allow_rfc1918" {
  name    = "spoke1-allow-rfc1918"
  network = google_compute_network.vpc_spoke1.self_link

  allow {
    protocol = "all"
  }

  source_ranges = [
    "10.0.0.0/8",
    "172.16.0.0/12",
    "192.168.0.0/16"
  ]
}
