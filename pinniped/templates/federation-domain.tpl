{{/*Runik Platform
SPDX-License-Identifier: AGPL-3.0-only

Pinniped glyph: FederationDomain

Legacy usage (still supported):
  pinniped:
    tyl-federation:
      type: federationDomain
      namespace: pinniped-supervisor
      issuer: https://pinniped.int.the.yaml.life
      identityProviders:
        - displayName: "Keycloak TYL"
          kind: OIDCIdentityProvider
          name: keycloak
*/}}
{{- define "pinniped.federationDomain" -}}
{{- $root := index . 0 -}}
{{- $glyph := index . 1 -}}
{{- $definition := deepCopy $glyph -}}
{{- $namespace := default "pinniped-supervisor" $glyph.namespace -}}
{{- $hasSelector := hasKey $glyph "identityProviderSelector" -}}
{{- $selector := default (dict) $glyph.identityProviderSelector -}}
{{- $spec := dict -}}
{{- if hasKey $glyph "spec" -}}
  {{- range $legacyField := list "issuer" "identityProviders" -}}
    {{- if hasKey $glyph $legacyField -}}
      {{- fail (printf "pinniped.federationDomain: spec and legacy field %s are mutually exclusive" $legacyField) -}}
    {{- end -}}
  {{- end -}}
  {{- $spec = deepCopy $glyph.spec -}}
{{- else -}}
  {{- $_ := set $spec "issuer" (required "pinniped.federationDomain: issuer is required" $glyph.issuer) -}}
  {{- with $glyph.identityProviders -}}
    {{- $refs := list -}}
    {{- range $provider := . -}}
      {{- $ref := dict
            "displayName" (required "pinniped.federationDomain: identityProviders[].displayName is required" $provider.displayName)
            "objectRef" (dict
              "apiGroup" (default "idp.supervisor.pinniped.dev" $provider.apiGroup)
              "kind" (default "OIDCIdentityProvider" $provider.kind)
              "name" (required "pinniped.federationDomain: identityProviders[].name is required" $provider.name)) -}}
      {{- with $provider.transforms -}}
        {{- $_ := set $ref "transforms" . -}}
      {{- end -}}
      {{- $refs = append $refs $ref -}}
    {{- end -}}
    {{- $_ := set $spec "identityProviders" $refs -}}
  {{- end -}}
{{- end -}}
{{- if $hasSelector -}}
  {{- if hasKey $spec "identityProviders" -}}
    {{- fail "pinniped.federationDomain: identityProviderSelector and identityProviders are mutually exclusive" -}}
  {{- end -}}
  {{- $resolved := get (include "pinniped.identityProviderRefs" (list $root $selector $namespace "pinniped.federationDomain") | fromJson) "refs" -}}
  {{- $_ := set $spec "identityProviders" $resolved -}}
{{- end -}}
{{- $_ := set $definition "spec" $spec -}}
{{ include "pinniped.nativeResource" (list $root $definition "config.supervisor.pinniped.dev/v1alpha1" "FederationDomain" true "pinniped-supervisor" "pinniped.federationDomain") }}
{{- end }}
