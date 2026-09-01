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

variable "application_name" {
  description = "The name of the application"
  type        = string
}

variable "group_membership_claims" {
  description = "Configures the groups claim issued in a token this app expects. One or more of: None, SecurityGroup, DirectoryRole, ApplicationGroup, All."
  type        = list(string)
  default     = null
}

variable "manage_redirect_uris" {
  description = "Whether to create the azuread_application_redirect_uris resource at all. Must be a plain bool the caller controls directly - do not derive this from whether redirect_uris happens to be non-empty, since that value can be unknown until apply and count/for_each can't depend on it."
  type        = bool
  default     = false
}

variable "redirect_uris" {
  description = "Redirect URIs to assign to the application. Only used when manage_redirect_uris = true; this value itself may safely be unknown until apply (e.g. built from a LoadBalancer hostname)."
  type        = list(string)
  default     = []
}

variable "redirect_uri_type" {
  description = "The type of redirect URIs in redirect_uris. One of: PublicClient, SPA, Web."
  type        = string
  default     = "Web"
}
