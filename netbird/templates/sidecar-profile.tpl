{{/*Runik Platform
Copyright (C) 2025 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

netbird.sidecarProfile creates a native SidecarProfile
(netbird.io/v1alpha1). Matching pods receive a NetBird client using a SetupKey
from the same namespace.

Usage: {{- include "netbird.sidecarProfile" (list $root $glyph) }}
*/}}
{{- define "netbird.sidecarProfile" }}
{{- $root := index . 0 -}}
{{- $definition := index . 1 }}
{{- $setupKeyRef := required "netbird.sidecarProfile: setupKeyRef is required" $definition.setupKeyRef }}
---
apiVersion: netbird.io/v1alpha1
kind: SidecarProfile
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
  setupKeyRef:
    name: {{ required "netbird.sidecarProfile: setupKeyRef.name is required" $setupKeyRef.name | quote }}
  {{- with $definition.podSelector }}
  podSelector:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $definition.injectionMode }}
  injectionMode: {{ . | quote }}
  {{- end }}
  {{- with $definition.extraDNSLabels }}
  extraDNSLabels:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $definition.containerOverride }}
  containerOverride:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
