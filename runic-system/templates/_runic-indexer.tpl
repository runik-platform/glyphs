{{/*Runik Platform
Copyright (C) 2023 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

runic-system.runic-indexer - Infrastructure discovery via lexicon label matching

The runic indexer enables dynamic resource discovery in templates by querying
infrastructure definitions stored in the lexicon (via appendix.lexicon).

Usage:
  {{- $results := get (include "runic-system.runic-indexer" (list $lexicon $selectors $type $chapter) | fromJson) "results" }}

Parameters:
  $lexicon: Lexicon dictionary from bookrack appendix
  $selectors: Label selectors (AND logic, empty = any)
  $type: Infrastructure type to filter by (e.g., istio-gw, vault, database)
  $chapter: Current chapter name (for chapter-level defaults)

Selection Priority:
  1. Exact match: ALL selectors match labels (AND logic)
  2. Book default: label with default: book (no selectors matched)
  3. Chapter default: label with default: chapter in same chapter (fallback)

Example lexicon entry:
  - name: external-gateway
    type: istio-gw
    labels:
      access: external
      environment: production
      default: book
    gateway: istio-system/external-gateway

Example usage in glyph:
  {{- $gateways := get (include "runic-system.runic-indexer" (list $root.Values.lexicon $glyphDefinition.selector "istio-gw" $root.Values.chapter.name) | fromJson) "results" }}
*/}}
{{- define "runic-system.runic-indexer" -}}
{{- $glyphs := index . 0 -}}
{{- $selectors := index . 1 -}}
{{- $type := index . 2 -}}
{{- $chapter := index . 3 -}}
{{- $results := list -}}
{{- $bookDefault := list -}}
{{- $chapterDefault := list -}}

{{/* Dictionary format - iterate over key/value pairs */}}
{{- range $glyphName, $currentGlyph := $glyphs -}}
  {{/* Ensure .name exists (use dict key if missing) */}}
  {{- if not (hasKey $currentGlyph "name") -}}
    {{- $_ := set $currentGlyph "name" $glyphName -}}
  {{- end -}}
  {{- if eq $currentGlyph.type $type -}}
    {{- $labels := default dict $currentGlyph.labels -}}
    {{/* Check if ALL selectors match (AND logic) */}}
    {{/* Selectors match against labels first, then top-level keys as fallback */}}
    {{- $allSelectorsMatch := true -}}
    {{- range $selector, $value := $selectors -}}
      {{- if and (hasKey $labels $selector) (eq (index $labels $selector) $value) -}}
      {{- else if and (hasKey $currentGlyph $selector) (eq (toString (index $currentGlyph $selector)) (toString $value)) -}}
      {{- else -}}
        {{- $allSelectorsMatch = false -}}
      {{- end -}}
    {{- end -}}
    {{/* Only add to results if selectors exist AND ALL selectors matched */}}
    {{- if and (gt (len $selectors) 0) $allSelectorsMatch -}}
      {{- $results = append $results $currentGlyph -}}
    {{- end -}}
    {{- if and (hasKey $labels "default") (eq (len $results) 0) -}}
      {{- if eq (index $labels "default") "book" -}}
        {{- $bookDefault = append $bookDefault $currentGlyph -}}
      {{- else if and (eq $currentGlyph.chapter $chapter) (eq (index $labels "default") "chapter") -}}
        {{- $chapterDefault = append $chapterDefault $currentGlyph -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- if (eq (len $results) 0) -}}
  {{- if (eq (len $chapterDefault) 0) -}}
    {{- $results = $bookDefault -}}
  {{- else -}}
    {{- $results = $chapterDefault -}}
  {{- end -}}
{{- end -}}
{{- dict "results" $results | toJson -}}
{{- end -}}
