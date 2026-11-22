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
  {{- include "summon.resourceMetadata" (list $root $root.Values.workload.labels $root.Values.workload.annotations) | nindent 2 }}
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
        {{- include "summon.pod.labels" $root | nindent 8 }}
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
