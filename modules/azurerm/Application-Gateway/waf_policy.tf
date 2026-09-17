# -------------------------------------------------------------------------------------
#
# Copyright (c) 2026, WSO2 LLC. (http://www.wso2.com). All Rights Reserved.
#
# This software is the property of WSO2 LLC. and its suppliers, if any.
# Dissemination of any information or reproduction of any material contained
# herein in any form is strictly forbidden, unless permitted by WSO2 expressly.
# You may not alter or remove any copyright or other notice from copies of this content.
#
# --------------------------------------------------------------------------------------
resource "azurerm_web_application_firewall_policy" "waf_policy" {
  name                = join("-", compact([var.application_gateway_abbreviation, var.application_gateway_name, "waf-policy"]))
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  policy_settings {
    enabled                     = var.waf_enabled
    mode                        = var.waf_firewall_mode
    file_upload_limit_in_mb     = var.waf_file_upload_limit_mb
    max_request_body_size_in_kb = var.waf_max_request_body_size_kb
    request_body_check          = var.waf_request_body_check
  }

  managed_rules {
    dynamic "managed_rule_set" {
      for_each = [1]

      content {
        type    = var.waf_rule_set_type
        version = var.waf_rule_set_version

        dynamic "rule_group_override" {
          for_each = var.waf_disabled_rule_group_settings

          content {
            rule_group_name = rule_group_override.value["rule_group_name"]

            dynamic "rule" {
              for_each = rule_group_override.value["rules"]

              content {
                id      = rule.value
                enabled = false
              }
            }
          }
        }
      }
    }

    dynamic "exclusion" {
      for_each = var.waf_exclusion_settings

      content {
        match_variable          = exclusion.value["match_variable"]
        selector                = exclusion.value["selector"]
        selector_match_operator = exclusion.value["selector_match_operator"]
      }
    }
  }

  lifecycle {
    ignore_changes = [
      tags,
      managed_rules[0].managed_rule_set,
    ]
  }
}
