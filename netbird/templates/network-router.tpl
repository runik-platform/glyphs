{{/*Runik Platform
Copyright (C) 2025 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

netbird.networkRouter creates the native Kubernetes-workload NetworkRouter
(netbird.io/v1alpha1). The native operator owns the NetBird Network,
routing-peer group/setup key and the routing-peer Deployment. Use
netbird.accountNetworkRouter instead when an already-enrolled physical or
external peer routes an account-plane Network without creating a workload.

Required: exactly one DNS zone through dnsZoneRef.name or dnsZoneSelector
(runicIndexer type netbird-dnszone).
Optional: image, logLevel, workloadOverride and namespace.

Usage: {{- include "netbird.networkRouter" (list $root $glyph) }}
*/}}
{{- define "netbird.networkRouter" }}
{{- $root := index . 0 -}}
{{- $definition := index . 1 }}
{{- $dnsZoneRef := get (include "netbird.singleRef" (list $root $definition.dnsZoneRef (default (dict) $definition.dnsZoneSelector) "netbird-dnszone" "netbird.networkRouter DNS zone") | fromJson) "ref" }}
---
apiVersion: netbird.io/v1alpha1
kind: NetworkRouter
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
  dnsZoneRef:
    name: {{ $dnsZoneRef | quote }}
  {{- with $definition.image }}
  image: {{ . | quote }}
  {{- end }}
  {{- with $definition.logLevel }}
  logLevel: {{ . | quote }}
  {{- end }}
  {{- with $definition.workloadOverride }}
  workloadOverride:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
