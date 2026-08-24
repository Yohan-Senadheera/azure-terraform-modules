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

terraform {
  required_version = ">= 0.13"
  required_providers {
    # Pinned to the 4.x line, not left open-ended: AKS-Generic and
    # Virtual-Network (both composed here) use azurerm_subnet arguments
    # that azurerm 5.x removed (service_endpoints,
    # private_endpoint_network_policies) - this is a pre-existing gap in
    # those modules, not something this composite works around by design.
    # ~> 4.0 is the newest line where the whole dependency graph validates;
    # widen this once AKS-Generic/Virtual-Network are updated for 5.x.
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}
