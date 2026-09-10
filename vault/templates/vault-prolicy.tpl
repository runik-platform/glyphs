{{/*Runik Platform
Copyright (C) 2023 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

vault.prolicy is the opinionated, backward-compatible metaglyph that builds the
standard application policy paths and composes vault.policy with vault.role.

Parameters:
- $root: Chart root context (index . 0)
- $glyph: Shared Policy and KubernetesAuthEngineRole configuration (index . 1)
  - nameOverride: Policy and role name (default: common.name)
  - serviceAccount: ServiceAccount to bind (default: common.name)
  - bookPublicsWrite: Enable writes to book/publics (default: false)
  - chapterPublicsWrite: Enable writes to chapter/publics (default: false)
  - extraPolicy: Additional policy paths (array)
  - tokenPeriod: Optional periodic token duration in seconds
*/}}

{{/* Detect database consumers in both dispatcher shapes. A spell with database
     credentials owns one namespaced database-engine mount; vault.prolicy owns
     that mount and the read policy for its native credential endpoints. Only
     the prolicy selected by the consumer's ServiceAccount/auth-role pair owns
     the mount; a second prolicy in the same spell must not render it again. */}}
{{- define "vault.hasDatabaseCredentials" -}}
{{- $root := index . 0 -}}
{{- $policy := index . 1 -}}
{{- $policyName := default (include "common.name" $root) $policy.nameOverride -}}
{{- $policyServiceAccount := default (include "common.name" $root) $policy.serviceAccount -}}
{{- $glyphs := default dict $root.Values.glyphs -}}
{{- $found := false -}}
{{- range $definitions := list (default dict $root.Values.postgresql) (default dict (get $glyphs "postgresql")) -}}
  {{- range $key, $definition := $definitions -}}
    {{- if eq (default "" $definition.type) "db" -}}
      {{- $pg := include "postgresql.resolveLexicon" (list $root (default $definition.cluster $definition.clusterSelector)) | fromJson -}}
      {{- if not $pg.legacyDatabaseMount -}}
        {{- $credentials := default dict $definition.credentials -}}
        {{- $appName := default (include "common.name" $root) (default $key $definition.name) -}}
        {{- $serviceAccount := default (default $appName $definition.serviceAccount) $credentials.serviceAccount -}}
        {{- $authRole := include "vault.databaseAuthRole" (list $root $serviceAccount $credentials.authRole) -}}
        {{- if and (eq $serviceAccount $policyServiceAccount) (eq $authRole $policyName) -}}
          {{- $policyCoordinates := include "vault.databaseCoordinates" (list $root (dict "selector" $policy.selector) "dynamic") | fromJson -}}
          {{- $consumerSelector := default $definition.selector $definition.vaultSelector -}}
          {{- $consumerCoordinates := include "vault.databaseCoordinates" (list $root (dict "selector" $consumerSelector) "dynamic") | fromJson -}}
          {{- if or (ne $consumerCoordinates.store $policyCoordinates.store) (ne $consumerCoordinates.base $policyCoordinates.base) -}}
            {{- fail (printf "vault.prolicy %q selects secret-store %q (databasePath %q) but PostgreSQL consumer %q selects %q (databasePath %q); select the same secret-store" $policyName $policyCoordinates.store $policyCoordinates.base $appName $consumerCoordinates.store $consumerCoordinates.base) -}}
          {{- end -}}
          {{- $found = true -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- range $definitions := list (default dict $root.Values.cockroachdb) (default dict (get $glyphs "cockroachdb")) -}}
  {{- range $_, $definition := $definitions -}}
    {{- if eq (default "" $definition.type) "database" -}}
      {{- $crdb := include "cockroachdb.resolveLexicon" (list $root $definition.selector) | fromJson -}}
      {{- if not $crdb.legacyDatabaseMount -}}
        {{- $credentials := default dict $definition.credentials -}}
        {{- $appName := include "common.name" $root -}}
        {{- $serviceAccount := default (default $appName $definition.serviceAccount) $credentials.serviceAccount -}}
        {{- $authRole := include "vault.databaseAuthRole" (list $root $serviceAccount $credentials.authRole) -}}
        {{- if and (eq $serviceAccount $policyServiceAccount) (eq $authRole $policyName) -}}
          {{- $policyCoordinates := include "vault.databaseCoordinates" (list $root (dict "selector" $policy.selector) "dynamic") | fromJson -}}
          {{- $consumerCoordinates := include "vault.databaseCoordinates" (list $root (dict "selector" $definition.vaultSelector) "dynamic") | fromJson -}}
          {{- if or (ne $consumerCoordinates.store $policyCoordinates.store) (ne $consumerCoordinates.base $policyCoordinates.base) -}}
            {{- fail (printf "vault.prolicy %q selects secret-store %q (databasePath %q) but CockroachDB consumer selects %q (databasePath %q); select the same secret-store" $policyName $policyCoordinates.store $policyCoordinates.base $consumerCoordinates.store $consumerCoordinates.base) -}}
          {{- end -}}
          {{- $found = true -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- range $definitions := list (default dict $root.Values.elasticsearch) (default dict (get $glyphs "elasticsearch")) -}}
  {{- range $key, $definition := $definitions -}}
    {{- if eq (default "" $definition.type) "index" -}}
      {{- $es := include "elasticsearch.resolveLexicon" (list $root $definition.cluster) | fromJson -}}
      {{- if not $es.legacyDatabaseMount -}}
        {{- $appName := default (include "common.name" $root) (default $key $definition.name) -}}
        {{- $serviceAccount := default $appName $definition.serviceAccount -}}
        {{- $authRole := include "vault.databaseAuthRole" (list $root $serviceAccount $definition.authRole) -}}
        {{- if and (eq $serviceAccount $policyServiceAccount) (eq $authRole $policyName) -}}
          {{- $policyCoordinates := include "vault.databaseCoordinates" (list $root (dict "selector" $policy.selector) "dynamic") | fromJson -}}
          {{- $consumerCoordinates := include "vault.databaseCoordinates" (list $root (dict "selector" $definition.vaultSelector) "dynamic") | fromJson -}}
          {{- if or (ne $consumerCoordinates.store $policyCoordinates.store) (ne $consumerCoordinates.base $policyCoordinates.base) -}}
            {{- fail (printf "vault.prolicy %q selects secret-store %q (databasePath %q) but Elasticsearch consumer %q selects %q (databasePath %q); select the same secret-store" $policyName $policyCoordinates.store $policyCoordinates.base $appName $consumerCoordinates.store $consumerCoordinates.base) -}}
          {{- end -}}
          {{- $found = true -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- range $definitions := list (default dict $root.Values.vault) (default dict (get $glyphs "vault")) -}}
  {{- range $_, $definition := $definitions -}}
    {{- if and (eq (default "" $definition.type) "secret") (has (default "kv" $definition.generationType) (list "database" "database-static")) -}}
      {{- if not $definition.databaseMount -}}
        {{- $serviceAccount := default (include "common.name" $root) $definition.serviceAccount -}}
        {{- $authRole := include "vault.databaseAuthRole" (list $root $serviceAccount $definition.customRole) -}}
        {{- if and (eq $serviceAccount $policyServiceAccount) (eq $authRole $policyName) -}}
          {{- $policyCoordinates := include "vault.databaseCoordinates" (list $root (dict "selector" $policy.selector) "dynamic") | fromJson -}}
          {{- $consumerCoordinates := include "vault.databaseCoordinates" (list $root (dict "selector" $definition.selector) "dynamic") | fromJson -}}
          {{- if or (ne $consumerCoordinates.store $policyCoordinates.store) (ne $consumerCoordinates.base $policyCoordinates.base) -}}
            {{- fail (printf "vault.prolicy %q selects secret-store %q (databasePath %q) but vault.secret consumer selects %q (databasePath %q); select the same secret-store" $policyName $policyCoordinates.store $policyCoordinates.base $consumerCoordinates.store $consumerCoordinates.base) -}}
          {{- end -}}
          {{- $found = true -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- dict "found" $found | toJson -}}
{{- end -}}

