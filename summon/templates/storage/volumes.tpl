{{/*Runik Platform
Copyright (C) 2023 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only
 */}}
{{- define "summon.common.volumes.items" -}}
{{- with .Values.configMaps }}
{{- include "summon.common.volumes.configMaps" . }}
{{- end }}
{{- with .Values.secrets }}
{{- include "summon.common.volumes.secrets" . }}
{{- end }}
{{- if .Values.volumes }}
{{- include "summon.common.volumes.volumes" . }}
{{- end }}
{{- end -}}

{{- define "summon.common.volumes" -}}
{{- $items := include "summon.common.volumes.items" . | trim -}}
{{- if $items }}
volumes:
{{ $items | nindent 2 }}
{{- end }}
{{- end -}}


{{- define "summon.common.volumes.volumes" -}}
  {{- range $name, $volume := .Values.volumes }}
- name: {{ $name }}
  {{- if eq $volume.type "emptyDir" }}
  emptyDir:
    {{- if $volume.inMemory }} 
      medium: "Memory"
    {{- end }}
      sizeLimit: {{default "" $volume.size}}
    {{- end }}
  {{- if eq $volume.type "hostPath" }}
  hostPath: 
    path: {{ $volume.path }}
    type: {{ default "DirectoryOrCreate" $volume.pathType }}
    {{- end }}
  {{- if eq $volume.type "nfs" }}
  nfs:
    server: {{ $volume.server }}
    path: {{ $volume.path }}
    {{- end }}
  {{- if eq $volume.type "pvc" }}
  persistentVolumeClaim:
    {{- $pvcName := "" }}
    {{- if $volume.name }}
      {{- $pvcName = $volume.name }}
    {{- else }}
      {{- $pvcName = print (include "common.name" $ ) "-" $name }}
    {{- end }}
    claimName: {{ $pvcName }}
  {{- end }}
  {{- if eq $volume.type "secret" }}
  secret:
    secretName: {{ $volume.secretName }}
    {{- if $volume.defaultMode }}
    defaultMode: {{ $volume.defaultMode }}
    {{- end }}
    {{- if $volume.items }}
    items:
      {{- range $volume.items }}
      - key: {{ .key }}
        path: {{ .path }}
        {{- if .mode }}
        mode: {{ .mode }}
        {{- end }}
      {{- end }}
    {{- end }}
  {{- end }}
  {{- if eq $volume.type "downwardAPI" }}
  downwardAPI:
    {{- if $volume.defaultMode }}
    defaultMode: {{ $volume.defaultMode }}
    {{- end }}
    items:
      {{- range $volume.items }}
      - path: {{ .path }}
        fieldRef:
          fieldPath: {{ .fieldPath }}
        {{- if .resourceFieldRef }}
        resourceFieldRef:
          containerName: {{ .resourceFieldRef.containerName }}
          resource: {{ .resourceFieldRef.resource }}
        {{- end }}
      {{- end }}
  {{- end }}
  {{- if eq $volume.type "configmap" }}
  configMap:
    name: {{ $volume.configMapName }}
    {{- if $volume.defaultMode }}
    defaultMode: {{ $volume.defaultMode }}
    {{- end }}
    {{- if $volume.items }}
    items:
      {{- range $volume.items }}
      - key: {{ .key }}
        path: {{ .path }}
        {{- if .mode }}
        mode: {{ .mode }}
        {{- end }}
      {{- end }}
    {{- end }}
  {{- end }}
{{- end }}
{{- end }}

{{- define "summon.common.volumes.configMaps" -}}
  {{- range $name, $content := .  }}
    {{- if ne ( default "file" .contentType ) "env" }}
    {{- $rn := include "common.storage.resourceName" (list $name $content) }}
- name: {{ $rn }}
  configMap:
    name: {{ $rn }}
    {{- if $content.defaultMode }}
    defaultMode: {{ $content.defaultMode }}
    {{- end }}
    {{- if $content.items }}
    items:
      {{- range $content.items }}
      - key: {{ .key }}
        path: {{ .path }}
        {{- if .mode }}
        mode: {{ .mode }}
        {{- end }}
      {{- end }}
    {{- end }}
    {{- end }}
  {{- end }}
{{- end -}}

{{- define "summon.common.volumes.secrets" -}}
  {{- range $name, $content := . }}
    {{- if ne ( default "file" .contentType ) "env" }}
    {{- $rn := include "common.storage.resourceName" (list $name $content) }}
- name: {{ $rn }}
  secret:
    secretName: {{ $rn }}
    {{- if $content.defaultMode }}
    defaultMode: {{ $content.defaultMode }}
    {{- end }}
    {{- if $content.items }}
    items:
      {{- range $content.items }}
      - key: {{ .key }}
        path: {{ .path }}
        {{- if .mode }}
        mode: {{ .mode }}
        {{- end }}
      {{- end }}
    {{- end }}
    {{- end }}
  {{- end }}
{{- end -}}
