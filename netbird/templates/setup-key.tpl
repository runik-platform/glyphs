{{/*Runik Platform
Copyright (C) 2025 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

netbird.setupKey creates a SetupKey (netbird.io/v1alpha1). The native operator
creates a reusable enrollment key and writes it to the owned Secret
`setup-key-<resource-name>` under the `setup-key` data key.

Optional fields: nbName, ephemeral, allowExtraDnsLabels, duration, autoGroups,
autoGroupsSelector and namespace.

Usage: {{- include "netbird.setupKey" (list $root $glyph) }}
*/}}
{{- define "netbird.setupKey" }}
{{- $root := index . 0 -}}
{{- $definition := index . 1 }}
{{- $explicitGroups := list -}}
{{- range $group := (default (list) $definition.autoGroups) -}}
  {{- if kindIs "map" $group -}}
    {{- $explicitGroups = append $explicitGroups (required "netbird.setupKey: autoGroups[].name is required" $group.name) -}}
  {{- else -}}
    {{- $explicitGroups = append $explicitGroups $group -}}
  {{- end -}}
{{- end -}}
{{- $autoGroups := get (include "netbird.resolveRefs" (list $root $explicitGroups (default (dict) $definition.autoGroupsSelector) "netbird-group" "netbird.setupKey auto groups") | fromJson) "refs" }}
---
apiVersion: netbird.io/v1alpha1
kind: SetupKey
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
  ephemeral: {{ if hasKey $definition "ephemeral" }}{{ $definition.ephemeral }}{{ else }}false{{ end }}
  allowExtraDnsLabels: {{ if hasKey $definition "allowExtraDnsLabels" }}{{ $definition.allowExtraDnsLabels }}{{ else }}false{{ end }}
  {{- with $definition.duration }}
  duration: {{ . | quote }}
  {{- end }}
  {{- if $autoGroups }}
  autoGroups:
    {{- range $group := $autoGroups }}
    - name: {{ $group | quote }}
    {{- end }}
  {{- end }}
{{- end }}
