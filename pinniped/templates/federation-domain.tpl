{{/*Runik Platform
SPDX-License-Identifier: AGPL-3.0-only

Pinniped glyph: FederationDomain

Usage:
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
{{- define "pinniped.federationDomain" }}
{{- $root := index . 0 -}}
{{- $glyph := index . 1 }}
---
apiVersion: config.supervisor.pinniped.dev/v1alpha1
kind: FederationDomain
metadata:
  name: {{ $glyph.name }}
  namespace: {{ $glyph.namespace | default "pinniped-supervisor" }}
spec:
  issuer: {{ $glyph.issuer }}
  {{- if $glyph.identityProviders }}
  identityProviders:
    {{- range $glyph.identityProviders }}
    - displayName: {{ .displayName | quote }}
      objectRef:
        apiGroup: idp.supervisor.pinniped.dev
        kind: {{ .kind | default "OIDCIdentityProvider" }}
        name: {{ .name }}
    {{- end }}
  {{- end }}
{{- end }}
