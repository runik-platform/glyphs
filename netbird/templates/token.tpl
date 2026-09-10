{{/*Runik Platform
Copyright (C) 2025 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

netbird.token creates a NetBirdToken (netbird.io/v1alpha1) — a Personal Access
Token for a user. The operator writes the token value into the referenced Secret.

Required:
- $definition.name (auto-injected)
- one of: $definition.userRef | $definition.userSelector (type `netbird-user`)
- $definition.secret.name, $definition.secret.key

Optional:
- $definition.nbName
- $definition.expiresInDays (CRD default: 90)
- $definition.renewBeforeDays (controller default: min(7, expiresInDays - 1))

NetBirdUser is no longer a managed CRD. userRef is the existing user's name or
email. userSelector remains available for lexicon entries that describe users
managed outside Kubernetes (for example through OIDC/JIT provisioning).

Usage: {{- include "netbird.token" (list $root $glyph) }}
*/}}
{{- define "netbird.token" }}
{{- $root := index . 0 -}}
{{- $definition := index . 1 }}
{{- $userRef := get (include "netbird.singleRef" (list $root $definition.userRef (default (dict) $definition.userSelector) "netbird-user" "netbird.token user") | fromJson) "ref" }}
{{- $secret := required "netbird.token: secret is required (secret.name and secret.key)" $definition.secret }}
---
apiVersion: netbird.io/v1alpha1
kind: NetBirdToken
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
  name: {{ default $definition.name $definition.nbName | quote }}
  userRef: {{ $userRef | quote }}
  {{- if hasKey $definition "expiresInDays" }}
  expiresInDays: {{ $definition.expiresInDays }}
  {{- end }}
  {{- if hasKey $definition "renewBeforeDays" }}
  renewBeforeDays: {{ $definition.renewBeforeDays }}
  {{- end }}
  secretRef:
    name: {{ required "netbird.token: secret.name is required" $secret.name | quote }}
    key: {{ required "netbird.token: secret.key is required" $secret.key | quote }}
{{- end }}