{{/* Compatibility for producer-wide engines and books that explicitly publish
     the former shared databaseMount. Producer-offered and static credentials
     use exact paths; legacy dynamic consumers preserve the historical mount
     wildcard. */}}
{{- define "vault.legacyDatabaseCredentialPaths" -}}
{{- $root := index . 0 -}}
{{- $policy := index . 1 -}}
{{- $policyServiceAccount := default (include "common.name" $root) $policy.serviceAccount -}}
{{- $glyphs := default dict $root.Values.glyphs -}}
{{- $paths := dict -}}
{{- range $definitions := list (default dict $root.Values.postgresql) (default dict (get $glyphs "postgresql")) -}}
  {{- range $_, $definition := $definitions -}}
    {{- if eq (default "" $definition.type) "cluster" -}}
      {{- $dbEngine := default dict $definition.dbEngine -}}
      {{- if ne false $dbEngine.enabled -}}
        {{- $engineMount := default "database" $dbEngine.databaseMount -}}
        {{- range $roleName, $roleDefinition := default dict $dbEngine.roles -}}
          {{- if $roleDefinition.expose -}}
            {{- $serviceAccount := default (include "common.name" $root) $roleDefinition.serviceAccount -}}
            {{- $authRole := default $serviceAccount $roleDefinition.authRole -}}
            {{- if and (eq $serviceAccount $policyServiceAccount) (eq $authRole (default (include "common.name" $root) $policy.nameOverride)) -}}
              {{- $_ := set $paths (printf "%s/creds/%s" $engineMount $roleName) true -}}
            {{- end -}}
          {{- end -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- range $_, $entry := default dict $root.Values.lexicon -}}
  {{- if and (has (default "" $entry.type) (list "postgres" "mongodb" "cockroachdb" "elasticsearch")) (hasKey $entry "databaseMount") -}}
    {{- $_ := set $paths (printf "%s/creds/*" $entry.databaseMount) true -}}
  {{- end -}}
{{- end -}}
{{- range $definitions := list (default dict $root.Values.postgresql) (default dict (get $glyphs "postgresql")) -}}
  {{- range $key, $definition := $definitions -}}
    {{- $credentials := default dict $definition.credentials -}}
    {{- if and (eq (default "" $definition.type) "db") (eq (default "dynamic" $credentials.mode) "static") -}}
      {{- $appName := default (include "common.name" $root) (default $key $definition.name) -}}
      {{- $serviceAccount := default (default $appName $definition.serviceAccount) $credentials.serviceAccount -}}
      {{- $pg := include "postgresql.resolveLexicon" (list $root (default $definition.cluster $definition.clusterSelector)) | fromJson -}}
      {{- if and $pg.legacyDatabaseMount (eq $serviceAccount $policyServiceAccount) -}}
        {{- $databaseName := default $appName $definition.databaseName -}}
        {{- $roleName := default (printf "%s-%s-rw" $pg.clusterName $databaseName) (default $definition.vaultRoleName $credentials.vaultRoleName) -}}
        {{- $_ := set $paths (printf "%s/static-creds/%s" $pg.databaseMount $roleName) true -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- range $definitions := list (default dict $root.Values.cockroachdb) (default dict (get $glyphs "cockroachdb")) -}}
  {{- range $_, $definition := $definitions -}}
    {{- $credentials := default dict $definition.credentials -}}
    {{- if and (eq (default "" $definition.type) "database") (eq (default "dynamic" $credentials.mode) "static") -}}
      {{- $appName := include "common.name" $root -}}
      {{- $serviceAccount := default (default $appName $definition.serviceAccount) $credentials.serviceAccount -}}
      {{- $crdb := include "cockroachdb.resolveLexicon" (list $root $definition.selector) | fromJson -}}
      {{- if and $crdb.legacyDatabaseMount (eq $serviceAccount $policyServiceAccount) -}}
        {{- $databaseName := default $appName $definition.databaseName -}}
        {{- $roleName := default (printf "%s-%s" $crdb.clusterName $databaseName) $credentials.vaultRoleName -}}
        {{- $_ := set $paths (printf "%s/static-creds/%s" $crdb.databaseMount $roleName) true -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- dict "paths" (keys $paths | sortAlpha) | toJson -}}
{{- end -}}

