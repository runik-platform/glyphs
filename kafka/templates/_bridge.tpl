{{/*Runik Platform
Copyright (C) 2026 namenmalkav@gmail.com
SPDX-License-Identifier: AGPL-3.0-only
*/}}
{{- define "kafka.bridge" -}}
{{- $root := index . 0 -}}
{{- $definition := index . 1 -}}
---
apiVersion: kafka.strimzi.io/v1
kind: KafkaBridge
metadata:
  name: {{ required "kafka.bridge: name is required" $definition.name }}
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
  replicas: {{ if hasKey $definition "replicas" }}{{ $definition.replicas }}{{ else }}1{{ end }}
  bootstrapServers: {{ required "kafka.bridge: bootstrapServers is required" $definition.bootstrapServers | quote }}
  http:
    {{- toYaml (default (dict "port" 8080) $definition.http) | nindent 4 }}
  {{- with $definition.authentication }}
  authentication:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $definition.tls }}
  tls:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $definition.adminClient }}
  adminClient:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $definition.consumer }}
  consumer:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $definition.producer }}
  producer:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $definition.config }}
  config:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $definition.image }}
  image: {{ . }}
  {{- end }}
  {{- with $definition.resources }}
  resources:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $definition.jvmOptions }}
  jvmOptions:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $definition.logging }}
  logging:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $definition.metricsConfig }}
  metricsConfig:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $definition.rack }}
  rack:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $definition.tracing }}
  tracing:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $definition.template }}
  template:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $definition.livenessProbe }}
  livenessProbe:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $definition.readinessProbe }}
  readinessProbe:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $definition.clientRackInitImage }}
  clientRackInitImage: {{ . }}
  {{- end }}
{{- printf "\n" -}}
{{- end }}
