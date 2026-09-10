{{/*Runik Platform
Copyright (C) 2025 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

vault.databaseEngine — a CONNECTION (DatabaseSecretEngineConfig) under a Vault
database secrets-engine mount. Engine-agnostic: the per-engine charts
(postgresql, mongodb, ...) supply pluginName + the connection string; the CRD
shape lives here.

Canonical Runik cardinality: one mount per spell → one or more physical database
connections → one or more credential roles. Explicit `databaseMount` values keep
the former shared-mount behavior during migration. Mount, connection and role
remain separate concerns, hence separate files:
  secret-engine-mount.tpl  vault.secretEngineMount  (the mount — usually infra)
  database-engine.tpl      vault.databaseEngine     (a connection — this file)
  database-role.tpl        vault.databaseRole       (a role)

Authenticates as the Vault admin (vault.connect "force") and lands in the Vault
server namespace by default (override: configNamespace) — writing Vault config is
privileged, not the app's job.

Normalized optional parameters owned by this glyph:
  passwordAuthentication  password | scram-sha-256 (default: password)
  rootRotation            boolean                     (default: false)
  rootRotationPeriod      Go duration                 (default: 0s)

`0s` disables recurring rotation. Root rotation itself is gated independently
by `rootRotation`; when that flag is false, the operator never enters its root
password rotation flow.
*/}}
{{- define "vault.databaseEngine" -}}
{{- $root := index . 0 -}}
{{- $g := index . 1 -}}
{{- $passwordAuthentication := "password" -}}
{{- if and (hasKey $g "passwordAuthentication") (not (kindIs "invalid" $g.passwordAuthentication)) -}}
  {{- if not (kindIs "string" $g.passwordAuthentication) -}}
    {{- fail "vault.databaseEngine: passwordAuthentication must be a string" -}}
  {{- end -}}
  {{- if $g.passwordAuthentication -}}
    {{- $passwordAuthentication = $g.passwordAuthentication -}}
  {{- end -}}
{{- end -}}
{{- if not (has $passwordAuthentication (list "password" "scram-sha-256")) -}}
  {{- fail "vault.databaseEngine: passwordAuthentication must be password or scram-sha-256" -}}
{{- end -}}
{{- $rootRotation := false -}}
{{- if and (hasKey $g "rootRotation") (not (kindIs "invalid" $g.rootRotation)) -}}
  {{- if not (kindIs "bool" $g.rootRotation) -}}
    {{- fail "vault.databaseEngine: rootRotation must be a boolean" -}}
  {{- end -}}
  {{- $rootRotation = $g.rootRotation -}}
{{- end -}}
{{- $rootRotationPeriod := "0s" -}}
{{- if and (hasKey $g "rootRotationPeriod") (not (kindIs "invalid" $g.rootRotationPeriod)) -}}
  {{- if not (kindIs "string" $g.rootRotationPeriod) -}}
    {{- fail "vault.databaseEngine: rootRotationPeriod must be a Go duration string" -}}
  {{- end -}}
  {{- if $g.rootRotationPeriod -}}
    {{- $rootRotationPeriod = $g.rootRotationPeriod -}}
  {{- end -}}
{{- end -}}
{{- $vaultServers := get (include "runic-system.runic-indexer" (list $root.Values.lexicon (merge (default dict $g.selector) (dict "provider" "operator")) "secret-store" $root.Values.chapter.name) | fromJson) "results" -}}
{{- if not $vaultServers -}}
  {{- fail "vault.databaseEngine: no 'type: secret-store' (provider: operator) entry found in lexicon" -}}
{{- end }}
{{- $vaultConf := index $vaultServers 0 -}}
{{- /* The caller resolves either the canonical per-spell mount or an explicit
       legacy mount. This glyph only registers a connection inside it. */ -}}
{{- $mount := default "database" $g.databaseMount -}}
{{- $ns := default $vaultConf.namespace $g.configNamespace -}}
---
apiVersion: redhatcop.redhat.io/v1alpha1
kind: DatabaseSecretEngineConfig
metadata:
  name: {{ required "vault.databaseEngine: name is required" $g.name }}
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
  {{- if or $g.serviceAccount $g.customRole }}
  {{- include "vault.connect" (list $root $vaultConf "" (default "" $g.serviceAccount) (default "" $g.customRole)) | nindent 2 }}
  {{- else }}
  {{- include "vault.connect" (list $root $vaultConf "force") | nindent 2 }}
  {{- end }}
  pluginName: {{ required "vault.databaseEngine: pluginName is required" $g.pluginName }}
  allowedRoles:
    {{- toYaml (default (list "*") $g.allowedRoles) | nindent 4 }}
  {{- /* Most database plugins consume connection_url with universal
         {{username}}/{{password}} templating. Some plugins, notably
         Elasticsearch, reject connection_url and consume a database-specific
         `url` field instead. Those callers must opt out explicitly and provide
         databaseSpecificConfig. */}}
  {{- if $g.omitConnectionURL }}
  {{- if not $g.databaseSpecificConfig }}
  {{- fail "vault.databaseEngine: omitConnectionURL requires databaseSpecificConfig" }}
  {{- end }}
  {{- else }}
  connectionURL: {{ if $g.connectionURL }}{{ $g.connectionURL }}{{ else }}{{ required "vault.databaseEngine: connectionPrefix is required" $g.connectionPrefix }}{{`{{username}}`}}:{{`{{password}}`}}{{ required "vault.databaseEngine: connectionSuffix is required" $g.connectionSuffix }}{{ end }}
  {{- end }}
  passwordAuthentication: {{ $passwordAuthentication | quote }}
  {{- with $g.databaseSpecificConfig }}
  databaseSpecificConfig:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- if hasKey $g "disableEscaping" }}
  disableEscaping: {{ $g.disableEscaping }}
  {{- end }}
  {{- if hasKey $g "verifyConnection" }}
  verifyConnection: {{ $g.verifyConnection }}
  {{- end }}
  {{- with $g.passwordPolicy }}
  passwordPolicy: {{ . }}
  {{- end }}
  {{- with $g.pluginVersion }}
  pluginVersion: {{ . }}
  {{- end }}
  {{- /* Root username is static (spec.username takes precedence); the password
         comes from a K8s basic-auth secret in the config namespace. */ -}}
  {{- with $g.username }}
  username: {{ . }}
  {{- end }}
  rootCredentials:
    {{- if $g.rootVaultSecretPath }}
    vaultSecret:
      path: {{ $g.rootVaultSecretPath }}
    {{- else if $g.vaultSecretPath }}
    vaultSecret:
      path: {{ include "generateSecretPath" (list $root (dict "name" $g.name "path" $g.vaultSecretPath) $vaultConf "") }}
    {{- else }}
    secret:
      name: {{ required "vault.databaseEngine: credentialsSecret, vaultSecretPath or rootVaultSecretPath is required" $g.credentialsSecret }}
    {{- end }}
    passwordKey: {{ default "password" $g.passwordKey }}
    usernameKey: {{ default "username" $g.usernameKey }}
  path: {{ $mount }}
  rootPasswordRotation:
  {{- if $rootRotation }}
    enable: true
  {{- end }}
    rotationPeriod: {{ $rootRotationPeriod | quote }}
  {{- with $g.rootRotationStatements }}
  rootRotationStatements:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{ println -}}
{{- end -}}
