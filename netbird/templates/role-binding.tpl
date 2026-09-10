{{/*Runik Platform
Copyright (C) 2025 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

netbird.roleBinding creates a NetBirdRoleBinding (netbird.io/v1alpha1). It
maps exact membership of an existing JWT-synchronized NetBird group to the
internal admin role. Owners are never modified by the complementary operator.

Required:
- one of: $definition.groupRef.name | $definition.groupSelector

Optional:
- $definition.role (defaults to admin; it is the only value supported by the CRD)
- $definition.revokeOnExit (CRD default: true)
- $definition.restoreOnDelete (CRD default: true)
- $definition.includeServiceUsers (CRD default: false)
- $definition.pollIntervalSeconds (CRD default: 60; valid range: 15-3600)

groupSelector uses runicIndexer with type filter `netbird-group`.

Usage: {{- include "netbird.roleBinding" (list $root $glyph) }}
*/}}
{{- define "netbird.roleBinding" }}
{{- $root := index . 0 -}}
{{- $definition := index . 1 }}
{{- $groupRef := get (include "netbird.singleRef" (list $root $definition.groupRef (default (dict) $definition.groupSelector) "netbird-group" "netbird.roleBinding group") | fromJson) "ref" }}
---
apiVersion: netbird.io/v1alpha1
kind: NetBirdRoleBinding
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
  groupRef:
    name: {{ $groupRef | quote }}
  role: {{ default "admin" $definition.role | quote }}
  {{- if hasKey $definition "revokeOnExit" }}
  revokeOnExit: {{ $definition.revokeOnExit }}
  {{- end }}
  {{- if hasKey $definition "restoreOnDelete" }}
  restoreOnDelete: {{ $definition.restoreOnDelete }}
  {{- end }}
  {{- if hasKey $definition "includeServiceUsers" }}
  includeServiceUsers: {{ $definition.includeServiceUsers }}
  {{- end }}
  {{- if hasKey $definition "pollIntervalSeconds" }}
  pollIntervalSeconds: {{ $definition.pollIntervalSeconds }}
  {{- end }}
{{- end }}
