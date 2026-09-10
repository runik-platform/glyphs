{{/*Runik Platform
Copyright (C) 2023 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only
*/}}
{{- define "vault.randomSecret" -}}
{{- $root := index . 0 -}}
{{- $glyphDefinition := index . 1}}
{{- $vaultServer := get (include "runic-system.runic-indexer" (list $root.Values.lexicon (merge (default dict $glyphDefinition.selector) (dict "provider" "operator")) "secret-store" $root.Values.chapter.name ) | fromJson) "results" }}
{{- range $vaultConf := $vaultServer }}
---
apiVersion: redhatcop.redhat.io/v1alpha1
kind: RandomSecret
metadata:
  name: {{ $glyphDefinition.name }}
  {{- with $glyphDefinition.namespace }}
  namespace: {{ . }}
  {{- end }}
  labels:
    {{- include "common.all.labels" $root | nindent 4 }}
    {{- with $glyphDefinition.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- with $glyphDefinition.annotations }}
  annotations:
    {{- include "common.annotations" $root | nindent 4 }}
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- if $glyphDefinition.customRole }}
  {{- include "vault.connect" (list $root $vaultConf "" (default "" $glyphDefinition.serviceAccount) $glyphDefinition.customRole) | nindent 2 }}
  {{- else }}
  {{- include "vault.connect" (list $root $vaultConf "" (default "" $glyphDefinition.serviceAccount)) | nindent 2 }}
  {{- end }}
  isKVSecretsEngineV2: true
  {{- with $glyphDefinition.kvSecretRetainPolicy }}
  kvSecretRetainPolicy: {{ . }}
  {{- end }}
  path: {{ include "generateSecretPath" ( list $root $glyphDefinition $vaultConf "true" ) }}
  secretKey: {{ default "password" $glyphDefinition.randomKey }}
  secretFormat:
    passwordPolicyName: {{ default "simple-password-policy" $glyphDefinition.passPolicyName }}
  {{- if $glyphDefinition.refreshPeriod }}
  refreshPeriod: {{ $glyphDefinition.refreshPeriod }}
  {{- end }}
  {{- end }}
{{- end }}
