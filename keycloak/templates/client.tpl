{{/*Runik Platform
Copyright (C) 2023 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

keycloak.client creates KeycloakClient resources for OIDC/SAML client configuration.
Uses the EDP Keycloak Operator CRDs.

Parameters:
- $root: Chart root context (index . 0)
- $glyphDefinition: Client configuration object (index . 1)

Required Configuration:
- glyphDefinition.realmRef: Keycloak realm name
- glyphDefinition.webUrl: Client web URL

Optional Configuration:
- glyphDefinition.name: Resource name (defaults to common.name)
- glyphDefinition.clientId: Client ID (defaults to name)
- glyphDefinition.protocol: Protocol type (default: openid-connect)
- glyphDefinition.public: Public client flag (default: false)
- glyphDefinition.directAccess: Direct access grants enabled (default: true)
- glyphDefinition.stdFlow: Standard flow enabled (default: true)
- glyphDefinition.redirectUris: List of valid redirect URIs
- glyphDefinition.webOrigins: List of valid web origins
- glyphDefinition.defaultClientScopes: List of default scopes
- glyphDefinition.optionalClientScopes: List of optional scopes
- glyphDefinition.clientRoles: List of client roles
- glyphDefinition.serviceAccount: Service account configuration
- glyphDefinition.attributes: Additional client attributes

Usage: {{- include "keycloak.client" (list $root $glyph) }}
*/}}
{{- define "keycloak.client" }}
{{- $root := index . 0 -}}
{{- $glyphDefinition := index . 1}}
---
apiVersion: v1.edp.epam.com/v1
kind: KeycloakClient
metadata:
  name: {{ default (include "common.name" $root) $glyphDefinition.name }}
  labels:
    {{- include "common.labels" $root | nindent 4}}
  {{- with $glyphDefinition.annotations }}
  annotations:
    {{- toYaml . | nindent 4}}
  {{- end }}
spec:
  realmRef:
    name: {{ required "glyphDefinition.realmRef is required" $glyphDefinition.realmRef }}
    kind: {{ default "ClusterKeycloakRealm" $glyphDefinition.realmRefKind }}
  {{- if hasKey $glyphDefinition "advMappers" }}
  advancedProtocolMappers: {{ $glyphDefinition.advMappers }}
  {{- else }}
  advancedProtocolMappers: true
  {{- end }}
  clientId: {{ default (default (include "common.name" $root) $glyphDefinition.name) $glyphDefinition.clientId }}
  {{- if hasKey $glyphDefinition "directAccess" }}
  directAccess: {{ $glyphDefinition.directAccess }}
  {{- else }}
  directAccess: true
  {{- end }}
  {{- if $glyphDefinition.public }}
  public: true
  {{- end }}
  {{- if $glyphDefinition.protocol }}
  protocol: {{ $glyphDefinition.protocol }}
  {{- end }}
  {{- $protocol := default "openid-connect" $glyphDefinition.protocol }}
  {{- if and (not $glyphDefinition.public) (ne $protocol "saml") $glyphDefinition.secret }}
  secret: {{ printf "$%s:client_secret" $glyphDefinition.secret }}
  {{- else if and (not $glyphDefinition.public) (ne $protocol "saml") }}
  secret: {{ printf "$keycloak-client-%s:client_secret" (default (include "common.name" $root) $glyphDefinition.name) }}
  {{- end }}
  webUrl: {{ required "glyphDefinition.webUrl is required" $glyphDefinition.webUrl }}
  {{- if hasKey $glyphDefinition "stdFlow" }}
  standardFlowEnabled: {{ $glyphDefinition.stdFlow }}
  {{- else }}
  standardFlowEnabled: true
  {{- end }}
  {{- $attributes := default dict $glyphDefinition.attributes }}
  {{- if hasKey $attributes "authService" }}
  authorizationServicesEnabled: {{ $attributes.authService }}
  {{- end }}
  {{- if or $attributes $glyphDefinition.rawAttributes }}
  attributes:
    {{- if $attributes.logoutURL }}
    post.logout.redirect.uris: {{ $attributes.logoutURL }}
    {{- end }}
    {{- if hasKey $attributes "oauth2Grant" }}
    oauth2.device.authorization.grant.enabled: {{ $attributes.oauth2Grant | toString | quote }}
    {{- end }}
    {{- if $glyphDefinition.protocol }}
    protocol: {{ $glyphDefinition.protocol }}
    {{- end }}
    {{- range $key, $value := default dict $glyphDefinition.rawAttributes }}
    {{ $key }}: {{ $value | quote }}
    {{- end }}
  {{- end }}
  {{- if $glyphDefinition.defaultClientScopes }}
  defaultClientScopes:
  {{- range $glyphDefinition.defaultClientScopes }}
    - {{ . }}
  {{- end }}
  {{- end }}
  {{- if $glyphDefinition.redirectUris }}
  redirectUris:
  {{- range $glyphDefinition.redirectUris }}
    - {{ . }}
  {{- end }}
  {{- end }}
  {{- if $glyphDefinition.optionalClientScopes }}
  optionalClientScopes:
  {{- range $glyphDefinition.optionalClientScopes }}
    - {{ . }}
  {{- end }}
  {{- end }}
  {{- if $glyphDefinition.clientRoles }}
  clientRoles:
  {{- range $glyphDefinition.clientRoles }}
    - {{ . }}
  {{- end }}
  {{- end }}
  {{- if $glyphDefinition.webOrigins }}
  webOrigins:
  {{- range $glyphDefinition.webOrigins }}
    - {{ . }}
  {{- end }}
  {{- end }}
  {{- if ($glyphDefinition.serviceAccount).enabled }}
  serviceAccount:
    enabled: true
    {{- if $glyphDefinition.serviceAccount.clientRoles }}
    clientRoles:
    {{- range $glyphDefinition.serviceAccount.clientRoles }}
      - {{ toYaml . | nindent 8 }}
    {{- end }}
    {{- end }}
  {{- end }}
{{- end }}
