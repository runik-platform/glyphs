{{/*Runik Platform
SPDX-License-Identifier: AGPL-3.0-only

Pinniped glyph: OIDCIdentityProvider

Legacy usage (still supported):
  pinniped:
    keycloak:
      type: oidcIdentityProvider
      namespace: pinniped-supervisor
      issuer: https://sso.example.com/realms/myrealm
      scopes: [email, profile, groups]
      claims:
        username: preferred_username
        groups: groups
      clientSecretName: pinniped-oidc-client-secret
*/}}
{{- define "pinniped.oidcIdentityProvider" -}}
{{- $root := index . 0 -}}
{{- $glyph := index . 1 -}}
{{- $definition := deepCopy $glyph -}}
{{- if hasKey $glyph "spec" -}}
  {{- range $legacyField := list "issuer" "scopes" "claims" "clientSecretName" -}}
    {{- if hasKey $glyph $legacyField -}}
      {{- fail (printf "pinniped.oidcIdentityProvider: spec and legacy field %s are mutually exclusive" $legacyField) -}}
    {{- end -}}
  {{- end -}}
{{- else -}}
  {{- $issuer := required "pinniped.oidcIdentityProvider: issuer is required" $glyph.issuer -}}
  {{- $secretName := required "pinniped.oidcIdentityProvider: clientSecretName is required" $glyph.clientSecretName -}}
  {{- $spec := dict "issuer" $issuer "client" (dict "secretName" $secretName) -}}
  {{- with $glyph.scopes -}}
    {{- $_ := set $spec "authorizationConfig" (dict "additionalScopes" .) -}}
  {{- end -}}
  {{- with $glyph.claims -}}
    {{- $_ := set $spec "claims" . -}}
  {{- end -}}
  {{- $_ := set $definition "spec" $spec -}}
{{- end -}}
{{ include "pinniped.nativeResource" (list $root $definition "idp.supervisor.pinniped.dev/v1alpha1" "OIDCIdentityProvider" true "pinniped-supervisor" "pinniped.oidcIdentityProvider") }}
{{- end }}
