
# security policy - backend
#----------------------------------------------------

# create sec policy to allow all traffic
# rules will be configured after

locals {
  hub_sec_rule_ip_ranges_allowed_list = concat(
    [for x in google_compute_address.hub_flood4_vm : x.address],
    [for x in google_compute_address.hub_flood7_vm : x.address],
    [
      "${data.external.case1_external_ip.result.ip}",
      google_compute_address.hub_denied_vm.address,
      google_compute_address.hub_baseline_vm.address,
    ]
  )
  hub_sec_rule_ip_ranges_allowed_string = join(",", local.hub_sec_rule_ip_ranges_allowed_list)
}

locals {
  hub_sec_rule_sqli_excluded_crs = join(",", [
    "'owasp-crs-v030001-id942421-sqli'",
    "'owasp-crs-v030001-id942200-sqli'",
    "'owasp-crs-v030001-id942260-sqli'",
    "'owasp-crs-v030001-id942340-sqli'",
    "'owasp-crs-v030001-id942430-sqli'",
    "'owasp-crs-v030001-id942431-sqli'",
    "'owasp-crs-v030001-id942432-sqli'",
    "'owasp-crs-v030001-id942420-sqli'",
    "'owasp-crs-v030001-id942440-sqli'",
    "'owasp-crs-v030001-id942450-sqli'",
  ])
  hub_sec_rule_preconfigured_sqli_tuned = "evaluatePreconfiguredExpr('sqli-stable',[${local.hub_sec_rule_sqli_excluded_crs}])"
  hub_sec_rule_custom_hacker            = "origin.region_code == 'US' && request.headers['Referer'].contains('hacker')"
}

locals {
  hub_backend_sec_rules_expr = {
    #("lfi")      = { preview = false, priority = 10, action = "deny(403)", ip = false, expression = "evaluatePreconfiguredExpr('lfi-stable')" }
    #("rce")      = { preview = false, priority = 20, action = "deny(403)", ip = false, expression = "evaluatePreconfiguredExpr('rce-stable')" }
    #("scanners") = { preview = false, priority = 30, action = "deny(403)", ip = false, expression = "evaluatePreconfiguredExpr('scannerdetection-stable')" }
    #("protocol") = { preview = false, priority = 40, action = "deny(403)", ip = false, expression = "evaluatePreconfiguredExpr('protocolattack-stable')" }
    #("session")  = { preview = false, priority = 50, action = "deny(403)", ip = false, expression = "evaluatePreconfiguredExpr('sessionfixation-stable')" }
    #("sqli")     = { preview = false, priority = 60, action = "deny(403)", ip = false, expression = local.hub_sec_rule_preconfigured_sqli_tuned }
    #("hacker")   = { preview = true, priority = 70, action = "deny(403)", ip = false, expression = local.hub_sec_rule_custom_hacker }
    #("xss")      = { preview = true, priority = 80, action = "deny(403)", ip = false, expression = "evaluatePreconfiguredExpr('xss-stable')" }
  }
  hub_backend_sec_rules_versioned_expr = {
    ("ranges")  = { preview = false, priority = 90, action = "allow", ip = true, src_ip_ranges = local.hub_sec_rule_ip_ranges_allowed_list }
    ("default") = { preview = false, priority = 2147483647, action = "deny(403)", src_ip_ranges = ["*"] }
  }
}

resource "google_compute_security_policy" "hub_backend_sec_policy" {
  provider    = google-beta
  project     = var.project_id_hub
  name        = "${local.hub_prefix}gclb7-backend-sec-policy"
  description = "CLOUD_ARMOR"
  adaptive_protection_config {
    layer_7_ddos_defense_config {
      enable          = true
      rule_visibility = "STANDARD"
    }
  }
  dynamic "rule" {
    for_each = local.hub_backend_sec_rules_versioned_expr
    iterator = rule
    content {
      action      = rule.value.action
      priority    = rule.value.priority
      description = rule.key
      match {
        versioned_expr = "SRC_IPS_V1"
        config {
          src_ip_ranges = rule.value.src_ip_ranges
        }
      }
    }
  }
  dynamic "rule" {
    for_each = local.hub_backend_sec_rules_expr
    iterator = rule
    content {
      action      = rule.value.action
      priority    = rule.value.priority
      description = rule.key
      match {
        expr {
          expression = rule.value.expression
        }
      }
    }
  }
}
