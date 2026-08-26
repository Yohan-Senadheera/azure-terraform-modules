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
# Raw azurerm resource blocks, not wrapped through wso2/azure-terraform-modules
# - this composite has no dependency on that repo (or any other WSO2 module
# repo) at all. Same tainted-node-pool + subnet-pinned + NAT-per-tier
# isolation pattern as before, just expressed directly: stage is the
# cluster's default node pool + its own subnet; prod is a separate subnet
# and a separate, tainted node pool. Cluster admin access is native Azure
# RBAC for Kubernetes (aks_admin_group_object_ids) plus an optional Azure
# Bastion, matching the native-per-cloud-identity decision (no unified
# cross-cloud OIDC layer).
#
# --------------------------------------------------------------------------------------

resource "azurerm_virtual_network" "this" {
  name                = var.vnet_name
  address_space       = [var.vnet_address_space]
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_subnet" "stage" {
  name                 = "${var.aks_cluster_name}-stage-snet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.stage_subnet_address_prefix]
}

resource "azurerm_subnet" "prod" {
  name                 = "${var.aks_cluster_name}-prod-snet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.prod_subnet_address_prefix]
}

resource "azurerm_subnet" "ilb" {
  name                 = "${var.aks_cluster_name}-ilb-snet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.internal_lb_subnet_address_prefix]
}

# --- Per-tier NSGs. Prod's own NSG denies inbound from the stage subnet -
#     the real network isolation boundary underneath the taint. ---