{{/* Some physical engines keep their root Secret outside Vault's namespace
     (ECK is the current case). Their infrastructure ServiceAccount may manage
     connection objects inside Runik-owned mounts, but never roles or creds. */}}
{{- define "vault.managesExternalDatabaseConnections" -}}
{{- $root := index . 0 -}}
{{- $policy := index . 1 -}}
{{- $policyName := default (include "common.name" $root) $policy.nameOverride -}}
{{- $policyServiceAccount := default (include "common.name" $root) $policy.serviceAccount -}}
{{- $glyphs := default dict $root.Values.glyphs -}}
{{- $found := false -}}
{{- range $definitions := list (default dict $root.Values.elasticsearch) (default dict (get $glyphs "elasticsearch")) -}}
  {{- range $_, $definition := $definitions -}}
    {{- if eq (default "" $definition.type) "connection" -}}
      {{- $serviceAccount := default (include "common.name" $root) $definition.serviceAccount -}}
      {{- $authRole := default $serviceAccount $definition.customRole -}}
      {{- if and (eq $serviceAccount $policyServiceAccount) (eq $authRole $policyName) -}}
        {{- $policyCoordinates := include "vault.databaseCoordinates" (list $root (dict "selector" $policy.selector) "dynamic") | fromJson -}}
        {{- $connectionCoordinates := include "vault.databaseCoordinates" (list $root (dict "selector" $definition.selector) "dynamic") | fromJson -}}
        {{- if or (ne $connectionCoordinates.store $policyCoordinates.store) (ne $connectionCoordinates.base $policyCoordinates.base) -}}
          {{- fail (printf "vault.prolicy %q selects secret-store %q (databasePath %q) but Elasticsearch connection selects %q (databasePath %q); select the same secret-store" $policyName $policyCoordinates.store $policyCoordinates.base $connectionCoordinates.store $connectionCoordinates.base) -}}
        {{- end -}}
        {{- $found = true -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- dict "found" $found | toJson -}}
{{- end -}}

