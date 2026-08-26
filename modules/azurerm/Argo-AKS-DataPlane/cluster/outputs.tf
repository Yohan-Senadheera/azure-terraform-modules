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

output "aks_cluster_name" {
  value = azurerm_kubernetes_cluster.this.name
}

output "aks_cluster_id" {
  value = azurerm_kubernetes_cluster.this.id
}

output "kubernetes_cluster_fqdn" {
  value = azurerm_kubernetes_cluster.this.fqdn
}

output "kubernetes_cluster_private_fqdn" {
  value = azurerm_kubernetes_cluster.this.private_fqdn
}

output "aks_oidc_issuer_url" {
  value = azurerm_kubernetes_cluster.this.oidc_issuer_url
}

output "virtual_network_name" {
  value = azurerm_virtual_network.this.name
}

output "stage_subnet_id" {
  value = azurerm_subnet.stage.id
}

output "prod_subnet_id" {
  value = azurerm_subnet.prod.id
}

output "bastion_host_id" {
  value = var.enable_bastion ? azurerm_bastion_host.this[0].id : null
}
