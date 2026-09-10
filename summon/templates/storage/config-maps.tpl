{{/*Runik Platform
Copyright (C) 2023 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

summon.configMap creates ConfigMap resources for configuration data.
Follows standard glyph parameter pattern for consistency.

Parameters:
- $root: Chart root context (index . 0) 
- $glyphDefinition: ConfigMap configuration with structure:
  - name: ConfigMap name
  - definition: Configuration object with content

Usage: {{- include "summon.configMap" (list $root $glyph) }}
*/}}
{{- define "summon.configMap" }}
{{- $root := index . 0 }}
{{- $glyphDefinition := index . 1}}
{{- $resourceName := include "common.storage.resourceName" (list $glyphDefinition.name $glyphDefinition.definition) }}
---
kind: ConfigMap
apiVersion: v1
metadata:
  name: {{ $resourceName }}
  labels:
    {{- include "common.all.labels" $root | nindent 4 }}
    {{- with $glyphDefinition.definition.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- with $glyphDefinition.definition.annotations }}
  annotations:
    {{- include "common.annotations" $root | nindent 4 }}
    {{- toYaml . | nindent 4 }}
  {{- end }}
data:
{{- $contentType := default "file" $glyphDefinition.definition.contentType }}
{{- $keyName := $resourceName }}
{{- if eq $contentType "env" }}
  {{/* Para contentType: env, crear cada key-value como entrada separada en el ConfigMap */}}
  {{- if kindIs "map" $glyphDefinition.definition.content }}
  {{- range $key, $value := $glyphDefinition.definition.content }}
  {{ $key }}: {{ $value | quote }}
  {{- end }}
  {{- else }}
  {{/* Si contentType: env pero content es string, crear una sola entrada */}}
  {{ $keyName }}: {{ $glyphDefinition.definition.content | quote }}
  {{- end }}
  {{- else }}
  {{/* Para otros tipos (file, yaml, json, toml), crear una sola entrada con el contenido formateado */}}
  {{ $keyName }}: |
  {{- if eq $contentType "yaml" }}
    {{- $glyphDefinition.definition.content | toYaml | nindent 4 }}
  {{- else if eq $contentType "json" }}
    {{- $glyphDefinition.definition.content | toJson | nindent 4 }}
  {{- else if eq $contentType "toml" }}
    {{- $glyphDefinition.definition.content | toToml | nindent 4 }}
  {{- else }}
    {{/* Para contentType: file o default, usar content tal cual si es string, o convertir a YAML si es map */}}
    {{- if kindIs "map" $glyphDefinition.definition.content }}
      {{- $glyphDefinition.definition.content | toYaml | nindent 4 }}
    {{- else }}
      {{- $glyphDefinition.definition.content | nindent 4 }}
    {{- end }}
  {{- end }}
  {{- end }}
{{- end }}

