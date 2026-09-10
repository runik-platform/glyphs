{{/*Runik Platform
Copyright (C) 2026 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

Runik database credentials live below one Vault database-engine mount per
spell. Vault owns the final operation-specific segments (`creds` and
`static-creds`); Runik owns the stable book/chapter/spell hierarchy.

Logical scope (`databasePath` comes from the selected `secret-store` and
defaults to `db`):
  <databasePath>/<book>/<chapter>/<spell>

Physical credential paths:
  <databasePath>/<book>/<chapter>/<spell>/creds/<name>
  <databasePath>/<book>/<chapter>/<spell>/static-creds/<name>
*/}}

{{- define "vault.databasePathSegment" -}}
{{- $field := index . 0 -}}
{{- $value := required (printf "vault database path: %s is required" $field) (index . 1) | toString -}}
{{- if not (regexMatch "^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$" $value) -}}
  {{- fail (printf "vault database path: %s %q is invalid (expected ^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$)" $field $value) -}}
{{- end -}}
{{- $value -}}
{{- end -}}

{{- define "vault.databaseCoordinates" -}}
{{- $root := index . 0 -}}
{{- $definition := default dict (index . 1) -}}
{{- $mode := default "dynamic" (index . 2) -}}
{{- if not (has $mode (list "dynamic" "static")) -}}
  {{- fail (printf "vault database path: mode must be dynamic or static, got %q" $mode) -}}
{{- end -}}
{{- $selector := merge (deepCopy (default dict $definition.selector)) (dict "provider" "operator") -}}
{{- $vaultServers := get (include "runic-system.runic-indexer" (list $root.Values.lexicon $selector "secret-store" $root.Values.chapter.name) | fromJson) "results" -}}
{{- if eq (len $vaultServers) 0 -}}
  {{- fail "vault database path: no selected 'type: secret-store' (provider: operator) entry found in lexicon" -}}
{{- end -}}
{{- if gt (len $vaultServers) 1 -}}
  {{- fail (printf "vault database path: selector %s matches %d secret-store entries; make vaultSelector/selector unambiguous" ($selector | toJson) (len $vaultServers)) -}}
{{- end -}}
{{- $vaultConf := index $vaultServers 0 -}}
{{- $book := include "vault.databasePathSegment" (list "spellbook.name" $root.Values.spellbook.name) -}}
{{- $chapter := include "vault.databasePathSegment" (list "chapter.name" $root.Values.chapter.name) -}}
{{- $spell := include "vault.databasePathSegment" (list "spell" (default (include "common.name" $root) $definition.spellName)) -}}
{{- $name := include "vault.databasePathSegment" (list "credential name" (default (include "common.name" $root) $definition.name)) -}}
{{- $base := include "vault.databasePathSegment" (list "secret-store.databasePath" (default "db" $vaultConf.databasePath)) -}}
{{- $mountParent := printf "%s/%s/%s" $base $book $chapter -}}
{{- $mount := printf "%s/%s" $mountParent $spell -}}
{{- $endpoint := ternary "static-creds" "creds" (eq $mode "static") -}}
{{- dict
      "base" $base
      "store" $vaultConf.name
      "book" $book
      "chapter" $chapter
      "spell" $spell
      "name" $name
      "mode" $mode
      "mountParent" $mountParent
      "mount" $mount
      "endpoint" $endpoint
      "path" (printf "%s/%s/%s" $mount $endpoint $name)
  | toJson -}}
{{- end -}}

{{/* Resolve the local prolicy's Vault auth role. Database VaultSecrets use the
     role rendered by the spell, not a role inferred from a shared ServiceAccount. */}}
{{- define "vault.databaseAuthRole" -}}
{{- $root := index . 0 -}}
{{- $serviceAccount := default (include "common.name" $root) (index . 1) -}}
{{- $explicit := default "" (index . 2) -}}
{{- $role := "" -}}
{{- $matches := 0 -}}
{{- $glyphs := default dict $root.Values.glyphs -}}
{{- range $definitions := list (default dict $root.Values.vault) (default dict (get $glyphs "vault")) -}}
  {{- range $_, $definition := $definitions -}}
    {{- if and (eq (default "" $definition.type) "prolicy") (eq (default (include "common.name" $root) $definition.serviceAccount) $serviceAccount) -}}
      {{- $candidate := default (include "common.name" $root) $definition.nameOverride -}}
      {{- if or (not $explicit) (eq $candidate $explicit) -}}
        {{- $matches = add1 $matches -}}
        {{- $role = $candidate -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- if eq $matches 0 -}}
  {{- if $explicit -}}
    {{- fail (printf "database credentials authRole %q for ServiceAccount %q must match one local vault.prolicy declaration" $explicit $serviceAccount) -}}
  {{- else -}}
    {{- fail (printf "database credentials for ServiceAccount %q require one local vault.prolicy declaration (or credentials.authRole)" $serviceAccount) -}}
  {{- end -}}
{{- end -}}
{{- if gt $matches 1 -}}
  {{- if $explicit -}}
    {{- fail (printf "database credentials authRole %q for ServiceAccount %q matches multiple local vault.prolicy declarations" $explicit $serviceAccount) -}}
  {{- else -}}
    {{- fail (printf "database credentials for ServiceAccount %q match multiple local vault.prolicy declarations; set credentials.authRole explicitly" $serviceAccount) -}}
  {{- end -}}
{{- end -}}
{{- $role -}}
{{- end -}}
