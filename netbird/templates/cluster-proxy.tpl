{{/*Runik Platform
Copyright (C) 2025 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

netbird.clusterProxy creates a native ClusterProxy (netbird.io/v1alpha1) that
exposes the Kubernetes API through a NetBird peer. Impersonation RBAC for its
service account remains the spell author's responsibility.

Usage: {{- include "netbird.clusterProxy" (list $root $glyph) }}
*/}}
{{- define "netbird.clusterProxy" }}
{{- $root := index . 0 -}}
{{- $definition := index . 1 }}
{{- $explicitGroups := list -}}
{{- range $group := (default (list) $definition.groups) -}}
  {{- if kindIs "map" $group -}}
    {{- $explicitGroups = append $explicitGroups (required "netbird.clusterProxy: groups[].name is required" $group.name) -}}
  {{- else -}}
    {{- $explicitGroups = append $explicitGroups $group -}}
  {{- end -}}
{{- end -}}
{{- $groups := get (include "netbird.resolveRefs" (list $root $explicitGroups (default (dict) $definition.groupsSelector) "netbird-group" "netbird.clusterProxy groups") | fromJson) "refs" }}
---
apiVersion: netbird.io/v1alpha1
kind: ClusterProxy
metadata:
  name: {{ $definition.name }}
  {{- with $definition.namespace }}
  namespace: {{ . }}
  {{- end }}
  labels:
    {{- include "common.all.labels" $root | nindent 4 }}
    {{- with $definition.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- with $definition.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  clusterName: {{ required "netbird.clusterProxy: clusterName is required" $definition.clusterName | quote }}
  apiServer: {{ default "https://kubernetes.default.svc.cluster.local/" $definition.apiServer | quote }}
  serviceAccountName: {{ required "netbird.clusterProxy: serviceAccountName is required" $definition.serviceAccountName | quote }}
  {{- if $groups }}
  groups:
    {{- range $group := $groups }}
    - name: {{ $group | quote }}
    {{- end }}
  {{- end }}
{{- end }}
