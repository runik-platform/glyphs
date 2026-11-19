{{/*Runik Platform
Copyright (C) 2025 laaledesiempre@disroot.org
SPDX-License-Identifier: AGPL-3.0-only

common.secretPath generates basic hierarchical secret paths.

This is a PROVIDER-AGNOSTIC helper. Provider-specific logic (like Vault's /data prefix,
AWS region handling, etc.) should be in the respective provider glyph.

Parameters:
- $root: Chart root context (index . 0)
- $glyph: Glyph definition object (index . 1)
- $basePath: Base path string from provider config (index . 2)
- $options: Optional dict (index . 3)

Options dict:
- excludeName: bool - If true, don't append name to path (for create operations)
- store: selected secret-store entry; its optional pathRoot replaces spellbook.name

Path Resolution:
- path: "book" → {basePath}/{spellbook}/{visibility}/{name}
- path: "chapter" → {basePath}/{spellbook}/{chapter}/{visibility}/{name}
- path: "/absolute/path/" → {basePath}/absolute/path/{name}
- path: "/absolute/path" → {basePath}/absolute/path
- default → {basePath}/{spellbook}/{chapter}/{namespace}/{visibility}/{name}

Visibility:
- Default: "publics"
- Override via glyph.private: "privates"

Examples:
  {{- include "common.secretPath" (list $root (dict "name" "api-key" "path" "book") "kv" dict) }}
  → kv/my-book/publics/api-key

  {{- include "common.secretPath" (list $root (dict "name" "db-creds" "path" "chapter") "kv" dict) }}
  → kv/my-book/prod/publics/db-creds

  {{- include "common.secretPath" (list $root (dict "name" "cert" "path" "/ssl/certs") "kv" dict) }}
  → kv/ssl/certs/cert

  {{- include "common.secretPath" (list $root (dict "name" "api-secret") "kv" dict) }}
  → kv/my-book/prod/default/publics/api-secret
*/}}

{{/* Only an explicit pathRoot is validated here. Omitted configuration retains
legacy book names and paths verbatim. Roots may contain multiple segments. */}}
{{- define "common.secretRoot" -}}
  {{- $root := index . 0 -}}
  {{- $store := default dict (index . 1) -}}
  {{- if hasKey $store "pathRoot" -}}
    {{- $value := $store.pathRoot -}}
    {{- if not (kindIs "string" $value) -}}
      {{- fail "secret-store.pathRoot must be a non-empty string of path segments" -}}
    {{- end -}}
    {{- if not (regexMatch "^[A-Za-z0-9][A-Za-z0-9._-]*(/[A-Za-z0-9][A-Za-z0-9._-]*)*$" $value) -}}
      {{- fail (printf "secret-store.pathRoot %q is invalid: use non-empty segments without leading/trailing slashes, wildcards or traversal" $value) -}}
    {{- end -}}
    {{- $value -}}
  {{- else -}}
    {{- $root.Values.spellbook.name -}}
  {{- end -}}
{{- end -}}

{{/* Logical scopes shared by secret readers, writers, database mounts and
policy builders. Provider prefixes and operation endpoints belong to adapters. */}}
{{- define "common.secretScope" -}}
  {{- $root := index . 0 -}}
  {{- $store := default dict (index . 1) -}}
  {{- $options := dict -}}
  {{- if gt (len .) 2 }}{{- $options = index . 2 -}}{{- end -}}
  {{- $pathRoot := include "common.secretRoot" (list $root $store) -}}
  {{- $chapter := $root.Values.chapter.name -}}
  {{- $namespace := default $root.Release.Namespace $options.namespace -}}
  {{- $chapterPath := printf "/%s/%s" $pathRoot $chapter -}}
  {{- dict "root" $pathRoot "chapter" $chapter "namespace" $namespace
        "bookPath" (printf "/%s" $pathRoot)
        "chapterPath" $chapterPath
        "namespacePath" (printf "%s/%s" $chapterPath $namespace)
      | toJson -}}
{{- end -}}

{{- define "common.secretCoordinates" }}
  {{- $root := index . 0 }}
  {{- $glyph := index . 1 }}
  {{- $store := default dict (index . 2) }}
  {{- $options := dict }}
  {{- if gt (len .) 3 }}
    {{- $options = index . 3 }}
  {{- end }}

  {{- $visibility := default "publics" $glyph.private }}
  {{- $path := default "" $glyph.path }}
  {{- $name := $glyph.name }}
  {{- $scope := include "common.secretScope" (list $root $store $options) | fromJson }}
  {{- $logicalPath := "" }}

  {{- if $options.excludeName }}
    {{- $name = "" }}
  {{- end }}

  {{- /* Simple hierarchical path generation */ -}}
  {{- if eq $path "book" }}
    {{- $logicalPath = printf "%s/%s/%s" $scope.bookPath $visibility $name }}
  {{- else if eq $path "chapter" }}
    {{- $logicalPath = printf "%s/%s/%s" $scope.chapterPath $visibility $name }}
  {{- else if hasPrefix "/" $path }}
    {{- /* Absolute path */ -}}
    {{- if hasSuffix "/" $path }}
      {{- $logicalPath = printf "%s%s" $path $name }}
    {{- else }}
      {{- $logicalPath = $path }}
    {{- end }}
  {{- else }}
    {{- /* Default: book/chapter/namespace/visibility/name */ -}}
    {{- $logicalPath = printf "%s/%s/%s" $scope.namespacePath $visibility $name }}
  {{- end }}
  {{- merge (dict "path" $logicalPath "name" $name "visibility" $visibility) $scope | toJson }}
{{- end }}

{{/* Compatibility entry point: provider prefixes remain separate from the
logical hierarchy; the existing positional signature is preserved. */}}
{{- define "common.secretPath" -}}
  {{- $root := index . 0 -}}
  {{- $glyph := index . 1 -}}
  {{- $basePath := index . 2 -}}
  {{- $options := dict -}}
  {{- if gt (len .) 3 }}{{- $options = index . 3 -}}{{- end -}}
  {{- $coordinates := include "common.secretCoordinates" (list $root $glyph (default dict $options.store) $options) | fromJson -}}
  {{- printf "%s%s" $basePath $coordinates.path -}}
{{- end }}
