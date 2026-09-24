{{/*Runik Platform
Copyright (C) 2026 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

netbird.identitySync creates a NetBirdIdentitySync (netbird.io/v1alpha1).
It turns selected Keycloak realm roles into one complete, authoritative
identity source reconciled by the complementary operator.

Required:
- $definition.provider.{baseUrl,realm,clientId,credentialsSecretRef}
- $definition.realmRoles: non-empty unique list of Keycloak realm-role names

Optional:
- $definition.source (defaults to glyph name)
- $definition.instanceRef or $definition.instanceSelector
- $definition.instanceId (compatibility assertion against the resolved instance)
- $definition.adoptExistingUsers (defaults to false)
- $definition.adoptExistingJWTGroups (defaults to false)
- $definition.pollIntervalSeconds (defaults to 60; range 15-3600)
- $definition.deletionPolicy (defaults to Retain; Disable is opt-in)

Realm roles are provider identities, not API-managed netbird-group entries, so
this renderer deliberately does not perform lexicon discovery.

Usage: {{- include "netbird.identitySync" (list $root $glyph) }}
*/}}
{{- define "netbird.identitySync" -}}
{{- $root := index . 0 -}}
{{- $definition := index . 1 -}}
{{- $instance := include "netbird.instanceEntry" (list $root $definition "netbird.identitySync") | fromJson }}
{{- $source := default $definition.name $definition.source -}}
{{- if or (gt (len $source) 255) (not (regexMatch "^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$" $source)) -}}
  {{- fail "netbird.identitySync: source must be a lowercase stable identifier" -}}
{{- end -}}
{{- $instanceID := get $instance "instanceId" -}}
{{- if and $definition.instanceId (ne $definition.instanceId $instanceID) -}}
  {{- fail (printf "netbird.identitySync: instanceId %q conflicts with selected netbird-instance %q" $definition.instanceId $instanceID) -}}
{{- end -}}
{{- if or (not (kindIs "string" $instanceID)) (empty $instanceID) (gt (len $instanceID) 255) -}}
  {{- fail "netbird.identitySync: instanceId must be a non-empty string of at most 255 characters" -}}
{{- end -}}

{{- $provider := required "netbird.identitySync: provider is required" $definition.provider -}}
{{- if not (kindIs "map" $provider) -}}
  {{- fail "netbird.identitySync: provider must be an object" -}}
{{- end -}}
{{- $baseURL := required "netbird.identitySync: provider.baseUrl is required" $provider.baseUrl -}}
{{- if or (not (kindIs "string" $baseURL)) (not (regexMatch "^https?://[^[:space:]]+$" $baseURL)) -}}
  {{- fail "netbird.identitySync: provider.baseUrl must be an absolute HTTP(S) URL" -}}
{{- end -}}
{{- $realm := required "netbird.identitySync: provider.realm is required" $provider.realm -}}
{{- if not (kindIs "string" $realm) -}}
  {{- fail "netbird.identitySync: provider.realm must be a string" -}}
{{- end -}}
{{- $clientID := required "netbird.identitySync: provider.clientId is required" $provider.clientId -}}
{{- if not (kindIs "string" $clientID) -}}
  {{- fail "netbird.identitySync: provider.clientId must be a string" -}}
{{- end -}}
{{- $secretRef := required "netbird.identitySync: provider.credentialsSecretRef is required" $provider.credentialsSecretRef -}}
{{- include "netbird.instance.secretRef" (list $secretRef "netbird.identitySync provider.credentialsSecretRef") -}}

{{- $realmRoles := required "netbird.identitySync: realmRoles is required" $definition.realmRoles -}}
{{- if not (kindIs "slice" $realmRoles) -}}
  {{- fail "netbird.identitySync: realmRoles must be a non-empty list" -}}
{{- end -}}
{{- $seenRoles := dict -}}
{{- range $index, $role := $realmRoles -}}
  {{- if or (not (kindIs "string" $role)) (empty $role) -}}
    {{- fail (printf "netbird.identitySync: realmRoles[%d] must be a non-empty string" $index) -}}
  {{- end -}}
  {{- if hasKey $seenRoles $role -}}
    {{- fail (printf "netbird.identitySync: realmRoles must be unique; duplicate %q" $role) -}}
  {{- end -}}
  {{- $_ := set $seenRoles $role true -}}
{{- end -}}

{{- $adoptUsers := false -}}
{{- if hasKey $definition "adoptExistingUsers" -}}
  {{- if not (kindIs "bool" $definition.adoptExistingUsers) -}}
    {{- fail "netbird.identitySync: adoptExistingUsers must be a boolean" -}}
  {{- end -}}
  {{- $adoptUsers = $definition.adoptExistingUsers -}}
{{- end -}}
{{- $adoptGroups := false -}}
{{- if hasKey $definition "adoptExistingJWTGroups" -}}
  {{- if not (kindIs "bool" $definition.adoptExistingJWTGroups) -}}
    {{- fail "netbird.identitySync: adoptExistingJWTGroups must be a boolean" -}}
  {{- end -}}
  {{- $adoptGroups = $definition.adoptExistingJWTGroups -}}
{{- end -}}
{{- $poll := int (default 60 $definition.pollIntervalSeconds) -}}
{{- if or (lt $poll 15) (gt $poll 3600) -}}
  {{- fail "netbird.identitySync: pollIntervalSeconds must be between 15 and 3600" -}}
{{- end -}}
{{- $deletionPolicy := default "Retain" $definition.deletionPolicy -}}
{{- if not (has $deletionPolicy (list "Retain" "Disable")) -}}
  {{- fail "netbird.identitySync: deletionPolicy must be Retain or Disable" -}}
{{- end -}}
---
apiVersion: netbird.io/v1alpha1
kind: NetBirdIdentitySync
metadata:
  name: {{ $definition.name }}
  {{- with $definition.namespace }}
  namespace: {{ . }}
  {{- end }}
  labels:
    {{- include "common.all.labels" $root | nindent 4 }}
    {{- with $definition.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- with $definition.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  source: {{ $source | quote }}
  instanceId: {{ $instanceID | quote }}
  provider:
    baseUrl: {{ $baseURL | quote }}
    realm: {{ $realm | quote }}
    clientId: {{ $clientID | quote }}
    credentialsSecretRef:
      name: {{ $secretRef.name | quote }}
      key: {{ $secretRef.key | quote }}
  realmRoles:
    {{- range $role := $realmRoles }}
    - {{ $role | quote }}
    {{- end }}
  adoptExistingUsers: {{ $adoptUsers }}
  adoptExistingJWTGroups: {{ $adoptGroups }}
  pollIntervalSeconds: {{ $poll }}
  deletionPolicy: {{ $deletionPolicy | quote }}
{{ end }}
