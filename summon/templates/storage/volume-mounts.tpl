{{/*Runik Platform
Copyright (C) 2023 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only
 */}}
{{- define "summon.common.volumeMounts.items" -}}
{{- with .Values.configMaps }}
{{- include "summon.common.volumeMounts.configMaps" . }}
{{- end }}
{{- with .Values.secrets }}
{{- include "summon.common.volumeMounts.secrets" . }}
{{- end }}
{{- with .Values.volumes }}
{{- include "summon.common.volumeMounts.volumes" . }}
{{- end }}
{{- with .Values.workload.volumeClaimTemplates }}
{{- include "summon.common.volumeMounts.volumeClaimTemplates" . }}
{{- end }}
{{- end -}}

{{- define "summon.common.volumeMounts" -}}
{{- $items := include "summon.common.volumeMounts.items" . | trim -}}
{{- if $items }}
volumeMounts:
{{ $items | nindent 2 }}
{{- end }}
{{- end -}}

{{- define "summon.common.volumeMounts.volumes" -}}
  {{- range $name, $content := . }}
- name: {{ $name }}
  mountPath: {{ $content.destinationPath }}
    {{- if .readOnly }}
  readOnly: {{ .readOnly }}
    {{- end }}
    {{- if $content.mountPropagation }}
  mountPropagation: {{ $content.mountPropagation }}
    {{- end }}
  {{- end }}
{{- end }}
{{/*
summon.common.volumeMounts.configMaps

mountPath semantics for a configMap entry:
  - If `items:` is set OR `mountAsDirectory: true`, the spell's `mountPath`
    is the real mount path (directory semantics, k8s-native).
  - Otherwise (legacy single-file mount), `mountPath` is treated as the
    parent directory and the filename is appended, with a subPath defaulted
    to the sanitized entry name. This is the historical default and is
    preserved for backward compatibility — set `mountAsDirectory: true` to
    opt out.
*/}}
{{- define "summon.common.volumeMounts.configMaps" -}}
  {{- range $name, $content := .  }}
    {{- if ne ( default "file" .contentType ) "env" }}
    {{- $rn := include "common.storage.resourceName" (list $name $content) }}
    {{- $asDir := or $content.items $content.mountAsDirectory }}
- name: {{ $rn }}
  {{- if $asDir }}
  {{/* mountPath is treated as a directory */}}
  mountPath: {{ $content.mountPath }}
  {{- else }}
  {{/* legacy single-file mount: append filename */}}
  mountPath: {{ $content.mountPath }}/{{ ( default $name $content.name ) }}
  {{- end }}
  {{- if $content.subPath }}
  subPath: {{ $content.subPath }}
  {{- else if not $asDir }}
  {{/* default subPath for single-file mount */}}
  subPath: {{ $rn }}
  {{- end }}
    {{- end }}
  {{- end }}
{{- end -}}

{{- define "summon.common.volumeMounts.secrets" -}}
  {{- range $name, $content := . }}
    {{- if ne ( default "file" .contentType ) "env" }}
    {{- $rn := include "common.storage.resourceName" (list $name $content) }}
- name: {{ $rn }}
  mountPath: {{ $content.mountPath }}
  {{- if $content.subPath }}
  subPath: {{ $content.subPath }}
  {{- else if not $content.items }}
  {{/* Only use default subPath if items are NOT defined (single file mount) */}}
  subPath: {{ $rn }}
  {{- end }}
    {{- end }}
  {{- end }}
{{- end -}}

{{- define "summon.common.volumeMounts.volumeClaimTemplates" -}}
  {{- range $name, $content := . }}
- name: {{ $name }}
  mountPath: {{ $content.destinationPath }}
    {{- if $content.readOnly }}
  readOnly: {{ $content.readOnly }}
    {{- end }}
  {{- end }}
{{- end -}}
