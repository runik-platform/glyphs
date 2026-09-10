{{/*Runik Platform
Copyright (C) 2025 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

netbird.accountSettings creates the singleton NetBirdAccountSettings
(netbird.io/v1alpha1) for account-wide settings. The complementary operator
requires metadata.name=default, so the glyph key is only a Runik identifier
and the rendered Kubernetes resource is always named default.

All fields are optional. See
https://docs.netbird.io/api for semantics. Most users pass the values through
as-is; this glyph adds no opinion beyond standard metadata and group discovery.

Lexicon integration:
- $definition.trafficLogsGroupsSelector → extra.networkTrafficLogsGroupRefs
- $definition.peerExposeGroupsSelector → peerExpose.groupRefs

Selectors use runicIndexer with type filter `netbird-group`; explicit lists
remain supported (extra.networkTrafficLogsGroupRefs, peerExpose.groupRefs).

Usage: {{- include "netbird.accountSettings" (list $root $glyph) }}
*/}}
{{- define "netbird.accountSettings" }}
{{- $root := index . 0 -}}
{{- $definition := index . 1 }}
{{- $extra := default dict $definition.extra -}}
{{- $trafficRefs := get (include "netbird.resolveRefs" (list $root (default (list) $extra.networkTrafficLogsGroupRefs) (default (dict) $definition.trafficLogsGroupsSelector) "netbird-group" "netbird.accountSettings traffic-log groups") | fromJson) "refs" -}}
{{- $peerExpose := default dict $definition.peerExpose -}}
{{- $exposeRefs := get (include "netbird.resolveRefs" (list $root (default (list) $peerExpose.groupRefs) (default (dict) $definition.peerExposeGroupsSelector) "netbird-group" "netbird.accountSettings peer-expose groups") | fromJson) "refs" }}
---
apiVersion: netbird.io/v1alpha1
kind: NetBirdAccountSettings
metadata:
  name: default
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
  {{- with $definition.autoUpdate }}
  autoUpdate:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $definition.dnsDomain }}
  dnsDomain: {{ . | quote }}
  {{- end }}
  {{- with $definition.networkRange }}
  networkRange: {{ . | quote }}
  {{- end }}
  {{- if hasKey $definition "groupsPropagationEnabled" }}
  groupsPropagationEnabled: {{ $definition.groupsPropagationEnabled }}
  {{- end }}
  {{- if hasKey $definition "lazyConnectionEnabled" }}
  lazyConnectionEnabled: {{ $definition.lazyConnectionEnabled }}
  {{- end }}
  {{- if hasKey $definition "regularUsersViewBlocked" }}
  regularUsersViewBlocked: {{ $definition.regularUsersViewBlocked }}
  {{- end }}
  {{- if hasKey $definition "routingPeerDnsResolutionEnabled" }}
  routingPeerDnsResolutionEnabled: {{ $definition.routingPeerDnsResolutionEnabled }}
  {{- end }}
  {{- with $definition.peerInactivityExpiration }}
  peerInactivityExpiration:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $definition.peerLoginExpiration }}
  peerLoginExpiration:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $definition.jwtGroups }}
  jwtGroups:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- if or (hasKey $extra "networkTrafficLogsEnabled") (hasKey $extra "networkTrafficPacketCounterEnabled") (hasKey $extra "peerApprovalEnabled") (hasKey $extra "userApprovalRequired") $trafficRefs }}
  extra:
    {{- if hasKey $extra "networkTrafficLogsEnabled" }}
    networkTrafficLogsEnabled: {{ $extra.networkTrafficLogsEnabled }}
    {{- end }}
    {{- if hasKey $extra "networkTrafficPacketCounterEnabled" }}
    networkTrafficPacketCounterEnabled: {{ $extra.networkTrafficPacketCounterEnabled }}
    {{- end }}
    {{- if hasKey $extra "peerApprovalEnabled" }}
    peerApprovalEnabled: {{ $extra.peerApprovalEnabled }}
    {{- end }}
    {{- if hasKey $extra "userApprovalRequired" }}
    userApprovalRequired: {{ $extra.userApprovalRequired }}
    {{- end }}
    {{- if $trafficRefs }}
    networkTrafficLogsGroupRefs:
      {{- range $g := $trafficRefs }}
      - {{ $g | quote }}
      {{- end }}
    {{- end }}
  {{- end }}
  {{- if or (hasKey $peerExpose "enabled") $exposeRefs }}
  peerExpose:
    {{- if hasKey $peerExpose "enabled" }}
    enabled: {{ $peerExpose.enabled }}
    {{- end }}
    {{- if $exposeRefs }}
    groupRefs:
      {{- range $g := $exposeRefs }}
      - {{ $g | quote }}
      {{- end }}
    {{- end }}
  {{- end }}
{{- end }}
