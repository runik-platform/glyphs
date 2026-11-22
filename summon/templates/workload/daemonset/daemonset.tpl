{{/*Runik Platform
Copyright (C) 2023 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only
*/}}
{{- define "summon.workload.daemonset" -}}
{{- $root := . -}}
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: {{ include "common.name" $root }}
  {{- include "summon.resourceMetadata" (list $root $root.Values.workload.labels $root.Values.workload.annotations) | nindent 2 }}
spec:
  selector:
    matchLabels:
      {{- include "common.selectorLabels" $root | nindent 6 }}
  {{- with $root.Values.workload.updateStrategy }}
  updateStrategy:
    {{- toYaml . | nindent 4 }}
  {{- end }}
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
{{- end -}}
