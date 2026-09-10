{{/*Runik Platform
Copyright (C) 2026 namenmalkav@gmail.com
SPDX-License-Identifier: AGPL-3.0-only
*/}}
{{- define "kafka.mirrorMaker2" -}}
{{- $root := index . 0 -}}
{{- $definition := index . 1 -}}
{{- $name := required "kafka.mirrorMaker2: name is required" $definition.name -}}
{{- $target := required "kafka.mirrorMaker2: target is required" $definition.target }}
---
apiVersion: kafka.strimzi.io/v1
kind: KafkaMirrorMaker2
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
  {{- with $definition.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  replicas: {{ if hasKey $definition "replicas" }}{{ $definition.replicas }}{{ else }}1{{ end }}
  {{- with $definition.version }}
  version: {{ . | quote }}
  {{- end }}
  target:
    alias: {{ required "kafka.mirrorMaker2: target.alias is required" $target.alias | quote }}
    bootstrapServers: {{ required "kafka.mirrorMaker2: target.bootstrapServers is required" $target.bootstrapServers | quote }}
    groupId: {{ default $name $target.groupId | quote }}
    configStorageTopic: {{ default (printf "__%s-config" $name) $target.configStorageTopic | quote }}
    offsetStorageTopic: {{ default (printf "__%s-offset" $name) $target.offsetStorageTopic | quote }}
    statusStorageTopic: {{ default (printf "__%s-status" $name) $target.statusStorageTopic | quote }}
    {{- with $target.config }}
    config:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with $target.authentication }}
    authentication:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with $target.tls }}
    tls:
      {{- toYaml . | nindent 6 }}
    {{- end }}
  mirrors:
    {{- toYaml (required "kafka.mirrorMaker2: mirrors is required" $definition.mirrors) | nindent 4 }}
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
