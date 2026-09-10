{{/*Runik Platform
Copyright (C) 2026 namenmalkav@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

kafka.cluster is the convenience meta-glyph for a complete Strimzi cluster.
It composes the one-resource glyphs instead of owning either CRD shape:
  1. kafka.kafka renders the Kafka resource
  2. kafka.nodePool renders one KafkaNodePool per nodePools entry

The cluster must be published as a `type: kafka` lexicon entry so topics,
users, rebalances, and other spells can discover it. By default the meta uses
the same-named lexicon entry; `selector` can choose another entry. In a real
spell the entry is normally declared under `appendix.lexicon`.

`kafka` contains the definition passed to kafka.kafka. Each `nodePools` entry
contains the definition passed to kafka.nodePool. The meta only extends those
definitions with identity and lexicon references; it does not flatten fields
across components or accept a native `spec:` passthrough.

When nodePools is omitted, a single ephemeral combined pool is created.
*/}}
{{- define "kafka.cluster" -}}
{{- $root := index . 0 -}}
{{- $definition := index . 1 -}}
{{- $glyphName := required "kafka.cluster: name is required" $definition.name -}}

{{- $entry := get (default (dict) $root.Values.lexicon) $glyphName -}}
{{- if and $entry (ne (default "" $entry.type) "kafka") -}}
  {{- $entry = dict -}}
{{- end -}}
{{- if or $definition.selector (not $entry) -}}
  {{- $selector := default (dict "default" "book") $definition.selector -}}
  {{- $matches := get (include "runic-system.runic-indexer" (list $root.Values.lexicon $selector "kafka" $root.Values.chapter.name) | fromJson) "results" -}}
  {{- if not $matches -}}
    {{- fail (printf "kafka.cluster: a type=kafka lexicon entry is required for %s (selector %v)" $glyphName $selector) -}}
  {{- end -}}
  {{- $entry = index $matches 0 -}}
{{- end -}}
{{- if not $entry -}}
  {{- fail (printf "kafka.cluster: lexicon.%s with type=kafka is required" $glyphName) -}}
{{- end -}}

{{- $clusterName := default (default $glyphName $entry.name) $entry.clusterName -}}
{{- $namespace := default $entry.namespace $definition.namespace -}}
{{- $kafkaDefinition := deepCopy (default (dict) $definition.kafka) -}}
{{- $_ := set $kafkaDefinition "name" $clusterName -}}
{{- if $namespace }}{{- $_ := set $kafkaDefinition "namespace" $namespace -}}{{- end -}}
{{ include "kafka.kafka" (list $root $kafkaDefinition) }}

{{- $nodePools := default (dict "combined" (dict)) $definition.nodePools -}}
{{- range $poolKey, $pool := $nodePools -}}
  {{- $poolDefinition := deepCopy (default (dict) $pool) -}}
  {{- $_ := set $poolDefinition "name" (default (printf "%s-%s" $clusterName $poolKey) $poolDefinition.name) -}}
  {{- $_ := set $poolDefinition "cluster" $clusterName -}}
  {{- if and $namespace (not $poolDefinition.namespace) }}{{- $_ := set $poolDefinition "namespace" $namespace -}}{{- end -}}
{{ include "kafka.nodePool" (list $root $poolDefinition) }}
{{- end -}}
{{- printf "\n" -}}
{{- end }}
