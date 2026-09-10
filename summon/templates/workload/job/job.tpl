{{/*Runik Platform
Copyright (C) 2023 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only
 */}}
{{- define "summon.workload.job" -}}
{{- $root := . -}}
---
apiVersion: batch/v1
kind: Job
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
  {{- if $root.Values.workload.backoffLimit }}
  backoffLimit: {{ $root.Values.workload.backoffLimit }}
  {{- end }}
  {{- if $root.Values.workload.activeDeadlineSeconds }}
  activeDeadlineSeconds: {{ $root.Values.workload.activeDeadlineSeconds }}
  {{- end }}
  template:
    metadata:
      labels:
        {{- include "common.selectorLabels" $root | nindent 8 }}
      {{- include "summon.pod.annotations" $root | nindent 6 }}
    spec:
      serviceAccountName: {{ include "common.serviceAccountName" $root }}
      {{- if $root.Values.workload.restartPolicy }}
      restartPolicy: {{ $root.Values.workload.restartPolicy }}
      {{- else }}
      restartPolicy: Never
      {{- end }}
      {{- include "summon.common.podSpec.body" $root | nindent 6 }}
{{- end -}}
