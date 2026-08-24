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

variable "nat_gateway_name" {
  description = "The name of the NAT Gateway."
  type        = string
}

variable "location" {
  description = "The Azure Region in which to create the NAT Gateway."
  type        = string
}

variable "resource_group_name" {
  description = "The name of the resource group in which to create the NAT Gateway."
  type        = string
}

variable "tags" {
  description = "Tags for the NAT Gateway."
  type        = map(string)
}

variable "subnet_id" {
  description = "The ID of the subnet to associate the NAT Gateway with."
  type        = string
}

variable "public_ip_id" {
  description = "The ID of the (Standard SKU) Public IP to associate with the NAT Gateway. Use the Public-IP module to create it."
  type        = string
}

variable "sku_name" {
  default     = "Standard"
  description = "The SKU of the NAT Gateway. Only Standard is supported by Azure."
  type        = string
}

variable "idle_timeout_in_minutes" {
  default     = 4
  description = "The idle timeout in minutes for the NAT Gateway."
  type        = number
}

variable "zones" {
  default     = null
  description = "The availability zone the NAT Gateway is deployed in. NAT Gateway is zonal, not zone-redundant, so a list with a single zone is expected when set."
  type        = list(string)
}

variable "nat_gateway_abbreviation" {
  description = "The abbreviation of the resource name."
  type        = string
  default     = "natgw"
}
