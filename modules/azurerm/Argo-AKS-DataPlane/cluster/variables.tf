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

variable "resource_group_name" {
  type        = string
  description = "Resource group for the data plane (AKS, VNet, NAT Gateways, Bastion)"
}

variable "location" {
  type        = string
  description = "Azure region"
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to resources created by this module"
  default     = {}
}

variable "vnet_name" {
  type        = string
  description = "Name of the data plane's virtual network"
}

variable "vnet_address_space" {
  type        = string
  description = "Address space for the VNet, e.g. 10.2.0.0/16"
}

variable "aks_cluster_name" {
  type        = string
  description = "Name of the AKS cluster"
}

variable "aks_dns_prefix" {
  type        = string
  description = "DNS prefix for the AKS cluster"
}

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes version"
}

variable "aks_admin_username" {
  type        = string
  description = "Admin username for AKS nodes"
  default     = "azureuser"
}

variable "aks_public_ssh_key_path" {
  type        = string
  description = "Path to the public SSH key file for AKS nodes"
}

variable "aks_admin_group_object_ids" {
  type        = list(string)
  description = "Entra ID group object IDs granted AKS cluster-admin via native Azure RBAC for Kubernetes (no unified cross-cloud identity layer)"
  default     = []
}

variable "private_cluster_enabled" {
  type        = bool
  description = "Whether the AKS API server has a private-only endpoint"
  default     = false
}

variable "api_server_authorized_ip_ranges" {
  type        = list(string)
  description = "Authorized IP ranges for the public API server endpoint, if not private"
  default     = []
}

variable "service_cidr" {
  type        = string
  description = "CIDR block for Kubernetes Services"
}

variable "log_analytics_workspace_id" {
  type        = string
  description = "Resource ID of an existing Log Analytics Workspace for AKS's oms_agent. This module does not create one - pass an existing workspace's ID."
}

variable "dns_service_ip" {
  type        = string
  description = "DNS service IP, must be inside service_cidr"
}

# --- Stage tier (AKS-Generic's own default node pool + its own subnet) ---

variable "stage_subnet_address_prefix" {
  type        = string
  description = "CIDR for the stage tier's node pool subnet"
}

variable "internal_lb_subnet_address_prefix" {
  type        = string
  description = "CIDR for AKS's internal load balancer subnet (shared infra, not tier-specific)"
}

variable "stage_node_count" {
  type    = number
  default = 2
}

variable "stage_node_vm_size" {
  type = string
}

variable "stage_availability_zones" {
  type    = list(number)
  default = [1, 2, 3]
}

variable "stage_node_min_count" {
  type    = number
  default = 1
}

variable "stage_node_max_count" {
  type    = number
  default = 3
}

# --- Prod tier (separate subnet + separate, tainted node pool) ---

variable "prod_subnet_address_prefix" {
  type        = string
  description = "CIDR for the prod tier's dedicated subnet"
}

variable "prod_node_count" {
  type    = number
  default = 2
}

variable "prod_node_vm_size" {
  type = string
}

variable "prod_availability_zones" {
  type    = list(string)
  default = ["1", "2", "3"]
}

variable "prod_node_min_count" {
  type    = number
  default = 1
}

variable "prod_node_max_count" {
  type    = number
  default = 3
}

variable "prod_node_taint_value" {
  type        = string
  description = "Value for the env taint applied to prod nodes (e.g. \"env=prod:NoSchedule\") so only workloads that explicitly tolerate it land there"
  default     = "prod"
}

# --- Bastion (native-identity admin access path, per the login-flow decision) ---

variable "enable_bastion" {
  type        = bool
  description = "Whether to provision Azure Bastion for admin access to this data plane"
  default     = true
}

variable "bastion_subnet_address_prefix" {
  type        = string
  description = "CIDR for the AzureBastionSubnet (must be /26 or larger per Azure's requirement)"
  default     = null
}

variable "bastion_allow_https_internet_inbound" {
  type        = bool
  description = "Whether the Bastion host accepts inbound from the public internet vs. only from public_address_prefixes"
  default     = false
}

variable "bastion_public_address_prefixes" {
  type        = list(string)
  description = "Source CIDRs allowed to reach Bastion when bastion_allow_https_internet_inbound is false"
  default     = []
}
