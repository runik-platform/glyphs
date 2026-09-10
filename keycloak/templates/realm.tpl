{{/*Runik Platform
Copyright (C) 2023 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

keycloak.realm creates KeycloakRealm resources for realm configuration.
Uses the EDP Keycloak Operator CRDs.

Parameters:
- $root: Chart root context (index . 0)
- $glyphDefinition: Realm configuration object (index . 1)

Required Configuration:
- glyphDefinition.realmName: Realm name/identifier
- glyphDefinition.keycloakRef: Reference to Keycloak instance

Optional Configuration:
- glyphDefinition.name: Resource name (defaults to common.name)
- glyphDefinition.displayName: Realm display name
- glyphDefinition.passwordPolicy: List of password policy rules
- glyphDefinition.themes: Theme configuration matching the operator CRD
- glyphDefinition.sessions: Session configuration matching the operator CRD
- glyphDefinition.eventConfig: Event logging configuration
- glyphDefinition.tokenSettings: Token lifetime settings

Note: The EDP Keycloak Operator CRD does not support 'enabled' or 'sslRequired' fields.
Realms are enabled by default when created. SSL configuration must be done at the
Keycloak server level, not per-realm.

Usage: {{- include "keycloak.realm" (list $root $glyph) }}
*/}}
{{- define "keycloak.realm" }}
{{- $root := index . 0 -}}
{{- $glyphDefinition := index . 1}}
---
apiVersion: v1.edp.epam.com/v1
kind: KeycloakRealm
metadata:
  name: {{ default (include "common.name" $root) $glyphDefinition.name }}
  labels:
    {{- include "common.labels" $root | nindent 4}}
  {{- with $glyphDefinition.annotations }}
  annotations:
    {{- toYaml . | nindent 4}}
  {{- end }}
spec:
  realmName: {{ required "glyphDefinition.realmName is required" $glyphDefinition.realmName }}
  {{- if $glyphDefinition.displayName }}
  displayName: {{ $glyphDefinition.displayName }}
  {{- end }}
  keycloakRef:
    name: {{ required "glyphDefinition.keycloakRef is required" $glyphDefinition.keycloakRef }}
    kind: {{ default "Keycloak" $glyphDefinition.keycloakRefKind }}
  {{- if $glyphDefinition.passwordPolicy }}
  passwordPolicy:
  {{- range $glyphDefinition.passwordPolicy }}
    - type: {{ .type }}
      value: {{ .value | quote }}
  {{- end }}
  {{- end }}
  {{- with $glyphDefinition.themes }}
  themes:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $glyphDefinition.sessions }}
  sessions:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- if $glyphDefinition.eventConfig }}
  realmEventConfig:
    {{- if hasKey $glyphDefinition.eventConfig "adminEventsDetailsEnabled" }}
    adminEventsDetailsEnabled: {{ $glyphDefinition.eventConfig.adminEventsDetailsEnabled }}
    {{- else }}
    adminEventsDetailsEnabled: true
    {{- end }}
    {{- if hasKey $glyphDefinition.eventConfig "adminEventsEnabled" }}
    adminEventsEnabled: {{ $glyphDefinition.eventConfig.adminEventsEnabled }}
    {{- else }}
    adminEventsEnabled: true
    {{- end }}
    {{- if $glyphDefinition.eventConfig.enabledEventTypes }}
    enabledEventTypes:
    {{- range $glyphDefinition.eventConfig.enabledEventTypes }}
      - {{ . }}
    {{- end }}
    {{- end }}
    {{- if hasKey $glyphDefinition.eventConfig "eventsEnabled" }}
    eventsEnabled: {{ $glyphDefinition.eventConfig.eventsEnabled }}
    {{- else }}
    eventsEnabled: true
    {{- end }}
    eventsExpiration: {{ default 15000 $glyphDefinition.eventConfig.eventsExpiration }}
    {{- if $glyphDefinition.eventConfig.eventsListeners }}
    eventsListeners:
    {{- range $glyphDefinition.eventConfig.eventsListeners }}
      - {{ . }}
    {{- end }}
    {{- else }}
    eventsListeners:
      - jboss-logging
    {{- end }}
  {{- else }}
  realmEventConfig:
    adminEventsDetailsEnabled: true
    adminEventsEnabled: true
    eventsEnabled: true
    eventsExpiration: 15000
    eventsListeners:
      - jboss-logging
  {{- end }}
  {{- $tokenDefaults := dict "accessTokenLifespan" 300 "accessCodeLifespan" 300 "accessToken" 300 "actionTokenGeneratedByAdminLifespan" 300 "actionTokenGeneratedByUserLifespan" 300 "refreshTokenMaxReuse" 0 "revokeRefreshToken" true "defaultSignatureAlgorithm" "RS256" -}}
  {{- $tokenSettings := mergeOverwrite $tokenDefaults (deepCopy (default dict $glyphDefinition.tokenSettings)) -}}
{{ printf "\n" }}  tokenSettings:
    {{- toYaml $tokenSettings | nindent 4 }}
{{- end }}
