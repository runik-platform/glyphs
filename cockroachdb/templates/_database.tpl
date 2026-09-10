{{/*Runik Platform
Copyright (C) 2026 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

cockroachdb.database creates one persistent application database and exposes
either dynamic credentials (the backward-compatible default) or one stable SQL
identity whose password is rotated by Vault.
*/}}
{{- define "cockroachdb.database" -}}
{{- $root := index . 0 -}}
{{- $g := index . 1 -}}
{{- $crdb := include "cockroachdb.resolveLexicon" (list $root $g.selector) | fromJson -}}
{{- $databaseName := include "cockroachdb.identifier" (list "databaseName" (default (include "common.name" $root) $g.databaseName)) -}}
{{- $credentials := deepCopy (default dict $g.credentials) -}}
{{- $vaultSelector := deepCopy (default dict $g.vaultSelector) -}}
{{- $credentialMode := default "dynamic" $credentials.mode -}}
{{- if not (has $credentialMode (list "dynamic" "static")) -}}
  {{- fail (printf "cockroachdb.database: credentials.mode must be dynamic or static, got %q" $credentialMode) -}}
{{- end -}}
{{- $coordinates := include "vault.databaseCoordinates" (list $root (dict "name" (default (include "common.name" $root) $credentials.name) "selector" $vaultSelector) $credentialMode) | fromJson -}}
{{- $legacyVaultRoleName := printf "%s-%s" $crdb.clusterName $databaseName -}}
{{- $vaultRoleName := default (ternary $legacyVaultRoleName $coordinates.name $crdb.legacyDatabaseMount) $credentials.vaultRoleName -}}
{{- $databaseMount := ternary $crdb.databaseMount $coordinates.mount $crdb.legacyDatabaseMount -}}
{{- $connectionStem := printf "%s-%s" $coordinates.spell $crdb.clusterName -}}
{{- if ne $coordinates.base "db" -}}{{- $connectionStem = printf "%s-%s" $connectionStem $coordinates.base -}}{{- end -}}
{{- $connectionName := ternary $crdb.clusterName ($connectionStem | lower | trunc 63 | trimSuffix "-") $crdb.legacyDatabaseMount -}}
{{- $serviceAccount := default (default (include "common.name" $root) $g.serviceAccount) $credentials.serviceAccount -}}
{{- $authRole := default $serviceAccount $credentials.authRole -}}
{{- if not $crdb.legacyDatabaseMount -}}{{- $authRole = include "vault.databaseAuthRole" (list $root $serviceAccount $credentials.authRole) -}}{{- end -}}
{{- $_ := set $crdb "databaseMount" $databaseMount -}}

{{- if not $crdb.legacyDatabaseMount }}
{{ include "vault.databaseEngine" (list $root (dict
    "name" $connectionName
    "pluginName" "postgresql-database-plugin"
    "connectionPrefix" "postgresql://"
    "connectionSuffix" (printf "@%s:%s/%s?sslmode=%s" $crdb.host $crdb.port (default "defaultdb" $crdb.database) $crdb.sslmode)
    "credentialsSecret" $crdb.engineCredentialsSecret
    "allowedRoles" (list $vaultRoleName)
    "databaseMount" $databaseMount
    "configNamespace" $crdb.engineConfigNamespace
    "rootRotation" false
    "selector" $vaultSelector
    "annotations" (dict "argocd.argoproj.io/sync-wave" "-2")
)) }}
{{- end }}

{{- if eq $credentialMode "dynamic" -}}
{{- $n := "{{name}}" -}}
{{- $pw := "{{password}}" -}}
{{- $exp := "{{expiration}}" -}}
{{- $creation := $g.creationStatements -}}
{{- if not $creation -}}
  {{- if $crdb.tlsEnabled -}}
    {{- $creation = list
        (printf "CREATE DATABASE IF NOT EXISTS \"%s\";" $databaseName)
        (printf "CREATE ROLE \"%s\" WITH LOGIN PASSWORD '%s' VALID UNTIL '%s';" $n $pw $exp)
        (printf "GRANT ALL ON DATABASE \"%s\" TO \"%s\";" $databaseName $n)
    -}}
  {{- else -}}
    {{- $creation = list
        (printf "CREATE DATABASE IF NOT EXISTS \"%s\";" $databaseName)
        (printf "CREATE ROLE \"%s\" WITH LOGIN VALID UNTIL '%s';" $n $exp)
        (printf "GRANT ALL ON DATABASE \"%s\" TO \"%s\";" $databaseName $n)
    -}}
  {{- end -}}
{{- end -}}
{{- $revocation := default (list
      (printf "REVOKE ALL ON DATABASE \"%s\" FROM \"%s\";" $databaseName $n)
      (printf "DROP ROLE IF EXISTS \"%s\";" $n)
  ) $g.revocationStatements -}}
{{- $renew := default (list (printf "ALTER ROLE \"%s\" VALID UNTIL '%s';" $n $exp)) $g.renewStatements -}}
{{ include "vault.databaseRole" (list $root (dict
    "name" $vaultRoleName
    "dBName" $connectionName
    "databaseMount" $crdb.databaseMount
    "creationStatements" $creation
    "revocationStatements" $revocation
    "renewStatements" $renew
    "rollbackStatements" $g.rollbackStatements
    "configNamespace" $g.configNamespace
    "defaultTTL" (default "1h" $g.defaultTTL)
    "maxTTL" (default "24h" $g.maxTTL)
    "selector" $vaultSelector
)) }}
{{- else -}}
{{- $username := include "cockroachdb.identifier" (list "credentials.username" (default $databaseName $credentials.username)) -}}
{{- $n := "{{name}}" -}}
{{- $pw := "{{password}}" -}}
{{- $rotation := $credentials.rotationStatements -}}
{{- if not $rotation -}}
  {{- if $crdb.tlsEnabled -}}
    {{- $rotation = list
        (printf "CREATE DATABASE IF NOT EXISTS \"%s\";" $databaseName)
        (printf "CREATE ROLE IF NOT EXISTS \"%s\" WITH LOGIN;" $n)
        (printf "ALTER ROLE \"%s\" WITH LOGIN PASSWORD '%s';" $n $pw)
        (printf "GRANT ALL ON DATABASE \"%s\" TO \"%s\";" $databaseName $n)
    -}}
  {{- else -}}
    {{- $rotation = list
        (printf "CREATE DATABASE IF NOT EXISTS \"%s\";" $databaseName)
        (printf "CREATE ROLE IF NOT EXISTS \"%s\" WITH LOGIN;" $n)
        (printf "GRANT ALL ON DATABASE \"%s\" TO \"%s\";" $databaseName $n)
    -}}
  {{- end -}}
{{- end -}}
{{ include "vault.databaseStaticRole" (list $root (dict
    "name" $vaultRoleName
    "dBName" $connectionName
    "databaseMount" $crdb.databaseMount
    "username" $username
    "rotationPeriod" $credentials.rotationPeriod
    "rotationStatements" $rotation
    "passwordPolicy" $credentials.passwordPolicy
    "configNamespace" (default $g.configNamespace $credentials.configNamespace)
    "selector" $vaultSelector
)) }}
{{- end }}
{{ include "cockroachdb.credentials" (list $root $g $crdb $vaultRoleName $databaseName $credentialMode $authRole $vaultSelector) }}
{{- end -}}
