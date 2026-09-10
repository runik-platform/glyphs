{{/*Runik Platform
Copyright (C) 2023 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

argo-events.lexicon-index owns the migration aliases for Argo Events lexicon
types. runic-system remains a generic exact-match indexer.

Canonical types are tried first. Historical spellings are consulted only when
the canonical spelling has no matches, so a partially migrated book has a
deterministic preference for its canonical entries.
*/}}
{{- define "argo-events.lexicon-index" -}}
{{- $lexicon := index . 0 -}}
{{- $selectors := index . 1 -}}
{{- $requestedType := index . 2 -}}
{{- $chapter := index . 3 -}}
{{- $eventBusTypes := list "event-bus" "eventbus" "eventBus" -}}
{{- $eventSourceTypes := list "event-source" "eventsource" "eventSource" -}}
{{- $aliases := dict
      "event-bus" $eventBusTypes
      "eventbus" $eventBusTypes
      "eventBus" $eventBusTypes
      "event-source" $eventSourceTypes
      "eventsource" $eventSourceTypes
      "eventSource" $eventSourceTypes
-}}
{{- $candidateTypes := default (list $requestedType) (get $aliases $requestedType) -}}
{{- $results := list -}}
{{- range $candidateType := $candidateTypes -}}
  {{- if eq (len $results) 0 -}}
    {{- $candidateResults := get (include "runic-system.runic-indexer" (list $lexicon $selectors $candidateType $chapter) | fromJson) "results" -}}
    {{- if gt (len $candidateResults) 0 -}}
      {{- $results = $candidateResults -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- dict "results" $results | toJson -}}
{{- end -}}
