# -------------------------------------------------------------------------------------
#
# Copyright (c) 2026, WSO2 LLC. (https://www.wso2.com) All Rights Reserved.
#
# WSO2 LLC. licenses this file to you under the Apache License,
# Version 2.0 (the "License"); you may not use this file except
# in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied. See the License for the
# specific language governing permissions and limitations
# under the License.
#
# --------------------------------------------------------------------------------------
#
# Everything the Argo control plane's Entra ID SSO needs, self-contained
# in one module: the app registration, its service principal + rotating
# password, and the RBAC tier groups credential-injector maps requests
# against. Raw resource blocks (same convention as Argo-Control-Plane/
# Argo-EKS-DataPlane/Argo-AKS-DataPlane) instead of composing the generic
# Application-Registration/Service-Principal/Service-Principal-Password/
# Group modules - a caller only needs this one module block.
#
# --------------------------------------------------------------------------------------

resource "azuread_application_registration" "ad_application" {
  display_name            = var.application_name
  group_membership_claims = var.group_membership_claims

  lifecycle {
    create_before_destroy = true
  }
}

# count is gated on var.manage_redirect_uris (a plain bool literal), NOT
# on length(var.redirect_uris) - count/for_each can never depend on a
# value that's unknown until apply, and redirect_uris' real-world content
# is often built from something only known post-apply (a LoadBalancer
# hostname here).
resource "azuread_application_redirect_uris" "ad_application" {
  count = var.manage_redirect_uris ? 1 : 0

  application_id = azuread_application_registration.ad_application.id
  type           = var.redirect_uri_type
  redirect_uris  = var.redirect_uris
}

resource "azuread_service_principal" "service_principal" {
  client_id                    = azuread_application_registration.ad_application.client_id
  app_role_assignment_required = var.sp_app_role_assignment_required
}

resource "time_rotating" "password_rotating_time" {
  rotation_months = var.sp_password_rotation_months

  lifecycle {
    create_before_destroy = true
  }
}

resource "azuread_service_principal_password" "service_principal_password" {
  service_principal_id = azuread_service_principal.service_principal.id
  display_name         = var.sp_password_display_name

  rotate_when_changed = {
    rotation = time_rotating.password_rotating_time.id
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "azuread_group" "tier" {
  for_each = local.tier_groups

  display_name     = "${var.group_name_prefix}-${each.key}"
  description      = each.value
  security_enabled = true
}
