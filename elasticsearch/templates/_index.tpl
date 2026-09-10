{{/*
SPDX-License-Identifier: AGPL-3.0-only

elasticsearch.index — consumer glyph analogous to postgresql.db. It creates a
Vault dynamic role scoped to index patterns and exposes credentials in the app
namespace. The connection scheme is inherited from the shared lexicon entry.
*/}}
{{- define "elasticsearch.index" -}}
{{- $root := index . 0 -}}
{{- $g := index . 1 -}}
{{- $appName := default (include "common.name" $root) $g.name -}}
{{- $vaultSelector := deepCopy (default dict $g.vaultSelector) -}}
{{- $es := include "elasticsearch.resolveLexicon" (list $root $g.cluster) | fromJson -}}
{{- $indexName := default $appName $g.indexName -}}
{{- $access := default "read-write" $g.role -}}
{{- if not (has $access (list "read-write" "read-only")) -}}
  {{- fail "elasticsearch.index: role must be read-write or read-only" -}}
{{- end -}}
{{- $short := ternary "rw" "ro" (eq $access "read-write") -}}
{{- $coordinates := include "vault.databaseCoordinates" (list $root (dict "name" (default $appName $g.credentialName) "selector" $vaultSelector) "dynamic") | fromJson -}}
{{- $legacyVaultRoleName := printf "%s-%s-%s" $es.clusterName $appName $short -}}
{{- $vaultRoleName := default (ternary $legacyVaultRoleName $coordinates.name $es.legacyDatabaseMount) $g.vaultRoleName -}}
{{- $databaseMount := ternary $es.databaseMount $coordinates.mount $es.legacyDatabaseMount -}}
{{- $connectionStem := printf "%s-%s" $coordinates.spell $es.clusterName -}}
{{- if ne $coordinates.base "db" -}}{{- $connectionStem = printf "%s-%s" $connectionStem $coordinates.base -}}{{- end -}}
{{- $connectionName := ternary $es.clusterName ($connectionStem | lower | trunc 63 | trimSuffix "-") $es.legacyDatabaseMount -}}
{{- $secretName := default $appName $g.secretName -}}
{{- $sa := default $appName $g.serviceAccount -}}
{{- $authRole := default $sa $g.authRole -}}
{{- if not $es.legacyDatabaseMount -}}{{- $authRole = include "vault.databaseAuthRole" (list $root $sa $g.authRole) -}}{{- end -}}
{{- $patterns := default (list $indexName (printf "%s-*" $indexName)) $g.indexPatterns -}}
{{- $privileges := default (ternary (list "read" "write" "create_index" "view_index_metadata") (list "read" "view_index_metadata") (eq $access "read-write")) $g.privileges -}}
{{- $roleDefinition := dict "elasticsearch_role_definition" (dict "indices" (list (dict "names" $patterns "privileges" $privileges))) -}}

{{- if not $es.legacyDatabaseMount }}
{{ include "vault.databaseEngine" (list $root (dict
    "name" $connectionName
    "pluginName" "elasticsearch-database-plugin"
    "omitConnectionURL" true
    "databaseSpecificConfig" (dict "url" (printf "%s://%s:%s" $es.scheme $es.host $es.port))
    "username" "elastic"
    "passwordKey" $es.credentialsKey
    "credentialsSecret" $es.credentialsSecret
    "allowedRoles" (list $vaultRoleName)
    "databaseMount" $databaseMount
    "configNamespace" $es.engineConfigNamespace
    "serviceAccount" $es.engineServiceAccount
    "customRole" $es.engineAuthRole
    "verifyConnection" true
    "rootRotation" false
    "selector" $vaultSelector
    "annotations" (dict "argocd.argoproj.io/sync-wave" "-2")
)) }}
{{- end }}

{{ include "vault.databaseRole" (list $root (dict
    "name" $vaultRoleName
    "dBName" $connectionName
    "databaseMount" $databaseMount
    "creationStatements" (list ($roleDefinition | toJson))
    "configNamespace" $g.configNamespace
    "defaultTTL" $g.defaultTTL
    "maxTTL" $g.maxTTL
    "selector" $vaultSelector
)) }}

{{ include "vault.secret" (list $root (dict
    "name" $secretName
    "random" false
    "generationType" "database"
    "databaseCredsName" $vaultRoleName
    "databaseMount" $databaseMount
    "serviceAccount" $sa
    "customRole" $authRole
    "format" "env"
    "refreshPeriod" (default "30m0s" $g.refreshPeriod)
    "keys" (list "username" "password")
    "selector" $vaultSelector
    "templateData" (dict
      "HOST" $es.host
      "PORT" $es.port
      "SCHEME" $es.scheme
      "URL" (printf "%s://%s:%s" $es.scheme $es.host $es.port)
      "INDEX" $indexName
    )
)) }}
{{- end -}}