{{- define "vault.prolicy" -}}
{{- $root := index . 0 -}}
{{- $glyph := index . 1 -}}
{{- $policyName := default (include "common.name" $root) $glyph.nameOverride -}}
{{- $policyNamespace := default (default $root.Release.Namespace $glyph.nameOverride) $glyph.targetNamespace -}}
{{- $bookPublicsCapabilities := list "read" "list" -}}
{{- $chapterPublicsCapabilities := list "read" "list" -}}
{{- if $glyph.bookPublicsWrite -}}
  {{- $bookPublicsCapabilities = list "create" "read" "update" "delete" "list" -}}
{{- end -}}
{{- if $glyph.chapterPublicsWrite -}}
  {{- $chapterPublicsCapabilities = list "create" "read" "update" "delete" "list" -}}
{{- end -}}
{{- $hasDatabaseCredentials := get (include "vault.hasDatabaseCredentials" (list $root $glyph) | fromJson) "found" -}}
{{- $managesExternalDatabaseConnections := get (include "vault.managesExternalDatabaseConnections" (list $root $glyph) | fromJson) "found" -}}
{{- $databaseCoordinates := dict -}}
{{- if or $hasDatabaseCredentials $managesExternalDatabaseConnections -}}
  {{- $databaseCoordinates = include "vault.databaseCoordinates" (list $root (dict "selector" $glyph.selector) "dynamic") | fromJson -}}
{{- end -}}
{{- $legacyDatabaseCredentialPaths := get (include "vault.legacyDatabaseCredentialPaths" (list $root $glyph) | fromJson) "paths" -}}
{{- $vaultServers := get (include "runic-system.runic-indexer" (list $root.Values.lexicon (merge (default dict $glyph.selector) (dict "provider" "operator")) "secret-store" $root.Values.chapter.name) | fromJson) "results" -}}
{{- range $vaultConf := $vaultServers -}}
  {{- $paths := list -}}
  {{- $paths = append $paths (dict "path" (printf "%s/data/%s/%s/%s/*" $vaultConf.secretPath $root.Values.spellbook.name $root.Values.chapter.name $policyNamespace) "capabilities" (list "create" "read" "update" "delete" "list")) -}}
  {{- $paths = append $paths (dict "path" (printf "%s/metadata/%s/%s/%s/*" $vaultConf.secretPath $root.Values.spellbook.name $root.Values.chapter.name $policyNamespace) "capabilities" (list "create" "read" "update" "delete" "list")) -}}
  {{- $paths = append $paths (dict "path" (printf "%s/data/%s/%s/publics/*" $vaultConf.secretPath $root.Values.spellbook.name $root.Values.chapter.name) "capabilities" $chapterPublicsCapabilities) -}}
  {{- $paths = append $paths (dict "path" (printf "%s/metadata/%s/%s/publics/*" $vaultConf.secretPath $root.Values.spellbook.name $root.Values.chapter.name) "capabilities" $chapterPublicsCapabilities) -}}
  {{- $paths = append $paths (dict "path" (printf "%s/data/%s/publics/*" $vaultConf.secretPath $root.Values.spellbook.name) "capabilities" $bookPublicsCapabilities) -}}
  {{- $paths = append $paths (dict "path" (printf "%s/metadata/%s/publics/*" $vaultConf.secretPath $root.Values.spellbook.name) "capabilities" $bookPublicsCapabilities) -}}
  {{- $paths = append $paths (dict "path" (printf "%s/data/%s/pipelines/*" $vaultConf.secretPath $root.Values.spellbook.name) "capabilities" (list "read" "list")) -}}
  {{- $paths = append $paths (dict "path" (printf "%s/metadata/%s/pipelines/*" $vaultConf.secretPath $root.Values.spellbook.name) "capabilities" (list "read" "list")) -}}
  {{- $paths = append $paths (dict "path" "sys/policies/password/*" "capabilities" (list "read" "list")) -}}

  {{- if $hasDatabaseCredentials -}}
    {{- $paths = append $paths (dict "path" (printf "%s/creds/*" $databaseCoordinates.mount) "capabilities" (list "read")) -}}
    {{- $paths = append $paths (dict "path" (printf "%s/static-creds/*" $databaseCoordinates.mount) "capabilities" (list "read")) -}}
    {{- /* SecretEngineMount reads the root catalog before operating on its
         exact mount path. Keep mutation scoped to this spell's mount. */ -}}
    {{- $paths = append $paths (dict "path" "sys/mounts" "capabilities" (list "read")) -}}
    {{- $paths = append $paths (dict "path" (printf "sys/mounts/%s" $databaseCoordinates.mount) "capabilities" (list "create" "read" "update" "delete")) -}}
  {{- end -}}
  {{- range $path := $legacyDatabaseCredentialPaths -}}
    {{- $paths = append $paths (dict "path" $path "capabilities" (list "read")) -}}
  {{- end -}}
  {{- if $managesExternalDatabaseConnections -}}
    {{- $paths = append $paths (dict "path" (printf "%s/+/+/+/config/*" $databaseCoordinates.base) "capabilities" (list "create" "read" "update" "delete")) -}}
  {{- end -}}
  {{- range (default list ($root.Values.spellbook.prolicy).extraPolicy) -}}
    {{- $paths = append $paths . -}}
  {{- end -}}
  {{- range (default list ($root.Values.chapter.prolicy).extraPolicy) -}}
    {{- $paths = append $paths . -}}
  {{- end -}}
  {{- range (default list $vaultConf.extraPolicy) -}}
    {{- $paths = append $paths . -}}
  {{- end -}}
  {{- range (default list $glyph.extraPolicy) -}}
    {{- $paths = append $paths . -}}
  {{- end -}}

  {{- $policyGlyph := deepCopy $glyph -}}
  {{- $_ := set $policyGlyph "paths" $paths -}}
  {{- $roleGlyph := deepCopy $glyph -}}
  {{- $_ := set $roleGlyph "policies" (list $policyName) -}}
  {{- if $hasDatabaseCredentials -}}
    {{- $policyAnnotations := deepCopy (default dict $glyph.annotations) -}}
    {{- if not (hasKey $policyAnnotations "argocd.argoproj.io/sync-wave") -}}{{- $_ := set $policyAnnotations "argocd.argoproj.io/sync-wave" "-5" -}}{{- end -}}
    {{- $_ := set $policyGlyph "annotations" $policyAnnotations -}}
    {{- $roleAnnotations := deepCopy (default dict $glyph.annotations) -}}
    {{- if not (hasKey $roleAnnotations "argocd.argoproj.io/sync-wave") -}}{{- $_ := set $roleAnnotations "argocd.argoproj.io/sync-wave" "-4" -}}{{- end -}}
    {{- $_ := set $roleGlyph "annotations" $roleAnnotations -}}
  {{- end -}}
{{ include "vault.policy.resource" (list $root $policyGlyph $vaultConf) }}
{{ include "vault.role.resource" (list $root $roleGlyph $vaultConf) }}
{{- if $hasDatabaseCredentials }}
{{ include "vault.secretEngineMount" (list $root (dict
    "name" $databaseCoordinates.spell
    "namespace" $policyNamespace
    "mountType" "database"
    "parentPath" $databaseCoordinates.mountParent
    "serviceAccount" (default (include "common.name" $root) $glyph.serviceAccount)
    "customRole" $policyName
    "selector" $glyph.selector
    "description" (printf "Runik database credentials for %s/%s/%s" $databaseCoordinates.book $databaseCoordinates.chapter $databaseCoordinates.spell)
    "annotations" (dict "argocd.argoproj.io/sync-wave" "-3")
)) }}
{{- end }}
{{- end -}}
{{- end -}}
