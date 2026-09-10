{{/*Runik Platform
Copyright (C) 2025 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

netbird.accountNetworkRouter creates a complementary NetBirdNetworkRouter. It
attaches an existing NetBird peer or peer group to an account-plane Network and
never creates a Kubernetes workload.

Network: networkRef XOR networkSelector (netbird-network), exactly one result.
Router: peerRef/peerSelector (netbird-peer) XOR
        peerGroupRefs/peerGroupsSelector (netbird-group).
*/}}
{{- define "netbird.accountNetworkRouter" }}
{{- $root := index . 0 -}}
{{- $definition := index . 1 -}}
{{- $networkRef := get (include "netbird.singleRef" (list $root $definition.networkRef (default (dict) $definition.networkSelector) "netbird-network" "netbird.accountNetworkRouter network") | fromJson) "ref" -}}
{{- $peerRefs := list -}}
{{- if or $definition.peerRef $definition.peerSelector -}}
  {{- $peerRef := get (include "netbird.singleRef" (list $root $definition.peerRef (default (dict) $definition.peerSelector) "netbird-peer" "netbird.accountNetworkRouter peer") | fromJson) "ref" -}}
  {{- $peerRefs = list $peerRef -}}
{{- end -}}
{{- $peerGroupRefs := get (include "netbird.resolveRefs" (list $root (default (list) $definition.peerGroupRefs) (default (dict) $definition.peerGroupsSelector) "netbird-group" "netbird.accountNetworkRouter peer groups") | fromJson) "refs" -}}
{{- if and $peerRefs $peerGroupRefs -}}{{- fail "netbird.accountNetworkRouter: peer and peer groups are mutually exclusive" -}}{{- end -}}
{{- if and (not $peerRefs) (not $peerGroupRefs) -}}{{- fail "netbird.accountNetworkRouter: one peer or at least one peer group is required" -}}{{- end -}}
---
apiVersion: netbird.io/v1alpha1
kind: NetBirdNetworkRouter
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
  {{- if $peerRefs }}
  peerRef: {{ index $peerRefs 0 | quote }}
  {{- else }}
  peerGroupRefs:
    {{- range $ref := $peerGroupRefs }}
    - {{ $ref | quote }}
    {{- end }}
  {{- end }}
  enabled: {{ if hasKey $definition "enabled" }}{{ $definition.enabled }}{{ else }}true{{ end }}
  masquerade: {{ if hasKey $definition "masquerade" }}{{ $definition.masquerade }}{{ else }}true{{ end }}
  metric: {{ if hasKey $definition "metric" }}{{ $definition.metric }}{{ else }}9999{{ end }}
{{- end }}
