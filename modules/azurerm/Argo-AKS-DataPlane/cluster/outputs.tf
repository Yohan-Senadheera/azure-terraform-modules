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
  value = module.aks.aks_cluster_name
}

output "aks_cluster_id" {
  value = module.aks.aks_cluster_id
}

output "kubernetes_cluster_fqdn" {
  value = module.aks.kubernetes_cluster_fqdn
}

output "kubernetes_cluster_private_fqdn" {
  value = module.aks.kubernetes_cluster_private_fqdn
}

output "aks_oidc_issuer_url" {
  value = module.aks.aks_oidc_issuer_url
}

output "virtual_network_name" {
  value = module.vnet.virtual_network_name
}

output "stage_subnet_id" {
  value = module.aks.aks_node_pool_subnet_id
}

output "prod_subnet_id" {
  value = module.prod_subnet.subnet_id
}

output "bastion_host_id" {
  value = var.enable_bastion ? module.bastion[0].bastion_host_id : null
}
