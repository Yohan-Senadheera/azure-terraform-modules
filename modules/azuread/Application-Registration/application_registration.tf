# -------------------------------------------------------------------------------------
#
# Copyright (c) 2025, WSO2 LLC. (https://www.wso2.com) All Rights Reserved.
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

resource "azuread_application_registration" "ad_application" {
  display_name            = var.application_name
  group_membership_claims = var.group_membership_claims

  lifecycle {
    create_before_destroy = true
  }
}

# Redirect URIs live on a separate resource in this provider version -
# azuread_application_registration itself has no such argument, and this
# resource is explicitly incompatible with the older azuread_application
# resource (not used here, so no conflict).
resource "azuread_application_redirect_uris" "ad_application" {
  count = length(var.redirect_uris) > 0 ? 1 : 0

  application_id = azuread_application_registration.ad_application.id
  type           = var.redirect_uri_type
  redirect_uris  = var.redirect_uris
}
