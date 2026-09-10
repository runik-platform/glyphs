{{/*Runik Platform
Copyright (C) 2023 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

workflow.template renders an already-resolved Argo WorkflowTemplate. It owns
only the Kubernetes resource envelope; composition remains with its caller.

Parameters (index . 1):
  name          resource name
  namespace     namespace override                         [optional]
  clusterScope  render ClusterWorkflowTemplate             [optional]
  labels        additional labels                          [optional]
  annotations   resource annotations                       [optional]
  spec          native Argo WorkflowTemplate spec
*/}}

{{- define "workflow.template" -}}
{{- $root := index . 0 -}}
{{- $definition := index . 1 -}}
{{- if not $definition.name -}}
  {{- fail "workflow.template requires name" -}}
{{- end -}}
{{- if not $definition.spec -}}
  {{- fail (printf "workflow.template '%s' requires spec" $definition.name) -}}
{{- end -}}
---
apiVersion: argoproj.io/v1alpha1
kind: {{ ternary "ClusterWorkflowTemplate" "WorkflowTemplate" (default false $definition.clusterScope) }}
metadata:
  name: {{ $definition.name }}
  {{- if not (default false $definition.clusterScope) }}
  namespace: {{ default $root.Release.Namespace $definition.namespace }}
  {{- end }}
  labels:
    {{- include "common.all.labels" $root | nindent 4 }}
    {{- with $definition.labels }}
    {{- . | toYaml | nindent 4 }}
    {{- end }}
  {{- with $definition.annotations }}
  annotations:
    {{- . | toYaml | nindent 4 }}
  {{- end }}
spec:
  {{- $definition.spec | toYaml | nindent 2 }}
{{- end -}}