resource "azurerm_network_security_group" "stage" {
  name                = "${var.aks_cluster_name}-stage-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_subnet_network_security_group_association" "stage" {
  subnet_id                 = azurerm_subnet.stage.id
  network_security_group_id = azurerm_network_security_group.stage.id
}

resource "azurerm_network_security_group" "prod" {
  name                = "${var.aks_cluster_name}-prod-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_network_security_rule" "deny_stage_inbound_to_prod" {
  name                        = "DenyStageSubnetInbound"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = var.stage_subnet_address_prefix
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.prod.name
}

resource "azurerm_subnet_network_security_group_association" "prod" {
  subnet_id                 = azurerm_subnet.prod.id
  network_security_group_id = azurerm_network_security_group.prod.id
}

# --- Per-tier NAT Gateways (own outbound IP each) ---

resource "azurerm_public_ip" "stage_nat" {
  name                = "${var.aks_cluster_name}-stage-nat-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_nat_gateway" "stage" {
  name                = "${var.aks_cluster_name}-stage-nat"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = "Standard"
  tags                = var.tags
}

resource "azurerm_nat_gateway_public_ip_association" "stage" {
  nat_gateway_id       = azurerm_nat_gateway.stage.id
  public_ip_address_id = azurerm_public_ip.stage_nat.id
}

resource "azurerm_subnet_nat_gateway_association" "stage" {
  subnet_id      = azurerm_subnet.stage.id
  nat_gateway_id = azurerm_nat_gateway.stage.id
}

resource "azurerm_public_ip" "prod_nat" {
  name                = "${var.aks_cluster_name}-prod-nat-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_nat_gateway" "prod" {
  name                = "${var.aks_cluster_name}-prod-nat"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = "Standard"
  tags                = var.tags
}

resource "azurerm_nat_gateway_public_ip_association" "prod" {
  nat_gateway_id       = azurerm_nat_gateway.prod.id
  public_ip_address_id = azurerm_public_ip.prod_nat.id
}

resource "azurerm_subnet_nat_gateway_association" "prod" {
  subnet_id      = azurerm_subnet.prod.id
  nat_gateway_id = azurerm_nat_gateway.prod.id
}

# --- AKS cluster: stage is the default node pool, prod is a separate,
#     tainted node pool ---

resource "azurerm_kubernetes_cluster" "this" {
  name                = var.aks_cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.aks_dns_prefix
  kubernetes_version  = var.kubernetes_version

  private_cluster_enabled = var.private_cluster_enabled

  api_server_access_profile {
    authorized_ip_ranges = var.api_server_authorized_ip_ranges
  }

  # Required by azurerm >= 5.x's node_provisioning_profile schema addition
  # (tied to AKS Node Autoprovisioning / Karpenter integration) - "Manual"
  # since node pools here are explicitly, individually managed below, not
  # auto-provisioned by AKS itself.
  node_provisioning_profile {
    mode = "Manual"
  }

  default_node_pool {
    name                         = "stage"
    vm_size                      = var.stage_node_vm_size
    vnet_subnet_id               = azurerm_subnet.stage.id
    zones                        = [for z in var.stage_availability_zones : tostring(z)]
    auto_scaling_enabled         = true
    min_count                    = var.stage_node_min_count
    max_count                    = var.stage_node_max_count
    os_disk_size_gb              = 128
    max_pods                     = 110
    only_critical_addons_enabled = false
  }

  identity {
    type = "SystemAssigned"
  }

  linux_profile {
    admin_username = var.aks_admin_username
    ssh_key {
      key_data = file(var.aks_public_ssh_key_path)
    }
  }

  network_profile {
    network_plugin = "azure"
    service_cidr   = var.service_cidr
    dns_service_ip = var.dns_service_ip
  }

  oms_agent {
    log_analytics_workspace_id = var.log_analytics_workspace_id
  }

  azure_active_directory_role_based_access_control {
    azure_rbac_enabled     = true
    admin_group_object_ids = var.aks_admin_group_object_ids
  }

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  tags = var.tags

  depends_on = [
    azurerm_subnet_nat_gateway_association.stage,
    azurerm_subnet_network_security_group_association.stage,
  ]
}

resource "azurerm_kubernetes_cluster_node_pool" "prod" {
  name                  = "prod"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  vm_size               = var.prod_node_vm_size
  vnet_subnet_id        = azurerm_subnet.prod.id
  zones                 = var.prod_availability_zones
  auto_scaling_enabled  = true
  min_count             = var.prod_node_min_count
  max_count             = var.prod_node_max_count
  os_disk_size_gb       = 128
  max_pods              = 110
  mode                  = "User"
  node_taints           = ["env=${var.prod_node_taint_value}:NoSchedule"]

  tags = var.tags

  depends_on = [
    azurerm_subnet_nat_gateway_association.prod,
    azurerm_subnet_network_security_group_association.prod,
  ]
}

# --- Bastion: native-identity admin access path (login-flow decision) ---

resource "azurerm_subnet" "bastion" {
  count = var.enable_bastion ? 1 : 0

  name                 = "AzureBastionSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.bastion_subnet_address_prefix]
}

resource "azurerm_public_ip" "bastion" {
  count = var.enable_bastion ? 1 : 0

  name                = "${var.aks_cluster_name}-bastion-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_network_security_group" "bastion" {
  count = var.enable_bastion ? 1 : 0

  name                = "${var.aks_cluster_name}-bastion-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_network_security_rule" "bastion_allow_https_inbound" {
  count = var.enable_bastion ? 1 : 0

  name                        = "AllowHttpsInBound"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = var.bastion_allow_https_internet_inbound ? "Internet" : null
  source_address_prefixes     = var.bastion_allow_https_internet_inbound ? null : var.bastion_public_address_prefixes
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.bastion[0].name
}

resource "azurerm_network_security_rule" "bastion_allow_gateway_manager_inbound" {
  count = var.enable_bastion ? 1 : 0

  name                        = "AllowGatewayManagerInBound"
  priority                    = 210
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "GatewayManager"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.bastion[0].name
}

resource "azurerm_network_security_rule" "bastion_allow_azure_lb_inbound" {
  count = var.enable_bastion ? 1 : 0

  name                        = "AllowAzureLoadBalancerInBound"
  priority                    = 220
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.bastion[0].name
}

resource "azurerm_network_security_rule" "bastion_allow_host_comm_inbound" {
  count = var.enable_bastion ? 1 : 0

  name                        = "AllowBastionHostCommunication"
  priority                    = 230
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["8080", "5701"]
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.bastion[0].name
}

resource "azurerm_network_security_rule" "bastion_allow_ssh_rdp_outbound" {
  count = var.enable_bastion ? 1 : 0

  name                        = "AllowSshRdpOutBound"
  priority                    = 200
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_ranges     = ["3389", "22"]
  source_address_prefix       = "*"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.bastion[0].name
}

resource "azurerm_network_security_rule" "bastion_allow_azure_cloud_outbound" {
  count = var.enable_bastion ? 1 : 0

  name                        = "AllowAzureCloudOutBound"
  priority                    = 210
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "AzureCloud"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.bastion[0].name
}

resource "azurerm_network_security_rule" "bastion_allow_comm_outbound" {
  count = var.enable_bastion ? 1 : 0

  name                        = "AllowBastionCommunication"
  priority                    = 220
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["8080", "5701"]
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.bastion[0].name
}

resource "azurerm_network_security_rule" "bastion_allow_get_session_outbound" {
  count = var.enable_bastion ? 1 : 0

  name                        = "AllowGetSessionInformation"
  priority                    = 230
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "Internet"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.bastion[0].name
}

resource "azurerm_subnet_network_security_group_association" "bastion" {
  count = var.enable_bastion ? 1 : 0

  subnet_id                 = azurerm_subnet.bastion[0].id
  network_security_group_id = azurerm_network_security_group.bastion[0].id
}

resource "azurerm_bastion_host" "this" {
  count = var.enable_bastion ? 1 : 0

  name                = "${var.aks_cluster_name}-bastion"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"
  tunneling_enabled   = true
  ip_connect_enabled  = true
  tags                = var.tags

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion[0].id
    public_ip_address_id = azurerm_public_ip.bastion[0].id
  }

  depends_on = [azurerm_subnet_network_security_group_association.bastion]
}
