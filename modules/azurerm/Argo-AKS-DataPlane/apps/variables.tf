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
# Mirrors Argo-EKS-DataPlane/apps exactly - same generic Helm/Kubernetes
# modules from common-terraform-modules, same manifest_files pattern for
# caller-supplied, project-specific YAML. Assumes the caller has already
# configured the kubernetes and helm providers against the cluster built by
# the sibling ../cluster module.
#
# --------------------------------------------------------------------------------------

variable "namespaces" {
  type        = list(string)
  description = "Kubernetes namespaces to install a namespaced Argo Workflows + Argo Events release into, one pair per namespace (e.g. [\"argo-stage\", \"argo-prod\"])"
}

variable "argo_workflows_chart_version" {
  type        = string
  description = "Argo Workflows Helm chart version. Null uses the chart repo's latest."
  default     = null
}

variable "argo_events_chart_version" {
  type        = string
  description = "Argo Events Helm chart version. Null uses the chart repo's latest."
  default     = null
}

variable "argo_helm_repo" {
  type        = string
  description = "Helm repository hosting the argo-workflows and argo-events charts"
  default     = "https://argoproj.github.io/argo-helm"
}

variable "argo_workflows_values" {
  type        = map(list(string))
  description = "Per-namespace Helm values overrides (YAML strings, later entries win) for the argo-workflows release. Key must match an entry in var.namespaces."
  default     = {}
}

variable "argo_events_values" {
  type        = map(list(string))
  description = "Per-namespace Helm values overrides (YAML strings, later entries win) for the argo-events release. Key must match an entry in var.namespaces."
  default     = {}
}

variable "install_argocd" {
  type        = bool
  description = "Whether to install ArgoCD on this cluster"
  default     = true
}

variable "argocd_namespace" {
  type        = string
  description = "Namespace for the ArgoCD installation"
  default     = "argocd"
}

variable "argocd_chart_version" {
  type        = string
  description = "ArgoCD Helm chart version. Null uses the chart repo's latest."
  default     = null
}

variable "argocd_helm_repo" {
  type        = string
  description = "Helm repository hosting the argo-cd chart"
  default     = "https://argoproj.github.io/argo-helm"
}

variable "argocd_values" {
  type        = list(string)
  description = "Helm values overrides (YAML strings, later entries win) for the argo-cd release"
  default     = []
}

variable "manifest_files" {
  type = list(object({
    location     = string
    template_map = optional(map(string), {})
  }))
  description = "Additional Kubernetes manifests to apply after the Helm releases above - e.g. debug-access RBAC, EventSource/Sensor definitions, ArgoCD Application/AppProject objects, ExternalSecrets/ClusterSecretStore for Workload Identity. Content and ordering are entirely caller-supplied."
  default     = []
}
