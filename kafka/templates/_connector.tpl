{{/*Runik Platform
Copyright (C) 2026 namenmalkav@gmail.com
SPDX-License-Identifier: AGPL-3.0-only
*/}}
{{- define "kafka.connector" -}}
{{- $root := index . 0 -}}
{{- $definition := index . 1 -}}
{{- $connectCluster := required "kafka.connector: connectCluster is required" $definition.connectCluster -}}
---
apiVersion: kafka.strimzi.io/v1
kind: KafkaConnector
metadata:
  name: {{ required "kafka.connector: name is required" $definition.name }}
  {{- with $definition.namespace }}
  namespace: {{ . }}
  {{- end }}
  labels:
    {{- include "common.all.labels" $root | nindent 4 }}
    {{- with $definition.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
    strimzi.io/cluster: {{ $connectCluster }}
  {{- with $definition.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  class: {{ required "kafka.connector: class is required" $definition.class | quote }}
  tasksMax: {{ default 1 $definition.tasksMax }}
  config:
    {{- toYaml (default (dict) $definition.config) | nindent 4 }}
  {{- with $definition.version }}
  version: {{ . | quote }}
  {{- end }}
  {{- with $definition.autoRestart }}
  autoRestart:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $definition.state }}
  state: {{ . }}
  {{- end }}
  {{- with $definition.listOffsets }}
  listOffsets:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $definition.alterOffsets }}
  alterOffsets:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- printf "\n" -}}
{{- end }}
