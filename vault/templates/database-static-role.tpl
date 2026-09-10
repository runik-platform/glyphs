{{/*Runik Platform
Copyright (C) 2026 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

vault.databaseStaticRole — a stable database identity managed by Vault. Unlike
vault.databaseRole, this maps one Vault role to one pre-existing SQL username
and rotates only that user's credential.

The caller owns the engine-specific rotation statements. This generic glyph
owns the DatabaseSecretEngineStaticRole CRD shape and Vault authentication.
*/}}
{{- define "vault.databaseStaticRole" -}}
{{- $root := index . 0 -}}
{{- $g := index . 1 -}}
{{- $vaultServers := get (include "runic-system.runic-indexer" (list $root.Values.lexicon (merge (default dict $g.selector) (dict "provider" "operator")) "secret-store" $root.Values.chapter.name) | fromJson) "results" -}}
{{- if not $vaultServers -}}
  {{- fail "vault.databaseStaticRole: no 'type: secret-store' (provider: operator) entry found in lexicon" -}}
{{- end -}}
{{- $vaultConf := index $vaultServers 0 -}}
{{- $mount := default "database" $g.databaseMount -}}
{{- $ns := default $vaultConf.namespace $g.configNamespace -}}
{{- $rotationPeriod := required "vault.databaseStaticRole: rotationPeriod is required (integer seconds, minimum 5)" $g.rotationPeriod -}}
{{- if lt (int $rotationPeriod) 5 -}}
  {{- fail "vault.databaseStaticRole: rotationPeriod must be at least 5 seconds" -}}
{{- end -}}
---
apiVersion: redhatcop.redhat.io/v1alpha1
kind: DatabaseSecretEngineStaticRole
metadata:
  name: {{ required "vault.databaseStaticRole: name is required" $g.name }}
  namespace: {{ $ns }}
  labels:
    {{- include "common.all.labels" $root | nindent 4 }}
    {{- with $g.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- $annotations := include "common.annotations.map" (list $root (default dict $g.annotations) dict) | fromJson -}}
  {{- with $annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- include "vault.connect" (list $root $vaultConf "force") | nindent 2 }}
  path: {{ $mount }}
  dBName: {{ required "vault.databaseStaticRole: dBName is required" $g.dBName }}
  username: {{ required "vault.databaseStaticRole: username is required" $g.username | quote }}
  rotationPeriod: {{ int $rotationPeriod }}
  rotationStatements:
    {{- toYaml (required "vault.databaseStaticRole: rotationStatements is required" $g.rotationStatements) | nindent 4 }}
  credentialType: password
  passwordCredentialConfig:
    {{- with $g.passwordPolicy }}
    passwordPolicy: {{ . }}
    {{- else }}
    {}
    {{- end }}
{{- end -}}
