{{/*Runik Platform
Copyright (C) 2025 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

netbird.networkResource creates a native Kubernetes-workload NetworkResource
(netbird.io/v1alpha1). It exposes a ClusterIP Service and creates its A record
in the NetworkRouter's DNS zone. Use netbird.accountNetworkResource for an
arbitrary IP, CIDR or domain that is not a Kubernetes Service.

Required: networkRouterRef.name/namespace and serviceRef.name.
Optional: groups, groupsSelector and namespace.

Usage: {{- include "netbird.networkResource" (list $root $glyph) }}
*/}}
{{- define "netbird.networkResource" }}
{{- $root := index . 0 -}}
{{- $definition := index . 1 }}
{{- $router := required "netbird.networkResource: networkRouterRef is required" $definition.networkRouterRef -}}
{{- $service := required "netbird.networkResource: serviceRef is required" $definition.serviceRef -}}
{{- $explicitGroups := list -}}
{{- range $group := (default (list) $definition.groups) -}}
  {{- if kindIs "map" $group -}}
    {{- $explicitGroups = append $explicitGroups (required "netbird.networkResource: groups[].name is required" $group.name) -}}
  {{- else -}}
    {{- $explicitGroups = append $explicitGroups $group -}}
  {{- end -}}
{{- end -}}
{{- $groups := get (include "netbird.resolveRefs" (list $root $explicitGroups (default (dict) $definition.groupsSelector) "netbird-group" "netbird.networkResource groups") | fromJson) "refs" }}
---
apiVersion: netbird.io/v1alpha1
kind: NetworkResource
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
  networkRouterRef:
    name: {{ required "netbird.networkResource: networkRouterRef.name is required" $router.name | quote }}
    namespace: {{ required "netbird.networkResource: networkRouterRef.namespace is required" $router.namespace | quote }}
  serviceRef:
    name: {{ required "netbird.networkResource: serviceRef.name is required" $service.name | quote }}
  {{- if $groups }}
  groups:
    {{- range $group := $groups }}
    - name: {{ $group | quote }}
    {{- end }}
  {{- end }}
{{- end }}
