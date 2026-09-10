{{/*Runik Platform
Copyright (C) 2025 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

netbird.accountNetworkResource creates a complementary
NetBirdNetworkResource for an arbitrary external IP, prefix, CIDR, domain or
wildcard domain. Unlike netbird.networkResource, it does not reference a
Kubernetes Service.

Network resolution accepts networkRef or networkSelector (netbird-network).
Resource group resolution combines groupRefs and groupsSelector
(netbird-group).
*/}}
{{- define "netbird.accountNetworkResource" }}
{{- $root := index . 0 -}}
{{- $definition := index . 1 -}}
{{- $networkRef := get (include "netbird.singleRef" (list $root $definition.networkRef (default (dict) $definition.networkSelector) "netbird-network" "netbird.accountNetworkResource network") | fromJson) "ref" -}}
{{- $groupRefs := get (include "netbird.resolveRefs" (list $root (default (list) $definition.groupRefs) (default (dict) $definition.groupsSelector) "netbird-group" "netbird.accountNetworkResource groups") | fromJson) "refs" }}
---
apiVersion: netbird.io/v1alpha1
kind: NetBirdNetworkResource
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
  networkRef:
    name: {{ $networkRef | quote }}
  name: {{ default $definition.name $definition.nbName | quote }}
  description: {{ default "" $definition.description | quote }}
  address: {{ required "netbird.accountNetworkResource: address is required" $definition.address | quote }}
  enabled: {{ if hasKey $definition "enabled" }}{{ $definition.enabled }}{{ else }}true{{ end }}
  {{- if $groupRefs }}
  groupRefs:
    {{- range $ref := $groupRefs }}
    - {{ $ref | quote }}
    {{- end }}
  {{- end }}
{{- end }}
