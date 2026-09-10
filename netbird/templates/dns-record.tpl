{{/*Runik Platform
Copyright (C) 2025 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

netbird.dnsRecord creates a NetBirdDNSRecord (netbird.io/v1alpha1) inside a
NetBirdDNSZone. Can either take an explicit zoneRef or discover it via the
zoneSelector using runicIndexer with type filter `netbird-dnszone`.

Required:
- $definition.name (auto-injected)
- $definition.recordType: A | AAAA | CNAME (maps to spec.type — we cannot use
  `type` on the glyph itself because that key is consumed by the kaster dispatcher)
- $definition.content
- $definition.ttl
- one of: $definition.zoneRef | $definition.zoneSelector

Optional:
- $definition.nbName
- $definition.namespace

Usage: {{- include "netbird.dnsRecord" (list $root $glyph) }}
*/}}
{{- define "netbird.dnsRecord" }}
{{- $root := index . 0 -}}
{{- $definition := index . 1 }}
{{- $explicitZones := list -}}
{{- if $definition.zoneRef -}}{{- $explicitZones = append $explicitZones $definition.zoneRef -}}{{- end -}}
{{- $zoneRefs := get (include "netbird.resolveRefs" (list $root $explicitZones (default (dict) $definition.zoneSelector) "netbird-dnszone" "netbird.dnsRecord zones") | fromJson) "refs" -}}
{{- if not $zoneRefs -}}
{{- fail "netbird.dnsRecord: zoneRef or a zoneSelector matching netbird-dnszone is required" -}}
{{- end }}
{{- range $zone := $zoneRefs }}
---
apiVersion: netbird.io/v1alpha1
kind: NetBirdDNSRecord
metadata:
  name: {{ $definition.name }}-{{ $zone }}
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
  zoneRef: {{ $zone | quote }}
  name: {{ default $definition.name $definition.nbName | quote }}
  type: {{ required "netbird.dnsRecord: recordType is required (A|AAAA|CNAME)" $definition.recordType | quote }}
  content: {{ required "netbird.dnsRecord: content is required" $definition.content | quote }}
  ttl: {{ required "netbird.dnsRecord: ttl is required" $definition.ttl }}
{{- end }}
{{- end }}
