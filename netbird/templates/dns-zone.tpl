{{/*Runik Platform
Copyright (C) 2025 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

netbird.dnsZone creates a NetBirdDNSZone (netbird.io/v1alpha1) — a private
DNS zone served by NetBird peers. Referenced by netbird.dnsRecord via zoneRef.

Required:
- $definition.name (auto-injected)
- $definition.domain: FQDN of the zone (e.g. internal.example.com)

Optional:
- $definition.nbName: override NetBird-side name
- $definition.enabled (default true on operator side)
- $definition.enableSearchDomain
- $definition.distributionGroupRefs: explicit list of group names
- $definition.groupsSelector: runicIndexer selector to discover groups (type: netbird-group)

Lexicon: declare an entry with `type: netbird-dnszone` in appendix.lexicon
to let dnsRecord discover this zone via selector.

Usage: {{- include "netbird.dnsZone" (list $root $glyph) }}
*/}}
{{- define "netbird.dnsZone" }}
{{- $root := index . 0 -}}
{{- $definition := index . 1 }}
{{- $groupRefs := get (include "netbird.resolveRefs" (list $root (default (list) $definition.distributionGroupRefs) (default (dict) $definition.groupsSelector) "netbird-group" "netbird.dnsZone distribution groups") | fromJson) "refs" }}
---
apiVersion: netbird.io/v1alpha1
kind: NetBirdDNSZone
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
  domain: {{ required "netbird.dnsZone: domain is required" $definition.domain | quote }}
  {{- if hasKey $definition "enabled" }}
  enabled: {{ $definition.enabled }}
  {{- end }}
  {{- if hasKey $definition "enableSearchDomain" }}
  enableSearchDomain: {{ $definition.enableSearchDomain }}
  {{- end }}
  {{- if $groupRefs }}
  distributionGroupRefs:
    {{- range $g := $groupRefs }}
    - {{ $g | quote }}
    {{- end }}
  {{- end }}
{{- end }}
