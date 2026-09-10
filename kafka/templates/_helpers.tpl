{{/*Runik Platform
Copyright (C) 2026 namenmalkav@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

Non-rendering helpers shared by Strimzi glyphs. Resources that belong to a
Kafka cluster may set `cluster` explicitly or use `selector` to resolve a
`type: kafka` entry from the Runik lexicon.
*/}}

{{- define "kafka.clusterRef" -}}
{{- $root := index . 0 -}}
{{- $definition := index . 1 -}}
{{- $context := index . 2 -}}
{{- if $definition.cluster -}}
{{- dict "name" $definition.cluster "namespace" $definition.namespace | toJson -}}
{{- else -}}
  {{- $matches := get (include "runic-system.runic-indexer" (list $root.Values.lexicon (default (dict "default" "book") $definition.selector) "kafka" $root.Values.chapter.name) | fromJson) "results" -}}
  {{- if not $matches -}}
    {{- fail (printf "%s: cluster is required when no type=kafka lexicon entry matches selector %v" $context (default (dict "default" "book") $definition.selector)) -}}
  {{- end -}}
  {{- $match := index $matches 0 -}}
  {{- $name := required (printf "%s: matched kafka lexicon entry has neither clusterName nor name" $context) (default $match.name $match.clusterName) -}}
  {{- dict "name" $name "namespace" (default $match.namespace $definition.namespace) | toJson -}}
{{- end -}}
{{- end -}}
