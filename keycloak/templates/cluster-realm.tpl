{{/*Runik Platform
Copyright (C) 2023 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

keycloak.clusterRealm creates ClusterKeycloakRealm resources for cluster-scoped realm configuration.
Uses the EDP Keycloak Operator CRDs (v1alpha1).

ClusterKeycloakRealm is cluster-scoped and can be referenced from any namespace,
making it ideal for multi-namespace deployments like covenant.

Parameters:
- $root: Chart root context (index . 0)
- $glyphDefinition: Realm configuration object (index . 1)

Required Configuration:
- glyphDefinition.realmName: Realm name/identifier
- glyphDefinition.clusterKeycloakRef: Name of ClusterKeycloak instance

Optional Configuration:
- glyphDefinition.name: Resource name (defaults to common.name)
- glyphDefinition.displayName: Realm display name
- glyphDefinition.passwordPolicy: List of password policy rules
- glyphDefinition.themes: Theme configuration matching the operator CRD
- glyphDefinition.sessions: Session configuration matching the operator CRD
- glyphDefinition.eventConfig: Event logging configuration
- glyphDefinition.tokenSettings: Token lifetime settings

Usage: {{- include "keycloak.clusterRealm" (list $root $glyph) }}
*/}}
{{- define "keycloak.clusterRealm" }}
{{- $root := index . 0 -}}
{{- $glyphDefinition := index . 1}}
---
apiVersion: v1.edp.epam.com/v1alpha1
kind: ClusterKeycloakRealm
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
  clusterKeycloakRef: {{ required "glyphDefinition.clusterKeycloakRef is required for ClusterKeycloakRealm" $glyphDefinition.clusterKeycloakRef }}
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
