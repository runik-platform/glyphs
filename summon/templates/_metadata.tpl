{{/*Runik Platform
Copyright (C) 2023 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only
*/}}

{{/* Render labels and annotations for a Summon resource.
     Parameters: (list $root $resourceLabels $resourceAnnotations). */}}
{{- define "summon.resourceMetadata" -}}
{{- $root := index . 0 -}}
{{- $resourceLabels := default dict (index . 1) -}}
{{- $resourceAnnotations := default dict (index . 2) -}}
{{- $customLabels := default dict ($root.Values.labels).custom -}}
{{- $generatedLabels := include "common.all.labels" $root -}}
labels:
{{- if or $customLabels $resourceLabels }}
  {{- $labels := mergeOverwrite ($generatedLabels | fromYaml) (deepCopy $customLabels) $resourceLabels }}
  {{- toYaml $labels | nindent 2 }}
{{- else }}
  {{- $generatedLabels | nindent 2 }}
{{- end }}
{{- if or $root.Values.annotations $resourceAnnotations }}
  {{- $annotations := include "common.annotations.map" (list $root $resourceAnnotations dict) | fromJson }}
annotations:
  {{- toYaml $annotations | nindent 2 }}
{{- end }}
{{- end -}}

{{- define "summon.pod.labels" -}}
{{- $selectors := include "common.selectorLabels" . -}}
{{- $customLabels := default dict (.Values.labels).custom -}}
{{- if or $customLabels .Values.podLabels -}}
  {{- /* Selector keys must match the workload and Service selectors. */ -}}
  {{- $labels := mergeOverwrite (deepCopy $customLabels) (default dict .Values.podLabels) ($selectors | fromYaml) -}}
  {{- toYaml $labels -}}
{{- else -}}
  {{- $selectors -}}
{{- end -}}
{{- end -}}
