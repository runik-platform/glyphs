{{/*Runik Platform
Copyright (C) 2023 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only
 */}}
{{- define "summon.common.envs.envFrom.items" -}}
{{- with .Values.configMaps }}
{{- include "summon.common.envs.configMaps" . }}
{{- end }}
{{- with .Values.secrets }}
{{- include "summon.common.envs.secrets.native" $ }}
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

{{/* Only the documented native s3.<key> -> secrets.<key> env binding
     participates. Explicit envs, ConfigMaps and unrelated Secrets are literal.
     Keep the existing map-only helper contract for other callers. */}}
{{- define "summon.common.envs.secrets.native" -}}
{{- $root := . -}}
{{- range $name, $content := .Values.secrets }}
{{- if eq (default "" $content.contentType) "env" }}
{{- $secret := $name | replace "." "-" }}
{{- $s3 := dict }}
{{- if and (eq $root.Chart.Name "summon") (kindIs "map" $root.Values.s3) }}
  {{- $s3 = get $root.Values.s3 $name | default dict }}
{{- end }}
{{- if and (kindIs "map" $s3) (hasKey $s3 "instance") (eq (default "" $s3.type) "bucket") }}
  {{- $g := merge (deepCopy $s3) (dict "name" $name) }}
  {{- $providers := include "s3.bucket.providers" (list $root $g) | fromJsonArray }}
  {{- $names := include "s3.bucket.names" (list $root $g (first $providers)) | fromJson }}
  {{- if ne $names.namespace $root.Release.Namespace }}{{- fail "s3.bucket: native env consumption requires the workload namespace" }}{{- end }}
  {{- if or $content.content (eq (default "" $content.location) "create") }}{{- fail "s3.bucket: native env binding cannot also create inline Secret content" }}{{- end }}
  {{- $secret = $names.appSecret }}
{{- end }}
- secretRef:
    name: {{ $secret }}
{{- end }}
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
