{{/*Runik Platform
Copyright (C) 2025 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

netbird.nameserverGroup creates a NetBirdNameserverGroup (netbird.io/v1alpha1)
— a set of upstream DNS servers applied to peers belonging to the referenced
groups.

Required:
- $definition.name (auto-injected)
- $definition.nameservers: list of { ip, nsType: udp, port }

Optional:
- $definition.nbName, $definition.description, $definition.domains
- $definition.enabled, $definition.primary, $definition.searchDomainsEnabled
- $definition.groupRefs (explicit) or $definition.groupsSelector (runicIndexer,
  type `netbird-group`)

Usage: {{- include "netbird.nameserverGroup" (list $root $glyph) }}
*/}}
{{- define "netbird.nameserverGroup" }}
{{- $root := index . 0 -}}
{{- $definition := index . 1 }}
{{- $groups := get (include "netbird.resolveRefs" (list $root (default (list) $definition.groupRefs) (default (dict) $definition.groupsSelector) "netbird-group" "netbird.nameserverGroup groups") | fromJson) "refs" }}
---
apiVersion: netbird.io/v1alpha1
kind: NetBirdNameserverGroup
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
  name: {{ default $definition.name $definition.nbName | quote }}
  {{- with $definition.description }}
  description: {{ . | quote }}
  {{- end }}
  nameservers:
    {{- range $ns := (required "netbird.nameserverGroup: nameservers is required" $definition.nameservers) }}
    - ip: {{ required "netbird.nameserverGroup: nameservers[].ip required" $ns.ip | quote }}
      nsType: {{ default "udp" $ns.nsType | quote }}
      port: {{ default 53 $ns.port }}
    {{- end }}
  {{- with $definition.domains }}
  domains:
    {{- range $d := . }}
    - {{ $d | quote }}
    {{- end }}
  {{- end }}
  {{- if hasKey $definition "enabled" }}
  enabled: {{ $definition.enabled }}
  {{- end }}
  {{- if hasKey $definition "primary" }}
  primary: {{ $definition.primary }}
  {{- end }}
  {{- if hasKey $definition "searchDomainsEnabled" }}
  searchDomainsEnabled: {{ $definition.searchDomainsEnabled }}
  {{- end }}
  {{- if $groups }}
  groupRefs:
    {{- range $g := $groups }}
    - {{ $g | quote }}
    {{- end }}
  {{- end }}
{{- end }}
