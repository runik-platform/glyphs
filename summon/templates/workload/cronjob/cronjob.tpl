{{/*Runik Platform
Copyright (C) 2023 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only
 */}}
{{- define "summon.workload.cronjob" -}}
{{- $root := . -}}
---
apiVersion: batch/v1
kind: CronJob
metadata:
  name: {{ include "common.name" $root }}
  {{- include "summon.resourceMetadata" (list $root $root.Values.workload.labels $root.Values.workload.annotations) | nindent 2 }}
spec:
  schedule: {{ $root.Values.workload.schedule | quote }}
  {{- if $root.Values.workload.concurrencyPolicy }}
  concurrencyPolicy: {{ $root.Values.workload.concurrencyPolicy }}
  {{- end }}
  {{- if $root.Values.workload.successfulJobsHistoryLimit }}
  successfulJobsHistoryLimit: {{ $root.Values.workload.successfulJobsHistoryLimit }}
  {{- end }}
  {{- if $root.Values.workload.failedJobsHistoryLimit }}
  failedJobsHistoryLimit: {{ $root.Values.workload.failedJobsHistoryLimit }}
  {{- end }}
  jobTemplate:
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
            {{- include "summon.pod.labels" $root | nindent 12 }}
          {{- include "summon.pod.annotations" $root | nindent 10 }}
        spec:
          serviceAccountName: {{ include "common.serviceAccountName" $root }}
          {{- if $root.Values.workload.restartPolicy }}
          restartPolicy: {{ $root.Values.workload.restartPolicy }}
          {{- else }}
          restartPolicy: OnFailure
          {{- end }}
          {{- include "summon.common.podSpec.body" $root | nindent 10 }}
{{- end -}}
