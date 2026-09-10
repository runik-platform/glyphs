{{/*Runik Platform
Copyright (C) 2026 namenmalkav@gmail.com
SPDX-License-Identifier: AGPL-3.0-only
*/}}
{{- define "kafka.connect" -}}
{{- $root := index . 0 -}}
{{- $definition := index . 1 -}}
{{- $name := required "kafka.connect: name is required" $definition.name -}}
{{- $annotations := deepCopy (default (dict) $definition.annotations) -}}
{{- if or (not (hasKey $definition "useConnectorResources")) $definition.useConnectorResources -}}
{{- $_ := set $annotations "strimzi.io/use-connector-resources" "true" -}}
{{- end }}
---
apiVersion: kafka.strimzi.io/v1
kind: KafkaConnect
metadata:
  name: {{ $name }}
  {{- with $definition.namespace }}
  namespace: {{ . }}
  {{- end }}
  labels:
    {{- include "common.all.labels" $root | nindent 4 }}
    {{- with $definition.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- with $annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  replicas: {{ if hasKey $definition "replicas" }}{{ $definition.replicas }}{{ else }}1{{ end }}
  bootstrapServers: {{ required "kafka.connect: bootstrapServers is required" $definition.bootstrapServers | quote }}
  groupId: {{ default $name $definition.groupId | quote }}
  configStorageTopic: {{ default (printf "__%s-config" $name) $definition.configStorageTopic | quote }}
  offsetStorageTopic: {{ default (printf "__%s-offset" $name) $definition.offsetStorageTopic | quote }}
  statusStorageTopic: {{ default (printf "__%s-status" $name) $definition.statusStorageTopic | quote }}
  {{- with $definition.version }}
  version: {{ . | quote }}
  {{- end }}
  {{- with $definition.config }}
  config:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $definition.authentication }}
  authentication:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $definition.tls }}
  tls:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $definition.build }}
  build:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $definition.plugins }}
  plugins:
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
  {{- with $definition.jmxOptions }}
  jmxOptions:
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
