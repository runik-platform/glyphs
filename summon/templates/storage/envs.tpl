{{/*Runik Platform
Copyright (C) 2023 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only
 */}}
{{- define "summon.common.envs.envFrom.items" -}}
{{- with .Values.configMaps }}
{{- include "summon.common.envs.configMaps" . }}
{{- end }}
{{- with .Values.secrets }}
{{- include "summon.common.envs.secrets" . }}
{{- end }}
{{- end -}}

{{- define "summon.common.envs.envFrom" -}}
{{- $items := include "summon.common.envs.envFrom.items" . | trim -}}
{{- if $items }}
envFrom:
{{ $items | nindent 2 }}
{{- end }}
{{- end -}}

{{- define "summon.common.envs.configMaps" -}}
{{- range $name, $content := . }}
{{- if eq ( default "" $content.contentType ) "env" }}
- configMapRef:
    name: {{ $name | replace "." "-"  }}
{{- end -}}
{{- end }}
{{- end -}}

{{- define "summon.common.envs.secrets" -}}
{{- range $name, $content := . }}
{{- if eq ( default "" $content.contentType ) "env" }}
- secretRef:
    name: {{ $name | replace "." "-"}}
{{- end -}}
{{- end }}
{{- end -}}

{{- define "summon.common.envs.env.items" -}}
  {{- if .Values.spellbook }}
- name: SPELLBOOK_NAME
  value: {{ .Values.spellbook.name | quote }}
- name: CHAPTER_NAME
  value: {{ .Values.chapter.name | quote }}
- name: SPELL_NAME
  value: {{ default .Release.Name .Values.name | quote }}
  {{- end }}
{{- range $key, $value := .Values.envs }}
{{- if eq (kindOf $value) "string" }}
- name: {{ $key | upper }}
  value: {{ $value | quote }}
{{- else if eq (index $value "type") "secret" }}
- name: {{ $key | upper }}
  valueFrom:
    secretKeyRef:
      name: {{ (index $value "name") }}
      key: {{ (index $value "key") }}
{{- else if eq (index $value "type") "configMap" }}
- name: {{ $key }}
  valueFrom:
    configMapKeyRef:
      name: {{ (index $value "name") }}
      key: {{ (index $value "key") }}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "summon.common.envs.env" -}}
{{- $items := include "summon.common.envs.env.items" . | trim -}}
{{- if $items }}
env:
{{ $items | nindent 2 }}
{{- end }}
{{- end -}}
