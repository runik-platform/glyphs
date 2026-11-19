{{/*
common.glyph.name accepts a dict with root, optional glyph and optional options.
Base: glyph.name, falling back to the existing common.name(root).
Order: options.prefix + glyph.namePrefix + base + glyph.nameSuffix + options.suffix.
Affixes include their own separators. Existing explicit names are preserved.

options.normalize (default false) opts into DNS label normalization and a
deterministic hash on truncation. options.maxLength (default 63, range 10..63)
requires normalize=true. The combined suffix is reserved before truncating.
Normalization can rename resources; opt in only when the caller's contract
allows it. SQL names, bucket identities and external references have their
own contracts and must not be normalized implicitly.

Usage:
  include "common.glyph.name" (dict "root" $root "glyph" $glyph
    "options" (dict "suffix" "-cert"))
*/}}
{{- define "common.glyph.name" -}}
{{- $root := .root -}}
{{- range $field := list "glyph" "options" -}}
  {{- $value := get $ $field -}}
  {{- if and (hasKey $ $field) (not (kindIs "invalid" $value)) (not (kindIs "map" $value)) -}}
    {{- fail (printf "common.glyph.name: %s must be a map" $field) -}}
  {{- end -}}
{{- end -}}
{{- $glyph := default dict .glyph -}}
{{- $options := default dict .options -}}
{{- range $field := list "name" "namePrefix" "nameSuffix" -}}
  {{- if and (hasKey $glyph $field) (not (kindIs "string" (get $glyph $field))) -}}
    {{- fail (printf "common.glyph.name: glyph.%s must be a string" $field) -}}
  {{- end -}}
{{- end -}}
{{- range $field := list "prefix" "suffix" -}}
  {{- if and (hasKey $options $field) (not (kindIs "string" (get $options $field))) -}}
    {{- fail (printf "common.glyph.name: options.%s must be a string" $field) -}}
  {{- end -}}
{{- end -}}
{{- if and (hasKey $options "normalize") (not (kindIs "bool" $options.normalize)) -}}
  {{- fail "common.glyph.name: options.normalize must be a boolean" -}}
{{- end -}}
{{- $base := default (include "common.name" $root) $glyph.name -}}
{{- $prefix := printf "%s%s" (default "" $options.prefix) (default "" $glyph.namePrefix) -}}
{{- $suffix := printf "%s%s" (default "" $glyph.nameSuffix) (default "" $options.suffix) -}}
{{- if and (hasKey $options "maxLength") (not $options.normalize) -}}
  {{- fail "common.glyph.name: options.maxLength requires options.normalize=true" -}}
{{- end -}}
{{- if $options.normalize -}}
  {{- $normalization := dict "name" (print $prefix $base) "suffix" $suffix -}}
  {{- if hasKey $options "maxLength" -}}{{- $_ := set $normalization "maxLength" $options.maxLength -}}{{- end -}}
  {{- include "common.name.normalize" $normalization -}}
{{- else -}}
  {{- print $prefix $base $suffix -}}
{{- end -}}
{{- end -}}

{{/*
common.name.normalize accepts name, optional suffix and maxLength (default 63).
Returns a DNS label: lowercase, replace invalid runs with '-', trim edges.
Long names use <truncated stem>-<8 hex SHA256><suffix>; hash input includes the
complete original name and suffix. With no suffix, nonempty results match the
existing Forgejo/MongoDB safeName algorithm. Empty names fail explicitly.
*/}}
{{- define "common.name.normalize" -}}
{{- if not (kindIs "string" .name) -}}
  {{- fail "common.name.normalize: name must be a string" -}}
{{- end -}}
{{- if and (hasKey . "suffix") (not (kindIs "string" .suffix)) -}}
  {{- fail "common.name.normalize: suffix must be a string" -}}
{{- end -}}
{{- $raw := toString .name -}}
{{- $suffix := default "" .suffix -}}
{{- $limit := 63 -}}
{{- if hasKey . "maxLength" -}}
  {{- $text := toString .maxLength -}}
  {{- if not (regexMatch "^[0-9]+$" $text) -}}
    {{- fail "common.name.normalize: maxLength must be an integer from 10 to 63" -}}
  {{- end -}}
  {{- $limit = int $text -}}
{{- end -}}
{{- if or (lt $limit 10) (gt $limit 63) -}}
  {{- fail "common.name.normalize: maxLength must be an integer from 10 to 63" -}}
{{- end -}}
{{- $slug := regexReplaceAll "[^a-z0-9-]+" (lower (print $raw $suffix)) "-" | trimAll "-" -}}
{{- if not $slug -}}
  {{- fail "common.name.normalize: name is empty after normalization" -}}
{{- end -}}
{{- if gt (len $slug) $limit -}}
  {{- $tail := regexReplaceAll "-+$" (regexReplaceAll "[^a-z0-9-]+" (lower $suffix) "-") "" -}}
  {{- $budget := int (sub $limit (add 9 (len $tail))) -}}
  {{- if lt $budget 1 -}}
    {{- fail "common.name.normalize: suffix leaves no room for the name and hash" -}}
  {{- end -}}
  {{- $stem := regexReplaceAll "[^a-z0-9-]+" (lower $raw) "-" | trimAll "-" | trunc $budget | trimSuffix "-" -}}
  {{- if not $stem -}}
    {{- fail "common.name.normalize: name is empty before the suffix" -}}
  {{- end -}}
  {{- printf "%s-%s%s" $stem (trunc 8 (sha256sum (print $raw $suffix))) $tail -}}
{{- else -}}
  {{- $slug -}}
{{- end -}}
{{- end -}}
