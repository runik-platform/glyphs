{{/*Runik Platform
Copyright (C) 2025 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

postgresql.db — CONSUMER glyph. Gives an app a database on a shared CNPG
cluster plus either dynamic credentials (backward-compatible default) or a
stable username whose password is rotated by Vault.

Minimal spell:
  postgresql:
    miapp:
      type: db            # everything else derived from common.name + lexicon

Emits, in Argo CD sync order:
  1. DatabaseRole (CNPG) — stable owner/login in the cluster namespace
  2. Database (CNPG) — explicit retain policy in the cluster namespace
  3. DatabaseSecretEngineRole or DatabaseSecretEngineStaticRole (Vault)
  4. VaultSecret — materializes the application Secret

The app's local vault.prolicy owns
`<secret-store.databasePath>/<book>/<chapter>/<spell>`, grants only that spell's
native `creds/*` and `static-creds/*` endpoints, and binds its own Vault auth
role even when several spells share one Kubernetes ServiceAccount.

credentials.mode defaults to dynamic. Static mode requires rotationPeriod and
defaults to a basic-auth Secret with lowercase username/password keys.
*/}}
{{- define "postgresql.db" -}}
{{- $root := index . 0 -}}
{{- $g := index . 1 -}}
{{- $appName := default (include "common.name" $root) $g.name -}}
{{- $credentials := deepCopy (default dict $g.credentials) -}}
{{- $mode := default "dynamic" $credentials.mode -}}
{{- if not (has $mode (list "dynamic" "static")) -}}
  {{- fail (printf "postgresql.db: credentials.mode must be dynamic or static, got %q" $mode) -}}
{{- end -}}
{{- $clusterSelector := default $g.cluster $g.clusterSelector -}}
{{- $vaultSelector := default $g.selector $g.vaultSelector -}}
{{- $pg := include "postgresql.resolveLexicon" (list $root $clusterSelector) | fromJson -}}
{{- if and (eq $mode "static") (not $pg.managerSuperuser) -}}
  {{- fail "postgresql.db: static credentials require the postgres lexicon entry to publish managerSuperuser: true, matching dbEngine.managerSuperuser on the cluster, so Vault can rotate CNPG-created roles" -}}
{{- end -}}
{{- $dbName := include "postgresql.identifier" (list "databaseName" (default $appName $g.databaseName)) -}}
{{- $username := $appName -}}
{{- if eq $mode "static" -}}
  {{- $username = include "postgresql.identifier" (list "credentials.username" (default $appName $credentials.username)) -}}
{{- end -}}
{{- $ownerDefault := ternary $username $appName (eq $mode "static") -}}
{{- $owner := include "postgresql.identifier" (list "owner" (default $ownerDefault $g.owner)) -}}
{{- if and (eq $mode "static") (ne $owner $username) -}}
  {{- fail "postgresql.db: static credentials require owner to equal credentials.username" -}}
{{- end -}}
{{- $access := default (default "read-write" $g.role) $credentials.access -}}
{{- if not (has $access (list "read-write" "read-only")) -}}
  {{- fail (printf "postgresql.db: credentials.access must be read-write or read-only, got %q" $access) -}}
{{- end -}}
{{- if and (eq $access "read-only") (not $g.creationStatements) -}}
  {{- fail "postgresql.db: built-in read-only grants are disabled because the shared engine connects to the maintenance database; provide creationStatements explicitly" -}}
{{- end -}}
{{- if and (eq $mode "static") (eq $access "read-only") -}}
  {{- fail "postgresql.db: static read-only credentials are not supported yet" -}}
{{- end -}}
{{- $accessShort := ternary "rw" "ro" (eq $access "read-write") -}}
{{- $legacyVaultRoleName := printf "%s-%s" $dbName $accessShort -}}
{{- $scopedVaultRoleName := printf "%s-%s-%s" $pg.clusterName $dbName $accessShort -}}
{{- $runikCoordinates := include "vault.databaseCoordinates" (list $root (dict "name" (default $appName $credentials.name) "selector" $vaultSelector) $mode) | fromJson -}}
{{- $legacyDefaultRoleName := ternary $scopedVaultRoleName $legacyVaultRoleName (eq $mode "static") -}}
{{- $vaultRoleName := default (ternary $legacyDefaultRoleName $runikCoordinates.name $pg.legacyDatabaseMount) (default $g.vaultRoleName $credentials.vaultRoleName) -}}
{{- $databaseMount := ternary $pg.databaseMount $runikCoordinates.mount $pg.legacyDatabaseMount -}}
{{- $runikConnectionStem := printf "%s-%s" $runikCoordinates.spell $pg.clusterName -}}
{{- if ne $runikCoordinates.base "db" -}}{{- $runikConnectionStem = printf "%s-%s" $runikConnectionStem $runikCoordinates.base -}}{{- end -}}
{{- $runikConnectionName := $runikConnectionStem | lower | trunc 63 | trimSuffix "-" -}}
{{- $vaultConnectionName := ternary $pg.clusterName $runikConnectionName $pg.legacyDatabaseMount -}}
{{- $serviceAccount := default (default $appName $g.serviceAccount) $credentials.serviceAccount -}}
{{- $authRole := default $serviceAccount $credentials.authRole -}}
{{- if not $pg.legacyDatabaseMount -}}{{- $authRole = include "vault.databaseAuthRole" (list $root $serviceAccount $credentials.authRole) -}}{{- end -}}
{{- $databaseCfg := deepCopy (default dict $g.database) -}}
{{- $ownerRoleCfg := deepCopy (default dict $g.ownerRole) -}}
{{- $createDatabase := ne false $databaseCfg.create -}}
{{- $declarativeOwnerRole := or (eq $mode "static") $pg.managerSuperuser -}}
{{- $createOwnerRole := and $declarativeOwnerRole (ne false $ownerRoleCfg.create) -}}
{{- $databaseResourceName := default (ternary (include "postgresql.resourceName" (list $pg.clusterName $dbName)) $dbName (eq $mode "static")) $databaseCfg.resourceName -}}
{{- $ownerRoleResourceName := default (include "postgresql.resourceName" (list $pg.clusterName $owner)) $ownerRoleCfg.resourceName -}}

