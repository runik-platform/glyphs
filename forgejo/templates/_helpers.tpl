{{/*Runik Platform
Copyright (C) 2026 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only
*/}}

{{- define "forgejo.safeName" -}}
{{- $raw := toString . -}}
{{- $slug := regexReplaceAll "[^a-z0-9-]+" (lower $raw) "-" | trimAll "-" -}}
{{- if gt (len $slug) 63 -}}
{{- printf "%s-%s" (trunc 54 $slug | trimSuffix "-") (trunc 8 (sha256sum $raw)) -}}
{{- else -}}
{{- $slug -}}
{{- end -}}
{{- end -}}

{{- define "forgejo.entry" -}}
{{- $root := index . 0 -}}
{{- $selector := default dict (index . 1) -}}
{{- $type := index . 2 -}}
{{- $context := index . 3 -}}
{{- $entries := get (include "runic-system.runic-indexer" (list $root.Values.lexicon $selector $type $root.Values.chapter.name) | fromJson) "results" -}}
{{- if eq (len $entries) 0 -}}
  {{- fail (printf "%s: selector %v matched no type=%s lexicon entry" $context $selector $type) -}}
{{- else if gt (len $entries) 1 -}}
  {{- fail (printf "%s: selector %v matched multiple type=%s lexicon entries" $context $selector $type) -}}
{{- end -}}
{{- index $entries 0 | toJson -}}
{{- end -}}

{{- define "forgejo.ref" -}}
{{- $root := index . 0 -}}
{{- $explicit := index . 1 -}}
{{- $selector := default dict (index . 2) -}}
{{- $type := index . 3 -}}
{{- $context := index . 4 -}}
{{- if and $explicit (gt (len $selector) 0) -}}
  {{- fail (printf "%s: exact ref and selector are mutually exclusive" $context) -}}
{{- end -}}
{{- $ref := dict -}}
{{- if $explicit -}}
  {{- if kindIs "string" $explicit -}}
    {{- $_ := set $ref "name" $explicit -}}
  {{- else if kindIs "map" $explicit -}}
    {{- $ref = deepCopy $explicit -}}
  {{- else -}}
    {{- fail (printf "%s: exact ref must be a name or map" $context) -}}
  {{- end -}}
{{- else -}}
  {{- $entry := include "forgejo.entry" (list $root $selector $type $context) | fromJson -}}
  {{- $_ := set $ref "name" (default $entry.name $entry.resourceName) -}}
  {{- with $entry.namespace }}{{- $_ := set $ref "namespace" . -}}{{- end -}}
  {{- with $entry.refLabels }}{{- $_ := set $ref "labels" . -}}{{- end -}}
{{- end -}}
{{- if not $ref.name -}}
  {{- fail (printf "%s: resolved reference has no name" $context) -}}
{{- end -}}
{{- $ref | toJson -}}
{{- end -}}

{{- define "forgejo.metadata" -}}
{{- $root := index . 0 -}}
{{- $definition := index . 1 -}}
name: {{ include "forgejo.safeName" $definition.name }}
namespace: {{ default $root.Release.Namespace $definition.namespace }}
labels:
  {{- include "common.all.labels" $root | nindent 2 }}
  {{- with $definition.labels }}
  {{- toYaml . | nindent 2 }}
  {{- end }}
{{- $annotations := include "common.annotations.map" (list $root (default dict $definition.annotations) dict) | fromJson -}}
{{- with $annotations }}
annotations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end -}}

{{- define "forgejo.resource" -}}
{{- $root := index . 0 -}}
{{- $definition := index . 1 -}}
{{- $kind := index . 2 -}}
{{- $spec := index . 3 -}}
---
apiVersion: hyperspike.io/v1
kind: {{ $kind }}
metadata:
  {{- include "forgejo.metadata" (list $root $definition) | nindent 2 }}
spec:
  {{- toYaml $spec | nindent 2 }}
{{- printf "\n" -}}
{{- end -}}
