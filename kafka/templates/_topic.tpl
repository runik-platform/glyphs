{{/*Runik Platform
Copyright (C) 2026 namenmalkav@gmail.com
SPDX-License-Identifier: AGPL-3.0-only
*/}}
{{- define "kafka.topic" -}}
{{- $root := index . 0 -}}
{{- $definition := index . 1 -}}
{{- $clusterRef := include "kafka.clusterRef" (list $root $definition "kafka.topic") | fromJson -}}
{{- $cluster := $clusterRef.name -}}
{{- $namespace := default $clusterRef.namespace $definition.namespace -}}
---
apiVersion: kafka.strimzi.io/v1
kind: KafkaTopic
metadata:
  name: {{ required "kafka.topic: name is required" $definition.name }}
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
spec:
  partitions: {{ default 1 $definition.partitions }}
  replicas: {{ default 1 $definition.replicas }}
  {{- with $definition.topicName }}
  topicName: {{ . | quote }}
  {{- end }}
  {{- with $definition.config }}
  config:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- printf "\n" -}}
{{- end }}
