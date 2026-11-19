{{/*Runik Platform
Copyright (C) 2026 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only
*/}}
{{/* A single persisted password, optionally rotated by an explicit interval.
No SecretStore is required: the generator is local to ESO. */}}
{{- define "external-secrets.generated-secret" -}}
{{- $root := index . 0 -}}
{{- $g := deepCopy (index . 1) -}}
{{- $name := include "common.glyph.name" (dict "root" $root "glyph" $g) -}}
{{- $password := mergeOverwrite (dict "length" 32 "digits" 5 "symbols" 5 "symbolCharacters" "-_@" "allowRepeat" true) (deepCopy (default dict $g.password)) -}}
{{ printf "\n" }}
---
apiVersion: generators.external-secrets.io/v1alpha1
kind: Password
metadata:
  name: {{ $name }}
  {{- with $g.namespace }}
  namespace: {{ . }}
  {{- end }}
  labels:
    {{- include "common.all.labels" $root | nindent 4 }}
  {{- with $g.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- toYaml $password | nindent 2 }}
{{- $_ := set $g "name" $name -}}
{{- $_ := set $g "generatorRef" (dict "apiVersion" "generators.external-secrets.io/v1alpha1" "kind" "Password" "name" $name) -}}
{{- $_ := set $g "refreshPolicy" (default (ternary "Periodic" "CreatedOnce" (hasKey $g "refreshInterval")) $g.refreshPolicy) -}}
{{- $_ := set $g "refreshInterval" (default "0s" $g.refreshInterval) -}}
{{- $_ := set $g "deletionPolicy" "Retain" -}}
{{ include "external-secrets.external-secret" (list $root $g) }}
{{- end -}}
