{{/*Runik Platform
SPDX-License-Identifier: AGPL-3.0-only

Pinniped glyph: OIDCIdentityProvider

Usage:
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
{{- define "pinniped.oidcIdentityProvider" }}
{{- $root := index . 0 -}}
{{- $glyph := index . 1 }}
---
apiVersion: idp.supervisor.pinniped.dev/v1alpha1
kind: OIDCIdentityProvider
metadata:
  name: {{ $glyph.name }}
  namespace: {{ $glyph.namespace | default "pinniped-supervisor" }}
spec:
  issuer: {{ $glyph.issuer }}
  {{- if $glyph.scopes }}
  authorizationConfig:
    additionalScopes:
      {{- range $glyph.scopes }}
      - {{ . }}
      {{- end }}
  {{- end }}
  {{- if $glyph.claims }}
  claims:
    {{- if $glyph.claims.username }}
    username: {{ $glyph.claims.username }}
    {{- end }}
    {{- if $glyph.claims.groups }}
    groups: {{ $glyph.claims.groups }}
    {{- end }}
  {{- end }}
  client:
    secretName: {{ $glyph.clientSecretName }}
{{- end }}
