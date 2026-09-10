{{/*Runik Platform
Copyright (C) 2023 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only
*/}}
{{- define "crossplane.provider" }}
{{- $root := index . 0 -}}
{{- $glyphDefinition := index . 1}}
{{- $providerPackage := default $glyphDefinition.providerURL $glyphDefinition.package }}
---
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: {{ default (include "common.name" $root) $glyphDefinition.name }}
  labels:
    {{- include "common.all.labels" $root | nindent 4 }}
    {{- with $glyphDefinition.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- with $glyphDefinition.annotations }}
  annotations:
    {{- include "common.annotations" $root | nindent 4 }}
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  package: {{ $providerPackage | quote }}
{{- end }}
