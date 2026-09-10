{{/*Runik Platform
Copyright (C) 2025 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

Shared reference resolution for NetBird glyphs.

netbird.resolveRefs receives:
  0: Helm root context
  1: explicit list of exact NetBird names
  2: optional runicIndexer selector
  3: lexicon type filter
  4: caller name used in validation messages

It returns JSON: {"refs": ["name", ...]}. Explicit and discovered names are
merged and deduplicated while preserving their first-seen order.
*/}}
{{- define "netbird.resolveRefs" -}}
{{- $root := index . 0 -}}
{{- $explicit := default (list) (index . 1) -}}
{{- $selector := default (dict) (index . 2) -}}
{{- $typeFilter := index . 3 -}}
{{- $caller := index . 4 -}}
{{- $refs := list -}}
{{- range $ref := $explicit -}}
  {{- if $ref -}}
    {{- $refs = append $refs (toString $ref) -}}
  {{- end -}}
{{- end -}}
{{- if $selector -}}
  {{- $found := get (include "runic-system.runic-indexer" (list $root.Values.lexicon $selector $typeFilter $root.Values.chapter.name) | fromJson) "results" -}}
  {{- range $item := $found -}}
    {{- $name := required (printf "%s: selected lexicon entry requires name" $caller) $item.name -}}
    {{- $refs = append $refs (toString $name) -}}
  {{- end -}}
{{- end -}}
{{- dict "refs" (uniq $refs) | toJson -}}
{{- end -}}

{{/*
netbird.singleRef receives the same arguments as resolveRefs, except argument 1
is one explicit string (or an object containing name). It fails unless the
combined explicit/selector result contains exactly one unique reference.

It returns JSON: {"ref": "name"}.
*/}}
{{- define "netbird.singleRef" -}}
{{- $root := index . 0 -}}
{{- $explicitValue := index . 1 -}}
{{- $selector := default (dict) (index . 2) -}}
{{- $typeFilter := index . 3 -}}
{{- $caller := index . 4 -}}
{{- $explicit := list -}}
{{- if $explicitValue -}}
  {{- if kindIs "map" $explicitValue -}}
    {{- $explicit = append $explicit (required (printf "%s: explicit reference requires name" $caller) $explicitValue.name) -}}
  {{- else -}}
    {{- $explicit = append $explicit (toString $explicitValue) -}}
  {{- end -}}
{{- end -}}
{{- $refs := get (include "netbird.resolveRefs" (list $root $explicit $selector $typeFilter $caller) | fromJson) "refs" -}}
{{- if ne (len $refs) 1 -}}
  {{- fail (printf "%s: exactly one reference is required, got %d" $caller (len $refs)) -}}
{{- end -}}
{{- dict "ref" (index $refs 0) | toJson -}}
{{- end -}}

{{/*
netbird.networkEntry resolves one published NetBird network contract without
discarding its provider-specific fields (for example routerRef). Unlike
singleRef, networkRef is the lexicon key, not a direct NetBird object name.

Arguments:
  0: Helm root context
  1: optional explicit lexicon key
  2: optional selector
  3: caller name used in validation messages

Exactly one of networkRef or networkSelector must be set.
Returns JSON: {"entry": <complete lexicon entry>}.
*/}}
{{- define "netbird.networkEntry" -}}
{{- $root := index . 0 -}}
{{- $explicit := default "" (index . 1) -}}
{{- $selector := default (dict) (index . 2) -}}
{{- $caller := index . 3 -}}
{{- if and $explicit $selector -}}
  {{- fail (printf "%s: networkRef and networkSelector are mutually exclusive" $caller) -}}
{{- end -}}
{{- if and (not $explicit) (not $selector) -}}
  {{- fail (printf "%s: networkRef or networkSelector is required" $caller) -}}
{{- end -}}
{{- $entries := list -}}
{{- if $explicit -}}
  {{- $entry := get (default (dict) $root.Values.lexicon) $explicit -}}
  {{- if not $entry -}}
    {{- fail (printf "%s: networkRef %q was not found in the lexicon" $caller $explicit) -}}
  {{- end -}}
  {{- if ne (default "" $entry.type) "netbird-network" -}}
    {{- fail (printf "%s: networkRef %q must have type netbird-network" $caller $explicit) -}}
  {{- end -}}
  {{- $entries = list $entry -}}
{{- else -}}
  {{- $entries = get (include "runic-system.runic-indexer" (list $root.Values.lexicon $selector "netbird-network" $root.Values.chapter.name) | fromJson) "results" -}}
{{- end -}}
{{- if ne (len $entries) 1 -}}
  {{- fail (printf "%s: exactly one netbird-network is required, got %d" $caller (len $entries)) -}}
{{- end -}}
{{- dict "entry" (index $entries 0) | toJson -}}
{{- end -}}
