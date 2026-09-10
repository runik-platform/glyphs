{{/*Runik Platform
Copyright (C) 2023 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

keycloak.user creates KeycloakRealmUser resources for user management in Keycloak.
Uses the EDP Keycloak Operator CRDs.

Parameters:
- $root: Chart root context (index . 0)
- $glyphDefinition: User configuration object (index . 1)

Required Configuration:
- glyphDefinition.email: User email address
- glyphDefinition.realmRef: Keycloak realm name

Optional Configuration:
- glyphDefinition.name: Resource name (defaults to common.name)
- glyphDefinition.username: Username (defaults to email)
- glyphDefinition.firstName: User's first name
- glyphDefinition.lastName: User's last name
- glyphDefinition.enabled: Enable/disable user (default: true)
- glyphDefinition.emailVerified: Email verification status (default: true)
- glyphDefinition.groups: List of groups user belongs to
- glyphDefinition.realmRoles: List of realm roles assigned to the user. This
  maps to the EDP operator's `spec.roles` field.
- glyphDefinition.clientRoles: List of client-role assignments
- glyphDefinition.requiredUserActions: List of required actions
- glyphDefinition.passwordSecret: K8s Secret reference for initial password
  - name: Secret name in the same namespace as the user
  - key:  Secret key holding the password
  - temporary: When true, Keycloak marks the password as temporary and
    auto-adds UPDATE_PASSWORD to requiredActions on first login

Usage: {{- include "keycloak.user" (list $root $glyph) }}
*/}}
{{- define "keycloak.user" }}
{{- $root := index . 0 -}}
{{- $glyphDefinition := index . 1}}
---
apiVersion: v1.edp.epam.com/v1
kind: KeycloakRealmUser
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
  username: {{ default $glyphDefinition.email $glyphDefinition.username }}
  email: {{ required "glyphDefinition.email is required" $glyphDefinition.email }}
  {{- if $glyphDefinition.firstName }}
  firstName: {{ $glyphDefinition.firstName }}
  {{- end }}
  {{- if $glyphDefinition.lastName }}
  lastName: {{ $glyphDefinition.lastName }}
  {{- end }}
  {{- if hasKey $glyphDefinition "enabled" }}
  enabled: {{ $glyphDefinition.enabled }}
  {{- else }}
  enabled: true
  {{- end }}
  {{- if hasKey $glyphDefinition "emailVerified" }}
  emailVerified: {{ $glyphDefinition.emailVerified }}
  {{- else }}
  emailVerified: true
  {{- end }}
  keepResource: true
  {{- with $glyphDefinition.requiredUserActions }}
  requiredUserActions: {{ . | toJson }}
  {{- end }}
  {{- with $glyphDefinition.passwordSecret }}
  passwordSecret:
    name: {{ required "passwordSecret.name is required" .name | quote }}
    key: {{ required "passwordSecret.key is required" .key | quote }}
    temporary: {{ default false .temporary }}
  {{- end }}
  {{- if $glyphDefinition.groups }}
  groups:
  {{- range $glyphDefinition.groups }}
    - {{ . }}
  {{- end }}
  {{- end }}
  {{- if $glyphDefinition.realmRoles }}
  roles:
  {{- range $glyphDefinition.realmRoles }}
    - {{ . }}
  {{- end }}
  {{- end }}
  {{- if $glyphDefinition.clientRoles }}
  clientRoles:
    {{- toYaml $glyphDefinition.clientRoles | nindent 4 }}
  {{- end }}
{{- end }}
