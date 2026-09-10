{{/*Runik Platform
Copyright (C) 2025 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

netbird.postureCheck creates a NetBirdPostureCheck (netbird.io/v1alpha1) — a
rule evaluated against peers (OS version, NetBird client version, geoloc, ...).

Required:
- $definition.name (auto-injected)
- $definition.description

Optional:
- $definition.nbName
- $definition.checks: object passed through verbatim. Supported sub-blocks:
    nbVersionCheck, osVersionCheck, geoLocationCheck, peerNetworkRangeCheck,
    processCheck. See the CRD schema for field details.

Usage: {{- include "netbird.postureCheck" (list $root $glyph) }}
*/}}
{{- define "netbird.postureCheck" }}
{{- $root := index . 0 -}}
{{- $definition := index . 1 }}
---
apiVersion: netbird.io/v1alpha1
kind: NetBirdPostureCheck
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
  description: {{ required "netbird.postureCheck: description is required" $definition.description | quote }}
  {{- with $definition.checks }}
  checks:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
