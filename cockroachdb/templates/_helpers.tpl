{{/*Runik Platform
Copyright (C) 2026 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only
*/}}

{{/* Restrict SQL identifiers interpolated by the built-in statements. Callers
     that need other identifiers must supply custom statements explicitly. */}}
{{- define "cockroachdb.identifier" -}}
{{- $field := index . 0 -}}
{{- $value := required (printf "cockroachdb: %s is required" $field) (index . 1) -}}
{{- if not (regexMatch "^[A-Za-z_][A-Za-z0-9_-]{0,62}$" $value) -}}
  {{- fail (printf "cockroachdb: %s %q is not a safe SQL identifier (expected ^[A-Za-z_][A-Za-z0-9_-]{0,62}$)" $field $value) -}}
{{- end -}}
{{- $value -}}
{{- end -}}

{{/* Resolve the shared physical cluster published as `type: cockroachdb` in
     the lexicon. The official CockroachDB Helm chart owns the CrdbCluster; this
     glyphset only consumes its SQL endpoint. */}}
{{- define "cockroachdb.resolveLexicon" -}}
{{- $root := index . 0 -}}
{{- $selector := default dict (index . 1) -}}
{{- $entries := get (include "runic-system.runic-indexer" (list $root.Values.lexicon $selector "cockroachdb" $root.Values.chapter.name) | fromJson) "results" -}}
{{- if not $entries -}}
  {{- fail (printf "cockroachdb: no 'type: cockroachdb' entry found in lexicon for selector %v" $selector) -}}
{{- end -}}
{{- $e := index $entries 0 -}}
{{- $cluster := default $e.name $e.clusterName -}}
{{- $namespace := default "cockroachdb" $e.namespace -}}
{{- $host := required (printf "cockroachdb: lexicon entry %q must publish host" $e.name) $e.host -}}
{{- if and (hasKey $e "tls") (not (kindIs "map" $e.tls)) -}}
  {{- fail (printf "cockroachdb: lexicon entry %q tls must be a map with an enabled boolean" $e.name) -}}
{{- end -}}
{{- $tls := default dict $e.tls -}}
{{- $hasTlsEnabled := hasKey $tls "enabled" -}}
{{- $tlsEnabled := true -}}
{{- if $hasTlsEnabled -}}
  {{- $tlsEnabled = $tls.enabled -}}
  {{- if not (kindIs "bool" $tlsEnabled) -}}
    {{- fail (printf "cockroachdb: lexicon entry %q tls.enabled must be a boolean" $e.name) -}}
  {{- end -}}
{{- end -}}
{{- $sslmode := ternary "require" "disable" $tlsEnabled -}}
{{- if hasKey $e "sslmode" -}}
  {{- $sslmode = toString $e.sslmode -}}
{{- end -}}
{{- if not (has $sslmode (list "disable" "require" "verify-ca" "verify-full")) -}}
  {{- fail (printf "cockroachdb: lexicon entry %q sslmode must be one of disable, require, verify-ca, or verify-full; got %q" $e.name $sslmode) -}}
{{- end -}}
{{- if and $hasTlsEnabled (not $tlsEnabled) (ne $sslmode "disable") -}}
  {{- fail (printf "cockroachdb: lexicon entry %q has tls.enabled=false but sslmode=%q; an insecure cluster requires sslmode=disable" $e.name $sslmode) -}}
{{- end -}}
{{- if and $hasTlsEnabled $tlsEnabled (eq $sslmode "disable") -}}
  {{- fail (printf "cockroachdb: lexicon entry %q has tls.enabled=true but sslmode=disable" $e.name) -}}
{{- end -}}
{{- dict
      "clusterName" $cluster
      "namespace" $namespace
      "host" $host
      "port" (toString (default 26257 $e.port))
      "databaseMount" (default "database" $e.databaseMount)
      "legacyDatabaseMount" (hasKey $e "databaseMount")
      "engineCredentialsSecret" (default (printf "%s-vault-manager-root" $cluster) $e.engineCredentialsSecret)
      "engineConfigNamespace" (default "vault" $e.engineConfigNamespace)
      "tlsEnabled" $tlsEnabled
      "sslmode" $sslmode
      "database" (default "" $e.database)
  | toJson -}}
{{- end -}}

{{/* Common Kubernetes Secret output for dynamic and static database roles. */}}
{{- define "cockroachdb.credentials" -}}
{{- $root := index . 0 -}}
{{- $g := index . 1 -}}
{{- $crdb := index . 2 -}}
{{- $vaultRoleName := index . 3 -}}
{{- $databaseName := index . 4 -}}
{{- $credentialMode := index . 5 -}}
{{- $authRole := index . 6 -}}
{{- $vaultSelector := index . 7 -}}
{{- $credentials := deepCopy (default dict $g.credentials) -}}
{{- $annotations := deepCopy (default dict $g.annotations) -}}
{{- $_ := set $annotations "runik.ing/cockroachdb-cluster" $crdb.clusterName -}}
{{ include "vault.secret" (list $root (dict
    "name" (default (default (include "common.name" $root) $g.secretName) $credentials.secretName)
    "random" false
    "generationType" (ternary "database-static" "database" (eq $credentialMode "static"))
    "databaseCredsName" $vaultRoleName
    "databaseMount" $crdb.databaseMount
    "serviceAccount" (default (default (include "common.name" $root) $g.serviceAccount) $credentials.serviceAccount)
    "customRole" $authRole
    "format" "env"
    "refreshThreshold" (default (default 80 $g.refreshThreshold) $credentials.refreshThreshold)
    "refreshPeriod" (default $g.refreshPeriod $credentials.refreshPeriod)
    "keys" (list "username" "password")
    "selector" $vaultSelector
    "annotations" $annotations
    "staticData" (dict
      "HOST" $crdb.host
      "PORT" ($crdb.port | quote)
      "DATABASE" $databaseName
      "DBNAME" $databaseName
      "SSLMODE" $crdb.sslmode)
)) }}
{{- end -}}
