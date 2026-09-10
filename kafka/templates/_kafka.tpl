{{/*Runik Platform
Copyright (C) 2026 namenmalkav@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

kafka.kafka renders one Strimzi Kafka resource. Node pools are independent
`type: nodePool` glyphs, just as they are independent Strimzi resources.
*/}}
{{- define "kafka.kafka" }}
{{- $root := index . 0 -}}
{{- $definition := index . 1 }}
---
apiVersion: kafka.strimzi.io/v1
kind: Kafka
metadata:
  name: {{ required "kafka.kafka: name is required" $definition.name }}
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
  kafka:
    {{- with $definition.version }}
    version: {{ . | quote }}
    {{- end }}
    {{- with $definition.metadataVersion }}
    metadataVersion: {{ . | quote }}
    {{- end }}
    {{- if $definition.listeners }}
    listeners:
      {{- toYaml $definition.listeners | nindent 6 }}
    {{- else }}
    listeners:
      - name: plain
        port: 9092
        type: internal
        tls: false
    {{- end }}
    {{- if hasKey $definition "config" }}
    config:
      {{- toYaml $definition.config | nindent 6 }}
    {{- end }}
    {{- with $definition.authorization }}
    authorization:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with $definition.brokerRackInitImage }}
    brokerRackInitImage: {{ . }}
    {{- end }}
    {{- with $definition.image }}
    image: {{ . }}
    {{- end }}
    {{- with $definition.jmxOptions }}
    jmxOptions:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with $definition.jvmOptions }}
    jvmOptions:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with $definition.livenessProbe }}
    livenessProbe:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with $definition.logging }}
    logging:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with $definition.metricsConfig }}
    metricsConfig:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with $definition.quotas }}
    quotas:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with $definition.rack }}
    rack:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with $definition.readinessProbe }}
    readinessProbe:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with $definition.template }}
    template:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with $definition.tieredStorage }}
    tieredStorage:
      {{- toYaml . | nindent 6 }}
    {{- end }}
  {{- if hasKey $definition "entityOperator" }}
  entityOperator:
    {{- toYaml $definition.entityOperator | nindent 4 }}
  {{- end }}
  {{- if hasKey $definition "kafkaExporter" }}
  kafkaExporter:
    {{- toYaml $definition.kafkaExporter | nindent 4 }}
  {{- end }}
  {{- if hasKey $definition "cruiseControl" }}
  cruiseControl:
    {{- toYaml $definition.cruiseControl | nindent 4 }}
  {{- end }}
  {{- with $definition.clusterCa }}
  clusterCa:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $definition.clientsCa }}
  clientsCa:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $definition.maintenanceTimeWindows }}
  maintenanceTimeWindows:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- printf "\n" -}}
{{- end }}
