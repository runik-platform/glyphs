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

{{/*
netbird.instanceEntry resolves the Runik-level provider contract for the
singleton NetBird installation. Consumers may set exactly one of instanceRef
or instanceSelector. With neither, runicIndexer selects the default: book
netbird-instance entry.

The selected entry publishes the NetBirdInstance namespace and optionally
resourceRef.name (default: default) or an explicit instanceId.
*/}}
{{- define "netbird.instanceEntry" -}}
{{- $root := index . 0 -}}
{{- $definition := default (dict) (index . 1) -}}
{{- $caller := index . 2 -}}
{{- $explicit := default "" $definition.instanceRef -}}
{{- $selector := default (dict) $definition.instanceSelector -}}
{{- if and (not (empty $explicit)) (not (kindIs "string" $explicit)) -}}
  {{- fail (printf "%s: instanceRef must be a lexicon key string" $caller) -}}
{{- end -}}
{{- if not (kindIs "map" $selector) -}}
  {{- fail (printf "%s: instanceSelector must be an object" $caller) -}}
{{- end -}}
{{- $explicitSelection := or (not (empty $explicit)) (gt (len $selector) 0) -}}
{{- if and $explicit $selector -}}
  {{- fail (printf "%s: instanceRef and instanceSelector are mutually exclusive" $caller) -}}
{{- end -}}
{{- $entries := list -}}
{{- if $explicit -}}
  {{- $entry := get (default (dict) $root.Values.lexicon) $explicit -}}
  {{- if not $entry -}}
    {{- fail (printf "%s: instanceRef %q was not found in the lexicon" $caller $explicit) -}}
  {{- end -}}
  {{- if not (kindIs "map" $entry) -}}
    {{- fail (printf "%s: instanceRef %q must resolve to an object" $caller $explicit) -}}
  {{- end -}}
  {{- if ne (default "" $entry.type) "netbird-instance" -}}
    {{- fail (printf "%s: instanceRef %q must have type netbird-instance" $caller $explicit) -}}
  {{- end -}}
  {{- $entries = list $entry -}}
{{- else -}}
  {{- $entries = get (include "runic-system.runic-indexer" (list $root.Values.lexicon $selector "netbird-instance" $root.Values.chapter.name) | fromJson) "results" -}}
{{- end -}}
{{- if and (eq (len $entries) 0) (not $explicitSelection) -}}
  {{- dict "entry" (dict) "instanceId" "default" "legacy" true | toJson -}}
{{- else -}}
{{- if ne (len $entries) 1 -}}
  {{- fail (printf "%s: exactly one netbird-instance is required, got %d" $caller (len $entries)) -}}
{{- end -}}
{{- $entry := index $entries 0 -}}
{{- if not (kindIs "map" $entry) -}}
  {{- fail (printf "%s: selected netbird-instance must be an object" $caller) -}}
{{- end -}}
{{- $namespace := required (printf "%s: selected netbird-instance requires namespace" $caller) $entry.namespace -}}
{{- if not (kindIs "string" $namespace) -}}
  {{- fail (printf "%s: selected netbird-instance namespace must be a string" $caller) -}}
{{- end -}}
{{- $resourceRef := default (dict) $entry.resourceRef -}}
{{- if not (kindIs "map" $resourceRef) -}}
  {{- fail (printf "%s: selected netbird-instance resourceRef must be an object" $caller) -}}
{{- end -}}
{{- $resourceName := default "default" $resourceRef.name -}}
{{- if not (kindIs "string" $resourceName) -}}
  {{- fail (printf "%s: selected netbird-instance resourceRef.name must be a string" $caller) -}}
{{- end -}}
{{- $instanceID := default (printf "%s/%s" $namespace $resourceName) $entry.instanceId -}}
{{- if not (kindIs "string" $instanceID) -}}
  {{- fail (printf "%s: selected netbird-instance instanceId must be a string" $caller) -}}
{{- end -}}
{{- dict "entry" $entry "instanceId" $instanceID | toJson -}}
{{- end -}}
{{- end -}}

{{/*
Validate a consumer against its selected provider. It emits no Kubernetes
field because both current NetBird operators are singleton controllers.
*/}}
{{- define "netbird.requireInstance" -}}
{{- $resolved := include "netbird.instanceEntry" . | fromJson -}}
{{- get $resolved "instanceId" -}}
{{- end -}}

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
