{{/*Runik Platform
Copyright (C) 2023 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

vault.secret creates ExternalSecret resources for HashiCorp Vault integration.
Follows standard glyph parameter pattern: (list $root $glyphDefinition).

Parameters:
- $root: Chart root context (index . 0)
- $glyphDefinition: Secret configuration object (index . 1)

Generation Types:
- generationType: "kv" (default) - KV v2 secrets, uses /data/ prefix
- generationType: "database" - Database dynamic credentials, requires databaseEngine and databaseRole
- generationType: "database-static" - Stable database identity managed by a
  DatabaseSecretEngineStaticRole, requires databaseCredsName

Path Resolution Examples (KV secrets):

path: "chapter" → /$spellbook/$chapter/publics/$secretName
path: "book" → /$spellbook/publics/$secretName
path: "/custom/path" → /custom/path/$secretName (absolute)
path: "summon" → /$spellbook/$chapter/$summonName/publics/$secretName

Database Credentials Example:

glyphs:
  vault:
    - type: secret
      name: myapp-db-creds
      generationType: "database"
      databaseEngine: "postgres"      # Name of postgres entry in lexicon
      databaseRole: "read-write"      # or "read-only"
      path: "chapter"                 # Optional, defaults to "chapter"
      format: env
      serviceAccount: myapp
      refreshPeriod: 30m
      keys:
        - username
        - password

Generates path: {secretPath}/{book}/{chapter}/publics/{databaseEngine}/creds/{databaseEngine}-{databaseRole}
Example: secret/mybook/prod/publics/postgres/creds/postgres-read-write

Static Database Credentials Example:

glyphs:
  vault:
    - type: secret
      name: myapp-db-creds
      generationType: "database-static"
      databaseCredsName: "postgres-myapp"
      format: env
      keys:
        - username
        - password

Generates path: db/$book/$chapter/$spell/static-creds/postgres-myapp

An explicit databaseMount preserves the former shared-mount behavior during
migration.

KV Secret Example:

glyphs:
  vault:
    - type: secret
      name: api-credentials
      format: env
      path: "chapter"
      keys:
        - api-key
        - api-secret

*/}}

