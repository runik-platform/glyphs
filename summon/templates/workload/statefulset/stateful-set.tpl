{{/*Runik Platform
Copyright (C) 2023 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

summon.workload.statefulset creates StatefulSet resources for summon workloads  
Supports both direct usage and glyph parameter pattern

Parameters:
- Direct usage: . (root context)
- Glyph usage: (list $root $glyphDefinition)
 */}}
{{- define "summon.workload.statefulset" -}}
{{- $root := . -}}
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: {{ include "common.name" $root }}
  labels:
    {{- include "common.all.labels" $root | nindent 4 }}
    {{- with $root.Values.workload.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- with $root.Values.workload.annotations }}
  annotations:
    {{- include "common.annotations" $root | nindent 4 }}
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- if not $root.Values.autoscaling.enabled }}
  replicas: {{ default 1 $root.Values.workload.replicas }}
  {{- end }}
  {{- with $root.Values.workload.podManagementPolicy }}
  podManagementPolicy: {{ . }}
  {{- end }}
  serviceName: {{ default (include "common.name" $root) $root.Values.workload.serviceName }}
  selector:
    matchLabels:
      {{- include "common.selectorLabels" $root | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "common.selectorLabels" $root | nindent 8 }}
      {{- include "summon.pod.annotations" $root | nindent 6 }}
    spec:
      {{- if $root.Values.hostNetwork }}
      hostNetwork: {{ $root.Values.hostNetwork }}
      {{- end }}
      {{- if $root.Values.dnsPolicy }}
      dnsPolicy: {{ $root.Values.dnsPolicy }}
      {{- end }}
      {{- include "summon.common.podSpec" $root | nindent 6 }}
  {{- if $root.Values.workload.volumeClaimTemplates }}
  volumeClaimTemplates:
  {{- range $name, $volume := $root.Values.workload.volumeClaimTemplates }}
    - metadata:
        name: {{ $name }}
      spec:
        {{- if $volume.storageClassName }}
        storageClassName: {{ $volume.storageClassName }}
        {{- end }}
        accessModes:
          - {{ default "ReadWriteOnce" $volume.accessModes }}
        resources:
          requests:
            storage: {{ $volume.size }}
  {{- end -}}
  {{- end -}}          
{{- end -}}
