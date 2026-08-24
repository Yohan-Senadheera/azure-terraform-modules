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

module "namespaces" {
  source = "git::https://github.com/wso2/common-terraform-modules.git//modules/kubernetes/Namespaces?ref=main"

  kubernetes_namespaces = merge(
    { for ns in var.namespaces : ns => {} },
    { (var.argocd_namespace) = {} },
  )
}

module "argo_workflows" {
  source   = "git::https://github.com/wso2/common-terraform-modules.git//modules/helm/Helm-Release?ref=main"
  for_each = toset(var.namespaces)

  release_name     = "argo-workflows"
  chart_repo       = var.argo_helm_repo
  chart_name       = "argo-workflows"
  version_number   = var.argo_workflows_chart_version
  namespace        = each.value
  create_namespace = false
  values           = lookup(var.argo_workflows_values, each.value, [])

  depends_on = [module.namespaces]
}

module "argo_events" {
  source   = "git::https://github.com/wso2/common-terraform-modules.git//modules/helm/Helm-Release?ref=main"
  for_each = toset(var.namespaces)

  release_name     = "argo-events"
  chart_repo       = var.argo_helm_repo
  chart_name       = "argo-events"
  version_number   = var.argo_events_chart_version
  namespace        = each.value
  create_namespace = false
  values           = lookup(var.argo_events_values, each.value, [])

  depends_on = [module.namespaces]
}

module "argocd" {
  source = "git::https://github.com/wso2/common-terraform-modules.git//modules/helm/Helm-Release?ref=main"
  count  = var.install_argocd ? 1 : 0

  release_name     = "argocd"
  chart_repo       = var.argocd_helm_repo
  chart_name       = "argo-cd"
  version_number   = var.argocd_chart_version
  namespace        = var.argocd_namespace
  create_namespace = false
  values           = var.argocd_values

  depends_on = [module.namespaces]
}

module "manifests" {
  source   = "git::https://github.com/wso2/common-terraform-modules.git//modules/kubernetes/Manifest?ref=main"
  for_each = { for idx, m in var.manifest_files : idx => m }

  manifest_location = each.value.location
  template_map      = each.value.template_map

  depends_on = [module.argo_workflows, module.argo_events, module.argocd]
}
