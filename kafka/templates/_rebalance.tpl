{{/*Runik Platform
Copyright (C) 2026 namenmalkav@gmail.com
SPDX-License-Identifier: AGPL-3.0-only
*/}}
{{- define "kafka.rebalance" -}}
{{- $root := index . 0 -}}
{{- $definition := index . 1 -}}
{{- $clusterRef := include "kafka.clusterRef" (list $root $definition "kafka.rebalance") | fromJson -}}
{{- $cluster := $clusterRef.name -}}
{{- $namespace := default $clusterRef.namespace $definition.namespace -}}
---
apiVersion: kafka.strimzi.io/v1
kind: KafkaRebalance
metadata:
  name: {{ required "kafka.rebalance: name is required" $definition.name }}
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
  {{- with $definition.mode }}
  mode: {{ . }}
  {{- end }}
  {{- with $definition.brokers }}
  brokers:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $definition.goals }}
  goals:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- if hasKey $definition "skipHardGoalCheck" }}
  skipHardGoalCheck: {{ $definition.skipHardGoalCheck }}
  {{- end }}
  {{- if hasKey $definition "rebalanceDisk" }}
  rebalanceDisk: {{ $definition.rebalanceDisk }}
  {{- end }}
  {{- with $definition.moveReplicasOffVolumes }}
  moveReplicasOffVolumes:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $definition.excludedTopics }}
  excludedTopics: {{ . | quote }}
  {{- end }}
  {{- with $definition.replicaMovementStrategies }}
  replicaMovementStrategies:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $definition.concurrentIntraBrokerPartitionMovements }}
  concurrentIntraBrokerPartitionMovements: {{ . }}
  {{- end }}
  {{- with $definition.concurrentLeaderMovements }}
  concurrentLeaderMovements: {{ . }}
  {{- end }}
  {{- with $definition.concurrentPartitionMovementsPerBroker }}
  concurrentPartitionMovementsPerBroker: {{ . }}
  {{- end }}
  {{- with $definition.replicationThrottle }}
  replicationThrottle: {{ . }}
  {{- end }}
{{- printf "\n" -}}
{{- end }}
