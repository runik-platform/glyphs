{{/*Runik Platform
Copyright (C) 2025 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

netbird.dnsSettings creates the singleton NetBirdDNSSettings
(netbird.io/v1alpha1) for account-wide DNS policy. The complementary operator
requires metadata.name=default, so the rendered resource always uses that
name. An empty list explicitly enables NetBird DNS management for all peers.

Optional:
- $definition.disabledManagementGroupRefs: explicit list of group names
- $definition.groupsSelector: runicIndexer selector (type: netbird-group)
- $definition.namespace

Usage: {{- include "netbird.dnsSettings" (list $root $glyph) }}
*/}}
{{- define "netbird.dnsSettings" }}
{{- $root := index . 0 -}}
{{- $definition := index . 1 }}
{{- $groupRefs := get (include "netbird.resolveRefs" (list $root (default (list) $definition.disabledManagementGroupRefs) (default (dict) $definition.groupsSelector) "netbird-group" "netbird.dnsSettings disabled-management groups") | fromJson) "refs" }}
---
apiVersion: netbird.io/v1alpha1
kind: NetBirdDNSSettings
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
  disabledManagementGroupRefs:
  {{- if $groupRefs }}
    {{- range $g := $groupRefs }}
    - {{ $g | quote }}
    {{- end }}
  {{- else }} []
  {{- end }}
{{ end }}
