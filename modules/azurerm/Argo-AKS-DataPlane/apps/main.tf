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
# Raw kubernetes/helm resources, no dependency on wso2/common-terraform-modules.
#
# --------------------------------------------------------------------------------------

resource "kubernetes_namespace_v1" "this" {
  for_each = toset(concat(var.namespaces, [var.argocd_namespace, var.system_namespace]))

  metadata {
    name = each.value
  }
}

# ONE shared argo-server + workflow-controller per data plane, in
# system_namespace - matches the security review doc's data-plane diagram
# ("system-pool - shared ... argo-server (argo-CLOUD-stage / -prod)") and
# its explicit statement that "the workflow-controller and Argo Events
# controllers see every namespace on their cluster - this is normal
# Kubernetes control-plane behaviour." Tier isolation is real RBAC
# (data-plane-tier-rbac.yaml / data-plane-debug-access-rbac.yaml, applied
# via manifest_files), not separate controller instances per tier.
resource "helm_release" "argo_workflows" {
  name             = "argo-workflows"
  repository       = var.argo_helm_repo
  chart            = "argo-workflows"
  version          = var.argo_workflows_chart_version
  namespace        = var.system_namespace
  create_namespace = false
  values           = var.argo_workflows_values

  depends_on = [kubernetes_namespace_v1.this]
}

resource "helm_release" "argo_events" {
  name             = "argo-events"
  repository       = var.argo_helm_repo
  chart            = "argo-events"
  version          = var.argo_events_chart_version
  namespace        = var.system_namespace
  create_namespace = false
  values           = var.argo_events_values

  depends_on = [kubernetes_namespace_v1.this]
}

resource "helm_release" "argocd" {
  count = var.install_argocd ? 1 : 0

  name             = "argocd"
  repository       = var.argocd_helm_repo
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  namespace        = var.argocd_namespace
  create_namespace = false
  values           = var.argocd_values

  depends_on = [kubernetes_namespace_v1.this]
}

# Several real pipeline manifests are multi-document YAML (Deployment +
# Service + IngressRoute in one file, multiple RBAC objects, etc.) -
# yamldecode() only parses a single document, so each file is split on a
# bare "---" line first.
locals {
  manifest_documents = flatten([
    for idx, m in var.manifest_files : [
      for doc_idx, doc in [
        for chunk in split("\n---\n", "\n${templatefile(m.location, m.template_map)}") : chunk
        if trimspace(chunk) != ""
        ] : {
        key      = "${idx}-${doc_idx}"
        manifest = yamldecode(doc)
      }
    ]
  ])
}

resource "kubernetes_manifest" "this" {
  for_each = { for d in local.manifest_documents : d.key => d.manifest }

  manifest = each.value

  depends_on = [helm_release.argo_workflows, helm_release.argo_events, helm_release.argocd]
}
