{{/*Runik Platform
Copyright (C) 2025 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

netbird.route creates the legacy NetBirdRoute (netbird.io/v1alpha1). Prefer
netbird.accountNetwork + accountNetworkResource + accountNetworkRouter for
site/service access. Keep this low-level glyph for domain routes, migration of
existing routes and advanced cases. For 0.0.0.0/0 use netbird.exitNode, which
also emits the ICMP peer-access policy required by NetBird.

Required:
- $definition.name (auto-injected)
- $definition.description
- $definition.networkId (NetBird-side route/network ID string)
- one of: $definition.network (CIDR) | $definition.domains (list of FQDN)

Optional (mutually exclusive: peerRef vs peerGroupRefs):
- $definition.peerRef | $definition.peerSelector (type `netbird-peer`)
- $definition.peerGroupRefs | $definition.peerGroupsSelector (type `netbird-group`)

- $definition.groupRefs | $definition.groupsSelector  (distribution, `netbird-group`)
- $definition.accessControlGroupRefs | $definition.accessControlSelector (`netbird-group`)
- $definition.enabled, $definition.masquerade, $definition.metric, $definition.keepRoute,
  $definition.skipAutoApply

Usage: {{- include "netbird.route" (list $root $glyph) }}
*/}}
{{- define "netbird.route" }}
{{- $root := index . 0 -}}
{{- $definition := index . 1 }}
{{- $peerRef := "" -}}
{{- if or $definition.peerRef $definition.peerSelector -}}
  {{- $peerRef = get (include "netbird.singleRef" (list $root $definition.peerRef (default (dict) $definition.peerSelector) "netbird-peer" "netbird.route peer") | fromJson) "ref" -}}
{{- end -}}
{{- $peerGroups := get (include "netbird.resolveRefs" (list $root (default (list) $definition.peerGroupRefs) (default (dict) $definition.peerGroupsSelector) "netbird-group" "netbird.route peer groups") | fromJson) "refs" -}}
{{- $dist := get (include "netbird.resolveRefs" (list $root (default (list) $definition.groupRefs) (default (dict) $definition.groupsSelector) "netbird-group" "netbird.route distribution groups") | fromJson) "refs" -}}
{{- $acl := get (include "netbird.resolveRefs" (list $root (default (list) $definition.accessControlGroupRefs) (default (dict) $definition.accessControlSelector) "netbird-group" "netbird.route access-control groups") | fromJson) "refs" -}}
{{- if and $peerRef $peerGroups -}}{{- fail "netbird.route: peerRef/peerSelector and peerGroupRefs/peerGroupsSelector are mutually exclusive" -}}{{- end -}}
{{- if and $definition.network $definition.domains -}}{{- fail "netbird.route: network and domains are mutually exclusive" -}}{{- end -}}
{{- if and (not $definition.network) (not $definition.domains) -}}{{- fail "netbird.route: network or domains is required" -}}{{- end }}
---
apiVersion: netbird.io/v1alpha1
kind: NetBirdRoute
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
  description: {{ required "netbird.route: description is required" $definition.description | quote }}
  networkId: {{ required "netbird.route: networkId is required" $definition.networkId | quote }}
  {{- with $definition.network }}
  network: {{ . | quote }}
  {{- end }}
  {{- with $definition.domains }}
  domains:
    {{- range $d := . }}
    - {{ $d | quote }}
    {{- end }}
  {{- end }}
  {{- with $peerRef }}
  peerRef: {{ . | quote }}
  {{- end }}
  {{- if $peerGroups }}
  peerGroupRefs:
    {{- range $g := $peerGroups }}
    - {{ $g | quote }}
    {{- end }}
  {{- end }}
  {{- if $dist }}
  groupRefs:
    {{- range $g := $dist }}
    - {{ $g | quote }}
    {{- end }}
  {{- end }}
  {{- if $acl }}
  accessControlGroupRefs:
    {{- range $g := $acl }}
    - {{ $g | quote }}
    {{- end }}
  {{- end }}
  {{- if hasKey $definition "enabled" }}
  enabled: {{ $definition.enabled }}
  {{- end }}
  {{- if hasKey $definition "masquerade" }}
  masquerade: {{ $definition.masquerade }}
  {{- end }}
  {{- if hasKey $definition "keepRoute" }}
  keepRoute: {{ $definition.keepRoute }}
  {{- end }}
  {{- if hasKey $definition "skipAutoApply" }}
  skipAutoApply: {{ $definition.skipAutoApply }}
  {{- end }}
  {{- if hasKey $definition "metric" }}
  metric: {{ $definition.metric }}
  {{- end }}
{{- end }}
