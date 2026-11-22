{{/*Runik Platform
Copyright (C) 2023 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only
 */}}
{{- define "summon.autoscaling" }}
{{- $root := . }}
{{- if $root.Values.autoscaling.enabled }}
{{- $mode := "hpa" }}
{{- if and (hasKey $root.Values.autoscaling "mode") (ne $root.Values.autoscaling.mode nil) }}
{{- $mode = $root.Values.autoscaling.mode }}
{{- end }}
{{- if not (has $mode (list "hpa" "external")) }}
{{- fail (printf "unsupported autoscaling.mode %q: expected hpa or external" $mode) }}
{{- end }}
{{- if eq $mode "hpa" }}
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "common.name" $root }}
  {{- include "summon.resourceMetadata" (list $root $root.Values.autoscaling.labels $root.Values.autoscaling.annotations) | nindent 2 }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ template "common.name" $root }}
  minReplicas: {{ default $root.Values.autoscaling.minReplicas $root.Values.workload.replicas }}
  maxReplicas: {{ $root.Values.autoscaling.maxReplicas }}
  metrics:
    {{- if $root.Values.autoscaling.targetCPUUtilizationPercentage }}
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ $root.Values.autoscaling.targetCPUUtilizationPercentage }}
    {{- end }}
    {{- if $root.Values.autoscaling.targetMemoryUtilizationPercentage }}
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: {{ $root.Values.autoscaling.targetMemoryUtilizationPercentage }}
    {{- end }}
{{- end -}}
{{- end -}}
{{- end -}}