{{- /* 1. The stable owner/login exists before Database reconciliation. CNPG
       owns role existence and attributes; Vault alone owns its password. */ -}}
{{- if $createOwnerRole }}
---
apiVersion: postgresql.cnpg.io/v1
kind: DatabaseRole
metadata:
  name: {{ $ownerRoleResourceName }}
  namespace: {{ $pg.namespace }}
  labels:
    {{- include "common.all.labels" $root | nindent 4 }}
    {{- with $ownerRoleCfg.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  annotations:
    argocd.argoproj.io/sync-wave: {{ default "-3" $ownerRoleCfg.syncWave | quote }}
    {{- with $ownerRoleCfg.annotations }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  cluster:
    name: {{ $pg.clusterName }}
  name: {{ $owner }}
  ensure: present
  login: {{ eq $mode "static" }}
  databaseRoleReclaimPolicy: {{ default "retain" $ownerRoleCfg.reclaimPolicy }}
{{- end }}

{{- /* 2. The database itself, after its owner exists. */ -}}
{{- if $createDatabase }}
---
apiVersion: postgresql.cnpg.io/v1
kind: Database
metadata:
  name: {{ $databaseResourceName }}
  namespace: {{ $pg.namespace }}
  labels:
    {{- include "common.all.labels" $root | nindent 4 }}
    {{- with $databaseCfg.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  annotations:
    argocd.argoproj.io/sync-wave: {{ default "-2" $databaseCfg.syncWave | quote }}
    {{- with $databaseCfg.annotations }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  cluster:
    name: {{ $pg.clusterName }}
  name: {{ $dbName }}
  owner: {{ $owner }}
  ensure: present
  databaseReclaimPolicy: {{ default "retain" $databaseCfg.reclaimPolicy }}
{{ end }}

{{- /* Canonical Runik scopes use a per-spell mount, so the selected physical
       resource must also be registered as a connection inside that mount. The
       producer owns and publishes the manager Secret; consumers never rotate
       that shared manager from their individual mounts. */ -}}
{{- if not $pg.legacyDatabaseMount }}
{{ include "vault.databaseEngine" (list $root (dict
    "name" $vaultConnectionName
    "pluginName" "postgresql-database-plugin"
    "connectionPrefix" "postgresql://"
    "connectionSuffix" (printf "@%s:%s/%s" $pg.host $pg.port $pg.engineDatabase)
    "credentialsSecret" $pg.engineCredentialsSecret
    "allowedRoles" (list $vaultRoleName)
    "databaseMount" $databaseMount
    "configNamespace" $pg.engineConfigNamespace
    "rootRotation" false
    "selector" $vaultSelector
    "annotations" (dict "argocd.argoproj.io/sync-wave" "-2")
)) }}
{{- end }}

{{- /* 3. Vault manages either an ephemeral login inheriting the stable owner,
       or the password of the stable LOGIN role. */ -}}
{{- $n := "{{name}}" -}}
{{- $pw := "{{password}}" -}}
{{- $exp := "{{expiration}}" -}}
{{- $vaultAnnotations := deepCopy (default dict $credentials.vaultAnnotations) -}}
{{- if not (hasKey $vaultAnnotations "argocd.argoproj.io/sync-wave") -}}
  {{- $_ := set $vaultAnnotations "argocd.argoproj.io/sync-wave" "-1" -}}
{{- end -}}
{{- if eq $mode "dynamic" -}}
{{- $creation := $g.creationStatements -}}
{{- if not $creation -}}
  {{- if $declarativeOwnerRole -}}
    {{- $creation = list
        (printf "CREATE ROLE \"%s\" WITH LOGIN PASSWORD '%s' VALID UNTIL '%s' IN ROLE \"%s\";" $n $pw $exp $owner)
        (printf "ALTER ROLE \"%s\" SET ROLE \"%s\";" $n $owner)
    -}}
  {{- else -}}
    {{- /* Backward-compatible path for clusters whose manager is CREATEROLE
           but not superuser. The manager creates the owner itself and thereby
           receives ADMIN OPTION on it. New shared clusters should publish
           managerSuperuser: true and use the declarative DatabaseRole path. */ -}}
    {{- $ownerSeed := printf "DO $$ BEGIN IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '%s') THEN CREATE ROLE \"%s\" NOLOGIN; END IF; END $$;" $owner $owner -}}
    {{- $creation = list
        $ownerSeed
        (printf "CREATE ROLE \"%s\" WITH LOGIN PASSWORD '%s' VALID UNTIL '%s' IN ROLE \"%s\";" $n $pw $exp $owner)
        (printf "ALTER ROLE \"%s\" SET ROLE \"%s\";" $n $owner)
    -}}
  {{- end -}}
{{- end -}}
{{ include "vault.databaseRole" (list $root (dict
    "name" $vaultRoleName
    "dBName" $vaultConnectionName
    "databaseMount" $databaseMount
    "creationStatements" $creation
    "revocationStatements" $g.revocationStatements
    "renewStatements" $g.renewStatements
    "rollbackStatements" $g.rollbackStatements
    "configNamespace" (default $g.configNamespace $credentials.configNamespace)
    "defaultTTL" (default $g.defaultTTL $credentials.defaultTTL)
    "maxTTL" (default $g.maxTTL $credentials.maxTTL)
    "selector" $vaultSelector
    "annotations" $vaultAnnotations
)) }}
{{- else -}}
{{- $rotation := default (list (printf "ALTER ROLE \"%s\" WITH LOGIN PASSWORD '%s';" $n $pw)) $credentials.rotationStatements -}}
{{ include "vault.databaseStaticRole" (list $root (dict
    "name" $vaultRoleName
    "dBName" $vaultConnectionName
    "databaseMount" $databaseMount
    "username" $username
    "rotationPeriod" $credentials.rotationPeriod
    "rotationStatements" $rotation
    "passwordPolicy" $credentials.passwordPolicy
    "configNamespace" (default $g.configNamespace $credentials.configNamespace)
    "selector" $vaultSelector
    "annotations" $vaultAnnotations
)) }}
{{- end }}

{{- /* 4. Materialize the exact role path in the app namespace. Dynamic mode
       retains the legacy env/Opaque contract; static defaults to basic-auth. */ -}}
{{- $secretAnnotations := deepCopy (default dict $g.annotations) -}}
{{- $_ := mergeOverwrite $secretAnnotations (deepCopy (default dict $credentials.annotations)) -}}
{{- if not (hasKey $secretAnnotations "argocd.argoproj.io/sync-wave") -}}
  {{- $_ := set $secretAnnotations "argocd.argoproj.io/sync-wave" "0" -}}
{{- end -}}
{{- $_ := set $secretAnnotations "runik.ing/postgresql-cluster" $pg.clusterName -}}
{{- $_ := set $secretAnnotations "runik.ing/credentials" $mode -}}
{{- $defaultStaticData := ternary
      (dict "host" $pg.host "port" ($pg.port | quote) "dbname" $dbName "database" $dbName)
      (dict "HOST" $pg.host "PORT" ($pg.port | quote) "DBNAME" $dbName)
      (eq $mode "static") -}}
{{- $staticData := mergeOverwrite $defaultStaticData (deepCopy (default dict $credentials.staticData)) -}}
{{- $secretDefinition := dict
    "name" (default (default $appName $g.secretName) $credentials.secretName)
    "random" false
    "generationType" (ternary "database-static" "database" (eq $mode "static"))
    "databaseCredsName" $vaultRoleName
    "databaseMount" $databaseMount
    "serviceAccount" $serviceAccount
    "customRole" $authRole
    "format" (default (ternary "plain" "env" (eq $mode "static")) $credentials.format)
    "keys" (default (list "username" "password") $credentials.keys)
    "staticData" $staticData
    "templateData" $credentials.templateData
    "secretType" (default (ternary "kubernetes.io/basic-auth" "Opaque" (eq $mode "static")) $credentials.secretType)
    "namespace" $credentials.namespace
    "nameOverwrite" $credentials.outputName
    "labels" (default $g.labels $credentials.labels)
    "annotations" $secretAnnotations
    "selector" $vaultSelector
-}}
{{- if eq $mode "static" -}}
  {{- $_ := set $secretDefinition "refreshThreshold" (default 80 $credentials.refreshThreshold) -}}
  {{- with $credentials.refreshPeriod }}{{- $_ := set $secretDefinition "refreshPeriod" . }}{{- end -}}
{{- else -}}
  {{- $_ := set $secretDefinition "refreshPeriod" (default (default "30m0s" $g.refreshPeriod) $credentials.refreshPeriod) -}}
  {{- with $credentials.refreshThreshold }}{{- $_ := set $secretDefinition "refreshThreshold" . }}{{- end -}}
{{- end -}}
{{ include "vault.secret" (list $root $secretDefinition) }}
{{- end -}}
