{{/*Runik Platform
Copyright (C) 2026  kazapeke@gmail.com
SPDX-License-Identifier: AGPL-3.0-only
*/}}
{{- define "aws.db-parameter-group" }}
{{- $root := index . 0 -}}
{{- $glyphDefinition := index . 1 }}
---
apiVersion: rds.services.k8s.aws/v1alpha1
kind: DBParameterGroup
metadata:
  name: {{ default (include "common.name" $root) $glyphDefinition.name }}
  namespace: {{ default $root.Release.Namespace $glyphDefinition.namespace }}
  labels:
    {{- include "common.all.labels" $root | nindent 4 }}
    {{- with $glyphDefinition.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  annotations:
    services.k8s.aws/adoption-policy: {{ default "adopt" $glyphDefinition.adoptionPolicy }}
    {{- with $glyphDefinition.annotations }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  name: {{ default (include "common.name" $root) $glyphDefinition.name }}
  description: {{ default (printf "Parameter group for %s" (default (include "common.name" $root) $glyphDefinition.name)) $glyphDefinition.description | quote }}
  family: {{ default "postgres15" $glyphDefinition.family }}
  {{- with $glyphDefinition.parameters }}
  parameterOverrides:
    {{- range $key, $value := . }}
    {{ $key }}: {{ $value | quote }}
    {{- end }}
  {{- end }}
  {{- with $glyphDefinition.tags }}
  tags:
    {{- range . }}
    - key: {{ .key }}
      value: {{ .value }}
    {{- end }}
  {{- end }}
{{- end }}
