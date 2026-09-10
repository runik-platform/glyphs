{{/*Runik Platform
Copyright (C) 2026 namenmalkav@gmail.com
SPDX-License-Identifier: AGPL-3.0-only
*/}}
{{- define "kafka.user" -}}
{{- $root := index . 0 -}}
{{- $definition := index . 1 -}}
{{- $clusterRef := include "kafka.clusterRef" (list $root $definition "kafka.user") | fromJson -}}
{{- $cluster := $clusterRef.name -}}
{{- $namespace := default $clusterRef.namespace $definition.namespace -}}
{{- $hasSpec := or (hasKey $definition "authentication") (hasKey $definition "authorization") (hasKey $definition "quotas") (hasKey $definition "template") -}}
---
apiVersion: kafka.strimzi.io/v1
kind: KafkaUser
metadata:
  name: {{ required "kafka.user: name is required" $definition.name }}
  {{- with $namespace }}
  namespace: {{ . }}
  {{- end }}
  labels:
    {{- include "common.all.labels" $root | nindent 4 }}
    {{- with $definition.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
    strimzi.io/cluster: {{ $cluster }}
  {{- with $definition.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- if $hasSpec }}
spec:
  {{- with $definition.authentication }}
  authentication:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $definition.authorization }}
  authorization:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $definition.quotas }}
  quotas:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $definition.template }}
  template:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- else }}
spec: {}
{{- end }}
{{- printf "\n" -}}
{{- end }}
