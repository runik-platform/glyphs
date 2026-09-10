{{/*Runik Platform
Copyright (C) 2023 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only
 */}}
{{- define "summon.workload.deployment" -}}
{{- $root := . -}}
---
apiVersion: apps/v1
kind: Deployment
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
  {{- with $root.Values.workload.strategy }}
  strategy:
    {{- if kindIs "string" . }}
    type: {{ . }}
    {{- else }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- end }}
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
{{- end -}}
