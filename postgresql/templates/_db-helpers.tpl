{{/*Runik Platform
Copyright (C) 2025 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

postgresql.identifier validates identifiers interpolated by the built-in SQL
statements. Custom SQL remains available for callers that need a different
identifier policy.

postgresql.resolveLexicon — resolves a `type: postgres` lexicon entry into the
full set of coordinates a consumer needs, applying the inference rules from
docs/design/postgresql-db-glyph.md §3.1. The producer (the cluster spell) only
declares what differs from the convention; everything else is derived here.

Parameters (list):
  0: $root      — chart root context
  1: $selector  — optional dict; lexicon label selector (empty → book default)

Returns (JSON dict):
  clusterName, namespace, host, port, credentialsSecret, databaseMount,
  legacyDatabaseMount, engineCredentialsSecret, engineConfigNamespace,
  database, vaultSecretPath, managerSuperuser

Inference (override any field by setting it on the lexicon entry):
  clusterName       = entry.name (the lexicon key, injected by runicIndexer)
  namespace         = "databases"
  host              = "<clusterName>-rw.<namespace>.svc"
  port              = "5432"
  credentialsSecret = "<clusterName>-superuser"
  databaseMount     = Runik scope
                      `<secret-store.databasePath>/<book>/<chapter>/<spell>`
                      unless the lexicon explicitly publishes a legacy mount
  database          = "*"
*/}}
{{- define "postgresql.identifier" -}}
{{- $field := index . 0 -}}
{{- $value := required (printf "postgresql.db: %s is required" $field) (index . 1) -}}
{{- if not (regexMatch "^[A-Za-z_][A-Za-z0-9_-]{0,62}$" $value) -}}
  {{- fail (printf "postgresql.db: %s %q is not a safe SQL identifier (expected ^[A-Za-z_][A-Za-z0-9_-]{0,62}$)" $field $value) -}}
{{- end -}}
{{- $value -}}
{{- end -}}

{{/* Build a deterministic DNS name for namespaced CNPG resources. SQL
     identifiers are limited to 63 bytes, so two validated identifiers plus a
     separator remain below the Kubernetes DNS subdomain limit. */}}
{{- define "postgresql.resourceName" -}}
{{- $cluster := index . 0 -}}
{{- $identifier := index . 1 -}}
{{- printf "%s-%s" $cluster $identifier | lower | replace "_" "-" -}}
{{- end -}}

{{- define "postgresql.resolveLexicon" -}}
{{- $root := index . 0 -}}
{{- $selector := default dict (index . 1) -}}
{{- $entries := get (include "runic-system.runic-indexer" (list $root.Values.lexicon $selector "postgres" $root.Values.chapter.name) | fromJson) "results" -}}
{{- if not $entries -}}
  {{- fail (printf "postgresql: no 'type: postgres' entry found in lexicon for selector %v. Publish one in the cluster spell's appendix.lexicon (see docs/design/postgresql-db-glyph.md §3.2)." $selector) -}}
{{- end -}}
{{- $e := index $entries 0 -}}
{{- $cluster := default $e.name $e.clusterName -}}
{{- $ns := default "databases" $e.namespace -}}
{{- $host := default (printf "%s-rw.%s.svc" $cluster $ns) $e.host -}}
{{- $port := default "5432" $e.port -}}
{{- $cred := default (printf "%s-superuser" $cluster) $e.credentialsSecret -}}
{{- $mount := default "database" $e.databaseMount -}}
{{- $database := default "*" $e.database -}}
{{- dict
      "clusterName" $cluster
      "namespace" $ns
      "host" $host
      "port" (toString $port)
      "credentialsSecret" $cred
      "databaseMount" $mount
      "legacyDatabaseMount" (hasKey $e "databaseMount")
      "engineCredentialsSecret" (default (printf "%s-vault-mgr-root" $cluster) $e.engineCredentialsSecret)
      "engineConfigNamespace" (default "vault" $e.engineConfigNamespace)
      "engineDatabase" (default "postgres" $e.engineDatabase)
      "database" $database
      "vaultSecretPath" (default "" $e.vaultSecretPath)
      "managerSuperuser" (eq true $e.managerSuperuser)
  | toJson -}}
{{- end -}}
