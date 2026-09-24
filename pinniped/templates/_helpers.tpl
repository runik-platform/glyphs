{{/*Runik Platform
Copyright (C) 2026 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

Shared helpers for Pinniped resources.
*/}}

{{/*
pinniped.nativeResource renders one CRD using its upstream spec verbatim.

Arguments:
  0: Helm root context
  1: glyph definition
  2: apiVersion
  3: kind
  4: namespaced resource (bool)
  5: default namespace (empty for cluster-scoped resources)
  6: caller name used in validation messages
*/}}
{{- define "pinniped.nativeResource" -}}
{{- $definition := index . 1 -}}
{{- $apiVersion := index . 2 -}}
{{- $kind := index . 3 -}}
{{- $namespaced := index . 4 -}}
{{- $defaultNamespace := index . 5 -}}
{{- $caller := index . 6 -}}
{{- $name := required (printf "%s: name is required" $caller) $definition.name -}}
{{- if not (hasKey $definition "spec") -}}
  {{- fail (printf "%s: spec is required" $caller) -}}
{{- end -}}
{{- if and (not $namespaced) (default "" $definition.namespace) -}}
  {{- fail (printf "%s: namespace is not valid for cluster-scoped %s" $caller $kind) -}}
{{- end }}
---
apiVersion: {{ $apiVersion }}
kind: {{ $kind }}
metadata:
  name: {{ $name }}
{{- if $namespaced }}
  namespace: {{ default $defaultNamespace $definition.namespace }}
{{- end }}
{{- with $definition.labels }}
  labels:
{{ toYaml . | nindent 4 }}
{{- end }}
{{- with $definition.annotations }}
  annotations:
{{ toYaml . | nindent 4 }}
{{- end }}
spec:
{{ toYaml $definition.spec | nindent 2 }}
{{- end }}

{{/*
pinniped.identityProviderRefs discovers the IdentityProviders attached to one
FederationDomain. Providers publish a pinniped-identity-provider lexicon entry
and consumers select them by labels, like Istio VirtualServices select
Gateways. Pinniped uses a TypedLocalObjectReference, so every selected provider
must live in the FederationDomain namespace.

Arguments:
  0: Helm root context
  1: runicIndexer selector
  2: FederationDomain namespace
  3: caller name used in validation messages

Returns JSON: {"refs": [<FederationDomain identityProviders entries>]}
*/}}
{{- define "pinniped.identityProviderRefs" -}}
{{- $root := index . 0 -}}
{{- $selector := default (dict) (index . 1) -}}
{{- $namespace := index . 2 -}}
{{- $caller := index . 3 -}}
{{- $providers := get (include "runic-system.runic-indexer" (list $root.Values.lexicon $selector "pinniped-identity-provider" $root.Values.chapter.name) | fromJson) "results" -}}
{{- if eq (len $providers) 0 -}}
  {{- fail (printf "%s: identityProviderSelector did not resolve any pinniped-identity-provider entries" $caller) -}}
{{- end -}}
{{- $refs := list -}}
{{- range $provider := $providers -}}
  {{- $name := required (printf "%s: selected identity provider requires name" $caller) $provider.name -}}
  {{- $kind := required (printf "%s: selected identity provider %q requires kind" $caller $name) $provider.kind -}}
  {{- $providerNamespace := default $namespace $provider.namespace -}}
  {{- if ne $providerNamespace $namespace -}}
    {{- fail (printf "%s: selected identity provider %q is in namespace %q, but FederationDomain is in %q" $caller $name $providerNamespace $namespace) -}}
  {{- end -}}
  {{- $ref := dict
        "displayName" (default $name $provider.displayName)
        "objectRef" (dict
          "apiGroup" (default "idp.supervisor.pinniped.dev" $provider.apiGroup)
          "kind" $kind
          "name" $name) -}}
  {{- with $provider.transforms -}}
    {{- $_ := set $ref "transforms" . -}}
  {{- end -}}
  {{- $refs = append $refs $ref -}}
{{- end -}}
{{- dict "refs" $refs | toJson -}}
{{- end }}