{{- define "vault.secret" -}}
{{- $root := index . 0 -}}
{{- $glyphDefinition := index . 1 }}
{{- $vaultServer := get (include "runic-system.runic-indexer" (list $root.Values.lexicon (merge (default dict $glyphDefinition.selector) (dict "provider" "operator")) "secret-store" $root.Values.chapter.name ) | fromJson) "results" }}
{{- range $vaultConf := $vaultServer }}
{{- if ne false $glyphDefinition.random }}
  {{- if $glyphDefinition.randomKeys }}
    {{- range $keyName := $glyphDefinition.randomKeys }}
{{ include "vault.randomSecret" (list $root (merge (dict "randomKey" $keyName "name" (printf "%s-%s" $glyphDefinition.name ($keyName | lower | replace "_" "-"))) $glyphDefinition) ) }}
    {{- end }}
  {{- else if or $glyphDefinition.randomKey $glyphDefinition.random }}
{{ include "vault.randomSecret" (list $root $glyphDefinition ) }}
  {{- end }}
{{- end }}
---
apiVersion: redhatcop.redhat.io/v1alpha1
kind: VaultSecret
metadata:
  name: {{ $glyphDefinition.name }}
  {{- if $glyphDefinition.namespace }}
  namespace: {{ $glyphDefinition.namespace }}
  {{- end }}
  labels:
    {{- include "common.all.labels" $root | nindent 4 }}
    {{- with $glyphDefinition.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- $metadataAnnotations := include "common.annotations.map" (list $root (default dict $glyphDefinition.annotations) dict) | fromJson -}}
  {{- with $metadataAnnotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- if hasKey $glyphDefinition "refreshThreshold" }}
  refreshThreshold: {{ $glyphDefinition.refreshThreshold }}
  {{- with $glyphDefinition.refreshPeriod }}
  refreshPeriod: {{ . }}
  {{- end }}
  {{- else }}
  refreshThreshold: 90
  refreshPeriod: {{ default "3m0s" $glyphDefinition.refreshPeriod }}
  {{- end }}
  vaultSecretDefinitions:
  {{- if $glyphDefinition.randomKeys }}
    {{- range $keyName := $glyphDefinition.randomKeys }}
    - name: {{ $keyName | lower | replace "_" "-" }}
      requestType: GET
      path: {{ include "generateSecretPath" (list $root (dict "name" (printf "%s-%s" $glyphDefinition.name ($keyName | lower | replace "_" "-")) "path" $glyphDefinition.path) $vaultConf "") }}
      {{- if $glyphDefinition.customRole }}
      {{- include "vault.connect" (list $root $vaultConf "" (default "" $glyphDefinition.serviceAccount) $glyphDefinition.customRole) | nindent 6 }}
      {{- else }}
      {{- include "vault.connect" (list $root $vaultConf "" (default "" $glyphDefinition.serviceAccount)) | nindent 6 }}
      {{- end }}
    {{- end }}
  {{- else }}
    - name: secret
      requestType: GET
      {{- $generationType := default "kv" $glyphDefinition.generationType }}
      {{- if eq $generationType "database-static" }}
      {{- $staticRoleName := required "databaseCredsName is required when generationType=database-static" $glyphDefinition.databaseCredsName }}
      {{- if $glyphDefinition.databaseMount }}
      path: {{ $glyphDefinition.databaseMount }}/static-creds/{{ $staticRoleName }}
      {{- else }}
      {{- $coordinates := include "vault.databaseCoordinates" (list $root (dict "name" $staticRoleName "selector" $glyphDefinition.selector) "static") | fromJson }}
      path: {{ $coordinates.path }}
      {{- end }}
      {{- else if eq $generationType "database" }}
      {{- /* databaseCredsName overrides the default `<engine>-<role>` creds name,
             for roles that aren't named that way (e.g. a custom `dba` role whose
             Vault path is database/creds/dba). */ -}}
      {{- $dynamicRoleName := "" }}
      {{- if $glyphDefinition.databaseCredsName }}
      {{- $dynamicRoleName = $glyphDefinition.databaseCredsName }}
      {{- else }}
      {{- $engineName := required "databaseEngine is required when generationType=database" $glyphDefinition.databaseEngine }}
      {{- $roleName := required "databaseRole is required when generationType=database" $glyphDefinition.databaseRole }}
      {{- $dynamicRoleName = printf "%s-%s" $engineName $roleName }}
      {{- end }}
      {{- if $glyphDefinition.databaseMount }}
      path: {{ $glyphDefinition.databaseMount }}/creds/{{ $dynamicRoleName }}
      {{- else }}
      {{- $coordinates := include "vault.databaseCoordinates" (list $root (dict "name" $dynamicRoleName "selector" $glyphDefinition.selector) "dynamic") | fromJson }}
      path: {{ $coordinates.path }}
      {{- end }}
      {{- else }}
      {{- /* sourceName overrides the secret name used to compute the READ path
             (default: name). Lets a VaultSecret with a distinct CR/output name
             read another secret's KV path (e.g. mirror a secret into another ns
             without a name collision). */ -}}
      {{- $readGlyph := merge (dict "name" (default $glyphDefinition.name $glyphDefinition.sourceName)) $glyphDefinition }}
      path: {{ include "generateSecretPath" ( list $root $readGlyph $vaultConf "" ) }}
      {{- end }}
      {{- if has $generationType (list "database" "database-static") }}
      {{- $databaseAuthRole := default (default (include "common.name" $root) $glyphDefinition.serviceAccount) $glyphDefinition.customRole }}
      {{- if not $glyphDefinition.databaseMount }}{{- $databaseAuthRole = include "vault.databaseAuthRole" (list $root (default "" $glyphDefinition.serviceAccount) $glyphDefinition.customRole) }}{{- end }}
      {{- include "vault.connect" (list $root $vaultConf "" (default "" $glyphDefinition.serviceAccount) $databaseAuthRole) | nindent 6 }}
      {{- else if $glyphDefinition.customRole }}
      {{- include "vault.connect" (list $root $vaultConf "" (default "" $glyphDefinition.serviceAccount) $glyphDefinition.customRole) | nindent 6 }}
      {{- else }}
      {{- include "vault.connect" (list $root $vaultConf "" (default "" $glyphDefinition.serviceAccount)) | nindent 6 }}
      {{- end }}
  {{- end }}
  output:
    name: {{ default $glyphDefinition.name $glyphDefinition.nameOverwrite }}
    labels:
      {{- include "common.all.labels" $root | nindent 6 }}
      {{- with $glyphDefinition.labels }}
      {{- toYaml . | nindent 6 }}
      {{- end }}
    {{- $outputAnnotations := include "common.annotations.map" (list $root (default dict $glyphDefinition.annotations) dict) | fromJson -}}
    {{- with $outputAnnotations }}
    annotations:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    stringData:
    {{- $format := default "plain" $glyphDefinition.format }}
    {{- if eq $format "env" }} #tiene q haber una forma de hacer q esto funcione con un range del lado del operator para q no hagan falta las keys
      {{- range $key := $glyphDefinition.keys }}
        {{ upper $key | replace "-" "_" }}: '{{ default (printf `{{ .secret.%s }}` $key ) }}'
      {{- end }}
      {{-  if $glyphDefinition.staticData }}
        {{- range $static, $data := $glyphDefinition.staticData }}
        {{ upper $static | replace "-" "_" }}: {{ $data }}
        {{- end }}
      {{- end }}
      {{- with $glyphDefinition.templateData }}
        {{- range $key, $value := . }}
        {{ $key }}: {{ $value | quote }}
        {{- end }}
      {{- end }}
      {{- if $glyphDefinition.randomKeys }}
        {{- range $keyName := $glyphDefinition.randomKeys }}
        {{ upper $keyName | replace "-" "_" }}: '{{ printf `{{ index . "%s" "%s" }}` ($keyName | lower | replace "_" "-") $keyName }}'
        {{- end }}
      {{- else if $glyphDefinition.randomKey }}
        {{ upper $glyphDefinition.randomKey | replace "-" "_" }}: '{{ printf `{{ .secret.%s }}` $glyphDefinition.randomKey  }}'
      {{- else if $glyphDefinition.random }}
        PASSWORD: '{{ printf `{{ .secret.password }}` }}'
      {{- end }}
    {{- else if eq $format "json" }}
      {{ default $glyphDefinition.name $glyphDefinition.key }}: '{{ `{{ .secret | toJson  }}` }}'
    {{- else if eq $format "b64" }}
      {{ default $glyphDefinition.name $glyphDefinition.key }}: '{{ `{{ .secret.b64 }}` }}'
    {{- else if eq $format "yaml" }}
      {{ default $glyphDefinition.name $glyphDefinition.key }}: '{{ `{{ .secret | toYaml  }}` }}'
    {{- else if eq $format "plain" }}
      {{- range $key := default list $glyphDefinition.keys }}
        {{ $key  }}: '{{ default (printf `{{ .secret.%s }}` $key ) }}'
      {{- end }}
      {{-  if $glyphDefinition.staticData }}
        {{- range $static, $data := $glyphDefinition.staticData }}
        {{ $static }}: {{ $data }}
        {{- end }}
      {{- end }}
      {{- with $glyphDefinition.templateData }}
        {{- range $key, $value := . }}
        {{ $key }}: {{ $value | quote }}
        {{- end }}
      {{- end }}
      {{- if $glyphDefinition.randomKeys }}
        {{- range $keyName := $glyphDefinition.randomKeys }}
        {{ $keyName }}: '{{ printf `{{ index . "%s" "%s" }}` ($keyName | lower | replace "_" "-") $keyName }}'
        {{- end }}
      {{- else if $glyphDefinition.randomKey }}
        {{ $glyphDefinition.randomKey  }}: '{{ printf `{{ index .secret "%s" }}` $glyphDefinition.randomKey  }}'
      {{- else if and $glyphDefinition.random (not $glyphDefinition.randomKey) }}
        password: '{{ printf `{{ .secret.password }}` }}'
      {{- end }}
    {{- end }}
    type: {{ default "Opaque" $glyphDefinition.secretType }}
{{- end }}
{{ end }}
