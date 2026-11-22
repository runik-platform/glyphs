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
  {{- include "summon.resourceMetadata" (list $root $root.Values.workload.labels $root.Values.workload.annotations) | nindent 2 }}
spec:
  {{- if not $root.Values.autoscaling.enabled }}
  replicas: {{ if hasKey $root.Values.workload "replicas" }}{{ $root.Values.workload.replicas }}{{ else }}1{{ end }}
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
        {{- include "summon.pod.labels" $root | nindent 8 }}
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
