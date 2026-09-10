{{/*Runik Platform
Copyright (C) 2026 namenmalkav@gmail.com
SPDX-License-Identifier: AGPL-3.0-only
*/}}
{{- define "kafka.nodePool" -}}
{{- $root := index . 0 -}}
{{- $definition := index . 1 -}}
{{- $clusterRef := include "kafka.clusterRef" (list $root $definition "kafka.nodePool") | fromJson -}}
{{- $cluster := $clusterRef.name -}}
{{- $namespace := default $clusterRef.namespace $definition.namespace -}}
---
apiVersion: kafka.strimzi.io/v1
kind: KafkaNodePool
metadata:
  name: {{ required "kafka.nodePool: name is required" $definition.name }}
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
  replicas: {{ if hasKey $definition "replicas" }}{{ $definition.replicas }}{{ else }}1{{ end }}
  roles:
    {{- toYaml (default (list "controller" "broker") $definition.roles) | nindent 4 }}
  storage:
    {{- toYaml (default (dict "type" "ephemeral") $definition.storage) | nindent 4 }}
  {{- with $definition.resources }}
  resources:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $definition.jvmOptions }}
  jvmOptions:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $definition.template }}
  template:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- printf "\n" -}}
{{- end }}
