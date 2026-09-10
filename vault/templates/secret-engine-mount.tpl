{{/*Runik Platform
Copyright (C) 2023 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

vault.secretEngineMount creates SecretEngineMount resources for Vault secret engines.
Follows standard glyph parameter pattern: (list $root $glyphDefinition).

Parameters:
- $root: Chart root context (index . 0)
- $glyphDefinition: Mount configuration object (index . 1)
  - mountType: Engine type (required: "database", "pki", "kv", etc.)
- path: Mount path (optional, defaults based on mountType)
- parentPath: Optional parent path. When set, `name` is the final path segment
  and Vault mounts the engine at `{parentPath}/{name}`.
  - description: Human-friendly description
  - config: Mount configuration overrides (optional)
  - options: Mount type-specific options (optional)
  - serviceAccount: ServiceAccount for Vault auth (optional)

Default Paths by mountType:
- database: "database-{book}-{chapter}"
- pki: "pki-{book}-{chapter}"
- kv: "kv-{book}-{chapter}"
- Custom: Use explicit path parameter

Example glyph definition:
  vault:
    - type: secretEngineMount
      mountType: database
      path: database-mybook-prod
      description: "Database secrets engine for dynamic credentials"
*/}}

{{- define "vault.secretEngineMount" -}}
{{- $root := index . 0 -}}
{{- $glyphDefinition := index . 1 }}
{{- $vaultServer := get (include "runic-system.runic-indexer" (list $root.Values.lexicon (merge (default dict $glyphDefinition.selector) (dict "provider" "operator")) "secret-store" $root.Values.chapter.name ) | fromJson) "results" }}
{{- range $vaultConf := $vaultServer }}
{{- $mountType := required "mountType is required for secretEngineMount" $glyphDefinition.mountType }}
{{- $defaultPath := "" }}
{{- if eq $mountType "database" }}
  {{- $defaultPath = printf "database-%s-%s" $root.Values.spellbook.name $root.Values.chapter.name }}
{{- else if eq $mountType "pki" }}
  {{- $defaultPath = printf "pki-%s-%s" $root.Values.spellbook.name $root.Values.chapter.name }}
{{- else if eq $mountType "kv" }}
  {{- $defaultPath = printf "kv-%s-%s" $root.Values.spellbook.name $root.Values.chapter.name }}
{{- else }}
  {{- $defaultPath = printf "%s-%s-%s" $mountType $root.Values.spellbook.name $root.Values.chapter.name }}
{{- end }}
{{- $mountPath := default $defaultPath $glyphDefinition.path }}
{{- $resourceName := $mountPath }}
{{- $config := deepCopy (default dict $glyphDefinition.config) }}
{{- /* The operator CRD documents `hidden` as the default, but some installed
       versions materialize an omitted value as an invalid empty string before
       schema defaulting. Emit the valid default for database mounts. */ -}}
{{- if and (eq $mountType "database") (not (hasKey $config "listingVisibility")) }}
  {{- $_ := set $config "listingVisibility" "hidden" }}
{{- end }}
{{- if $glyphDefinition.parentPath }}
  {{- $resourceName = required "name is required when secretEngineMount.parentPath is set" $glyphDefinition.name }}
  {{- $mountPath = printf "%s/%s" (trimSuffix "/" $glyphDefinition.parentPath) $resourceName }}
{{- end }}
---
apiVersion: redhatcop.redhat.io/v1alpha1
kind: SecretEngineMount
metadata:
  name: {{ $resourceName }}
  {{- with $glyphDefinition.namespace }}
  namespace: {{ . }}
  {{- end }}
  labels:
    {{- include "common.all.labels" $root | nindent 4 }}
    {{- with $glyphDefinition.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- $annotations := include "common.annotations.map" (list $root (default dict $glyphDefinition.annotations) dict) | fromJson -}}
  {{- with $annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- if $glyphDefinition.forceAdmin }}
  {{- include "vault.connect" (list $root $vaultConf "force") | nindent 2 }}
  {{- else if $glyphDefinition.customRole }}
  {{- include "vault.connect" (list $root $vaultConf "" (default "" $glyphDefinition.serviceAccount) $glyphDefinition.customRole) | nindent 2 }}
  {{- else }}
  {{- include "vault.connect" (list $root $vaultConf "" (default "" $glyphDefinition.serviceAccount)) | nindent 2 }}
  {{- end }}
  type: {{ $mountType }}
  {{- with $glyphDefinition.parentPath }}
  path: {{ trimSuffix "/" . }}
  {{- end }}
  {{- if $glyphDefinition.description }}
  description: {{ $glyphDefinition.description | quote }}
  {{- else }}
  description: "{{ $mountType | title }} secrets engine for {{ $root.Values.spellbook.name }}/{{ $root.Values.chapter.name }}"
  {{- end }}
  {{- if $config }}
  config:
    {{- toYaml $config | nindent 4 }}
  {{- end }}
  {{- if $glyphDefinition.options }}
  options:
    {{- toYaml $glyphDefinition.options | nindent 4 }}
  {{- end }}
{{- end }}
{{- end }}
