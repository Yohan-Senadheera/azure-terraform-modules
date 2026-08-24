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
#
# Composes the same tainted-node-pool + subnet-pinned + NAT-per-tier
# isolation pattern already proven live and mirrored in Argo-EKS-DataPlane,
# purely from existing generic modules in this repo. Stage is AKS-Generic's
# own default node pool + subnet; prod is a separate subnet and a separate,
# tainted AKS-Node-Pool. Cluster admin access is native Azure RBAC for
# Kubernetes (aks_admin_group_object_ids) plus an optional Azure Bastion,
# matching the native-per-cloud-identity decision (no unified cross-cloud
# OIDC layer).
#
# --------------------------------------------------------------------------------------

locals {
  node_pool_subnet_name         = "${var.aks_cluster_name}-stage-snet"
  node_pool_route_table_name    = "${var.aks_cluster_name}-stage-rt"
  node_pool_nsg_name            = "${var.aks_cluster_name}-stage-nsg"
  lb_subnet_name                = "${var.aks_cluster_name}-ilb-snet"
  lb_nsg_name                   = "${var.aks_cluster_name}-ilb-nsg"
  node_pool_resource_group_name = "${var.aks_cluster_name}-nodes-rg"

  prod_subnet_name = "${var.aks_cluster_name}-prod-snet"
  prod_nsg_name    = "${var.aks_cluster_name}-prod-nsg"
}

module "vnet" {
  source = "../../Virtual-Network"

  virtual_network_name          = var.vnet_name
  virtual_network_address_space = var.vnet_address_space
  location                      = var.location
  resource_group_name           = var.resource_group_name
  tags                          = var.tags
}

# --- Stage tier: AKS-Generic's own default node pool + its own subnet ---

module "aks" {
  source = "../../AKS-Generic"

  aks_cluster_name        = var.aks_cluster_name
  aks_cluster_dns_prefix  = var.aks_dns_prefix
  location                = var.location
  aks_resource_group_name = var.resource_group_name
  tags                    = var.tags

  log_analytics_workspace_id = var.log_analytics_workspace_id

  virtual_network_name                                 = module.vnet.virtual_network_name
  aks_node_pool_subnet_address_prefix                  = var.stage_subnet_address_prefix
  aks_node_pool_resource_group_name                    = local.node_pool_resource_group_name
  aks_node_pool_subnet_name                            = local.node_pool_subnet_name
  aks_node_pool_subnet_route_table_name                = local.node_pool_route_table_name
  aks_node_pool_subnet_network_security_group_name     = local.node_pool_nsg_name
  aks_load_balancer_subnet_name                        = local.lb_subnet_name
  aks_load_balancer_subnet_network_security_group_name = local.lb_nsg_name
  internal_loadbalancer_subnet_address_prefix          = var.internal_lb_subnet_address_prefix

  aks_admin_username      = var.aks_admin_username
  aks_public_ssh_key_path = var.aks_public_ssh_key_path

  kubernetes_version = var.kubernetes_version
  service_cidr       = var.service_cidr
  dns_service_ip     = var.dns_service_ip

  private_cluster_enabled         = var.private_cluster_enabled
  api_server_authorized_ip_ranges = var.api_server_authorized_ip_ranges

  aks_azure_rbac_enabled     = true
  aks_admin_group_object_ids = var.aks_admin_group_object_ids

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  default_node_pool_name                         = "stage"
  default_node_pool_count                        = var.stage_node_count
  default_node_pool_vm_size                      = var.stage_node_vm_size
  default_node_pool_availability_zones           = var.stage_availability_zones
  default_node_pool_orchestrator_version         = var.kubernetes_version
  default_node_pool_os_disk_size_gb              = 128
  default_node_pool_max_count                    = var.stage_node_max_count
  default_node_pool_min_count                    = var.stage_node_min_count
  default_node_pool_max_pods                     = 110
  default_node_pool_only_critical_addons_enabled = false
  azure_policy_enabled                           = false
}

# --- Prod tier: dedicated subnet + dedicated, tainted node pool ---

module "prod_subnet" {
  source = "../../Subnet"

  subnet_name                 = local.prod_subnet_name
  network_security_group_name = local.prod_nsg_name
  location                    = var.location
  resource_group_name         = var.resource_group_name
  virtual_network_name        = module.vnet.virtual_network_name
  address_prefix              = [var.prod_subnet_address_prefix]
  tags                        = var.tags

  depends_on = [module.aks]
}

module "prod_node_pool" {
  source = "../../AKS-Node-Pool"

  node_pool_name = "prod"
  aks_cluster_id = module.aks.aks_cluster_id
  aks_subnet_id  = module.prod_subnet.subnet_id
  tags           = var.tags

  node_pool_count                = var.prod_node_count
  node_pool_vm_size              = var.prod_node_vm_size
  node_pool_availability_zones   = var.prod_availability_zones
  node_pool_orchestrator_version = var.kubernetes_version
  node_pool_os_disk_size_gb      = 128
  node_pool_enable_auto_scaling  = true
  node_pool_max_count            = var.prod_node_max_count
  node_pool_min_count            = var.prod_node_min_count
  node_pool_max_pods             = 110
  node_pool_mode                 = "User"

  node_taints = ["env=${var.prod_node_taint_value}:NoSchedule"]
}

# --- Per-tier NAT Gateways (own outbound IP each) ---

module "stage_public_ip" {
  source = "../../Public-IP"

  public_ip_name      = "${var.aks_cluster_name}-stage-nat"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

module "stage_nat_gateway" {
  source = "../../NAT-Gateway"

  nat_gateway_name    = "${var.aks_cluster_name}-stage"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  subnet_id    = module.aks.aks_node_pool_subnet_id
  public_ip_id = module.stage_public_ip.public_ip_id
}

module "prod_public_ip" {
  source = "../../Public-IP"

  public_ip_name      = "${var.aks_cluster_name}-prod-nat"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

module "prod_nat_gateway" {
  source = "../../NAT-Gateway"

  nat_gateway_name    = "${var.aks_cluster_name}-prod"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  subnet_id    = module.prod_subnet.subnet_id
  public_ip_id = module.prod_public_ip.public_ip_id
}

# --- Bastion: native-identity admin access path (login-flow decision) ---

module "bastion" {
  source = "../../Bastion-Host"
  count  = var.enable_bastion ? 1 : 0

  bastion_host_name           = "${var.aks_cluster_name}-bastion"
  network_security_group_name = "${var.aks_cluster_name}-bastion"
  public_ip_name              = "${var.aks_cluster_name}-bastion"
  location                    = var.location
  resource_group_name         = var.resource_group_name
  tags                        = var.tags

  virtual_network_name    = module.vnet.virtual_network_name
  subnet_address_prefixes = var.bastion_subnet_address_prefix

  sku                = "Standard"
  tunneling_enabled  = true
  ip_connect_enabled = true

  allow_https_internet_inbound = var.bastion_allow_https_internet_inbound
  public_address_prefixes      = var.bastion_public_address_prefixes
}
