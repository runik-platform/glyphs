{{/*Runik Platform
Copyright (C) 2025 laaledesiempre@disroot.org
SPDX-License-Identifier: AGPL-3.0-only

postgresql.cluster — META glyph. Renders the full PG instance bundle:
  1. (optional) s3.bucket.impl — provisions backup bucket + VaultSecret
  2. postgresql.objectStore     — Barman Cloud Plugin ObjectStore CR(s)
  3. postgresql.instance        — Cluster CRD (spec.plugins / recovery)
  4. postgresql.scheduledBackup — daily cron (unless disabled)

Maintains the same surface as the legacy `type: cluster` (image, instances,
dbName, userName, secret, storage, postInit*, postgresql params, etc.) and
adds two new top-level fields:

  backup: {} (DEFAULT: enabled with sensible defaults)
    enabled: true|false           # opt-out
    retention: "90d"              # ObjectStore retentionPolicy
    schedule: "0 0 3 * * *"       # daily at 03:00 (Quartz 6-field)
    bucket: <name>                # default: <book>-<chapter>-<cluster>-backup
    s3SecretRef: <secret>         # if set, skips s3.bucket auto-provisioning
                                  # (use it to back up to an EXTERNAL S3)
    destinationPath: s3://...     # default: s3://<bucket>/<cluster-name>
    endpointURL: http://...       # default: lexicon s3-provider.internalEndpoint
                                  # (falls back to .endpoint)
    selector: {}                  # selector for the s3-provider lexicon lookup
    accessKeyIdKey: AWS_ACCESS_KEY_ID
    secretAccessKeyKey: AWS_SECRET_ACCESS_KEY

  restore: {} (default: not set — fresh init via bootstrap.initdb)
    Modality A — convention shortcut (same book/chapter, same namespace):
      from: <source-cluster-name>     # derives destinationPath, endpoint,
                                      # s3SecretRef by the same convention
                                      # the source cluster used.
      targetTime: "..."               # optional PITR
    Modality B — explicit (any S3, including off-site DR):
      source: <label>
      destinationPath: s3://...
      endpointURL: http://...
      s3SecretRef: <secret>
      targetTime / targetXID / targetName / targetTLI / targetImmediate

  When restore: is set, the meta still configures backup: for the NEW cluster
  (it backs up to its OWN destination, not the source's). To disable that,
  set backup.enabled: false explicitly.
*/}}

{{- define "postgresql.cluster" }}
{{- $root := index . 0 -}}
{{- $glyphDefinition := index . 1 -}}

{{- /* Resolve cluster name (same logic instance uses for metadata.name) */ -}}
{{- $clusterName := default (include "common.name" $root) $glyphDefinition.name -}}

{{- /* Vault DB engine — ON BY DEFAULT, gated by Vault being present in the
       lexicon. If there is no `type: secret-store` entry, nothing Vault-related
       is emitted and the cluster works exactly as before (everything still
       renders without Vault). Opt out explicitly with `dbEngine: {enabled: false}`.
       When on, the cluster emits its superuser secret (unless
       dbEngine.credentialsSecret points at an existing one) and registers a
       Vault database engine via the GENERIC vault.databaseEngine glyph. */ -}}
{{- $dbEngineCfg := default dict $glyphDefinition.dbEngine -}}
{{- $vaultServers := get (include "runic-system.runic-indexer" (list $root.Values.lexicon (merge (default dict $dbEngineCfg.selector) (dict "provider" "operator")) "secret-store" $root.Values.chapter.name) | fromJson) "results" -}}
{{- $vaultPresent := gt (len $vaultServers) 0 -}}
{{- $engineEnabled := and $vaultPresent (ne false $dbEngineCfg.enabled) -}}
{{- $engineMount := default "database" $dbEngineCfg.databaseMount -}}
{{- $superuserSecretName := default (printf "%s-superuser" $clusterName) (default $glyphDefinition.superuserSecret $dbEngineCfg.credentialsSecret) -}}
{{- /* Dedicated Vault management role: CNPG only creates the role; Vault owns its
       password (rotates it). Keeps Vault off the CNPG-managed superuser, so each
       side rotates independently without fighting. */ -}}
{{- $mgrUser := default "vault_mgr" $dbEngineCfg.managerUser -}}
{{- $mgrSecret := printf "%s-vault-mgr" $clusterName -}}
{{- $mgrRootSecret := printf "%s-vault-mgr-root" $clusterName -}}
{{- $rootRotation := true -}}
{{- if hasKey $dbEngineCfg "rootRotation" -}}
  {{- if not (kindIs "bool" $dbEngineCfg.rootRotation) -}}
    {{- fail "postgresql.cluster: dbEngine.rootRotation must be a boolean" -}}
  {{- end -}}
  {{- $rootRotation = $dbEngineCfg.rootRotation -}}
{{- end -}}

{{- /* Backup defaults — enabled unless explicit opt-out */ -}}
{{- $backupIn := default dict $glyphDefinition.backup -}}
{{- $backupEnabled := true -}}
{{- if hasKey $backupIn "enabled" -}}
  {{- $backupEnabled = $backupIn.enabled -}}
{{- end -}}
{{- $walArchiver := false -}}
{{- if hasKey $backupIn "walArchiver" -}}
  {{- $walArchiver = $backupIn.walArchiver -}}
{{- end -}}
{{- $scheduledBackup := true -}}
{{- if hasKey $backupIn "scheduledBackup" -}}
  {{- $scheduledBackup = $backupIn.scheduledBackup -}}
{{- end -}}


{{- /* Restore convention: if .restore.from is set, derive defaults from it */ -}}
{{- $restoreIn := $glyphDefinition.restore -}}
{{- $restoreOut := dict -}}
{{- if $restoreIn -}}
  {{- if $restoreIn.from -}}
    {{- /* Convention: source cluster's backup secret lives in the same namespace */ -}}
    {{- /* with the conventional name <from>-backup, bucket <book>-<chapter>-<from>-backup, */ -}}
    {{- /* and server-name <from>. Endpoint resolved from the same lexicon entry. */ -}}
    {{- $fromBucket := printf "%s-%s-%s-backup" $root.Values.spellbook.name $root.Values.chapter.name $restoreIn.from -}}
    {{- $restoreOut = dict
      "source" (default $restoreIn.from $restoreIn.source)
      "destinationPath" (default (printf "s3://%s/%s" $fromBucket $restoreIn.from) $restoreIn.destinationPath)
      "s3SecretRef" (default (printf "%s-backup" $restoreIn.from) $restoreIn.s3SecretRef)
      "endpointURL" $restoreIn.endpointURL
      "targetTime" $restoreIn.targetTime
      "targetXID" $restoreIn.targetXID
      "targetName" $restoreIn.targetName
      "targetTLI" $restoreIn.targetTLI
      "targetImmediate" $restoreIn.targetImmediate
      "accessKeyIdKey" $restoreIn.accessKeyIdKey
      "secretAccessKeyKey" $restoreIn.secretAccessKeyKey
    -}}
  {{- else -}}
    {{- /* Explicit modality: pass through as-is */ -}}
    {{- $restoreOut = $restoreIn -}}
  {{- end -}}
{{- end -}}

{{- /* Look up s3 provider via lexicon (needed for backup and for restore.from endpoint default) */ -}}
{{- $needLexicon := or $backupEnabled (and $restoreIn $restoreIn.from (not $restoreIn.endpointURL)) -}}
{{- $s3Provider := dict -}}
{{- if $needLexicon -}}
  {{- $selector := default (dict "default" "book") $backupIn.selector -}}
  {{- $s3Providers := get (include "runic-system.runic-indexer" (list $root.Values.lexicon $selector "s3-provider" $root.Values.chapter.name) | fromJson) "results" -}}
  {{- if not $s3Providers -}}
    {{- fail (printf "postgresql.cluster: no s3-provider found in lexicon for selector %v. To disable backups set backup.enabled: false" $selector) -}}
  {{- end -}}
  {{- $s3Provider = index $s3Providers 0 -}}
  {{- /* Fill restore.endpointURL via convention if missing */ -}}
  {{- if and $restoreIn $restoreIn.from (not $restoreIn.endpointURL) -}}
    {{- $_ := set $restoreOut "endpointURL" (default $s3Provider.endpoint $s3Provider.internalEndpoint) -}}
  {{- end -}}
{{- end -}}

{{- /* Recovery also reads through an ObjectStore CR (the source's) */ -}}
{{- if $restoreOut -}}
  {{- $srcStoreName := printf "%s-restore-src" $clusterName -}}
  {{- $_ := set $restoreOut "barmanObjectName" $srcStoreName -}}
{{ include "postgresql.objectStore" (list $root (dict
    "name" $srcStoreName
    "destinationPath" (get $restoreOut "destinationPath")
    "endpointURL" (get $restoreOut "endpointURL")
    "s3SecretRef" (get $restoreOut "s3SecretRef")
    "accessKeyIdKey" (get $restoreOut "accessKeyIdKey")
    "secretAccessKeyKey" (get $restoreOut "secretAccessKeyKey")
)) }}
{{- end -}}

{{- /* Resolve backup defaults */ -}}
{{- $backupOut := dict -}}
{{- if $backupEnabled -}}
  {{- $backupName := printf "%s-backup" $clusterName -}}
  {{- $defaultBucket := printf "%s-%s-%s-backup" $root.Values.spellbook.name $root.Values.chapter.name $clusterName -}}
  {{- $bucket := default $defaultBucket $backupIn.bucket -}}
  {{- $defaultEndpoint := default $s3Provider.endpoint $s3Provider.internalEndpoint -}}
  {{- $backupOut = dict
    "enabled" true
    "retention" (default "90d" $backupIn.retention)
    "destinationPath" (default (printf "s3://%s/%s" $bucket $clusterName) $backupIn.destinationPath)
    "endpointURL" (default $defaultEndpoint $backupIn.endpointURL)
    "s3SecretRef" (default $backupName $backupIn.s3SecretRef)
    "accessKeyIdKey" (default "AWS_ACCESS_KEY_ID" $backupIn.accessKeyIdKey)
    "secretAccessKeyKey" (default "AWS_SECRET_ACCESS_KEY" $backupIn.secretAccessKeyKey)
    "compression" (default "gzip" $backupIn.compression)
    "barmanObjectName" $clusterName
    "walArchiver" $walArchiver
  -}}

  {{- /* Auto-provision bucket+creds unless user pointed at an external secret */ -}}
  {{- if not $backupIn.s3SecretRef -}}
    {{- include "s3.bucket.impl" (list $root (dict
      "name" $backupName
      "bucket" $bucket
      "selector" $backupIn.selector
    )) }}
  {{- end -}}

  {{- /* Barman config lives in an ObjectStore CR (incl. retention) — Barman
         Cloud Plugin is the only engine (in-tree barman dies in CNPG 1.30) */ -}}
{{ include "postgresql.objectStore" (list $root (dict
      "name" $clusterName
      "destinationPath" (get $backupOut "destinationPath")
      "endpointURL" (get $backupOut "endpointURL")
      "s3SecretRef" (get $backupOut "s3SecretRef")
      "accessKeyIdKey" (get $backupOut "accessKeyIdKey")
      "secretAccessKeyKey" (get $backupOut "secretAccessKeyKey")
      "compression" (get $backupOut "compression")
      "retention" (get $backupOut "retention")
  )) }}
{{- end -}}

{{- /* 1. Cluster CRD via instance (with backup and restore blocks injected) */ -}}
{{- $instanceDef := deepCopy $glyphDefinition -}}
{{- if $engineEnabled -}}
  {{- $_ := set $instanceDef "superuserSecret" $superuserSecretName -}}
  {{- /* CNPG creates vault_mgr with an initial password from its secret; Vault
         then rotates it. CNPG re-applies only on secret change → no fight.
         managerSuperuser: true makes vault_mgr a SUPERUSER so it can issue
         privileged dynamic roles (e.g. a DBA superuser); default is CREATEROLE
         (enough for app roles). */ -}}
  {{- $mgrRole := dict "name" $mgrUser "ensure" "present" "login" true "passwordSecret" (dict "name" $mgrSecret) -}}
  {{- if $dbEngineCfg.managerSuperuser -}}
    {{- $_ := set $mgrRole "superuser" true -}}
  {{- else -}}
    {{- $_ := set $mgrRole "createrole" true -}}
  {{- end -}}
  {{- $_ := set $instanceDef "roles" (append (default list $glyphDefinition.roles) $mgrRole) -}}
{{- end -}}
{{- if $backupEnabled -}}
  {{- $_ := set $instanceDef "backup" $backupOut -}}
{{- else -}}
  {{- $_ := unset $instanceDef "backup" -}}
{{- end -}}
{{- if $restoreOut -}}
  {{- $_ := set $instanceDef "restore" $restoreOut -}}
{{- end -}}
{{ include "postgresql.instance" (list $root $instanceDef) }}

{{- /* 2. Daily ScheduledBackup (when backup enabled) */ -}}
{{- if and $backupEnabled $scheduledBackup }}
{{ include "postgresql.scheduledBackup" (list $root (dict
  "name" (printf "%s-daily" $clusterName)
  "cluster" $clusterName
  "schedule" (default "0 0 3 * * *" $backupIn.schedule)
  "backupOwnerReference" "self"
)) }}
{{- end }}

{{- /* Vault DB engine (when a dbEngine: block is present): superuser secret +
       the generic vault.databaseEngine. postgres only supplies the plugin name
       and the connection string parts; the CRD shape lives in the vault chart
       (reusable for mongo, etc). NOT a prolicy — that's per-workload. */ -}}
{{- if $engineEnabled }}
{{- $vaultConf := index $vaultServers 0 }}
{{- $configNamespace := default $vaultConf.namespace $dbEngineCfg.configNamespace }}
{{- /* Superuser secret for CNPG (its own superuser access). The engine does NOT
       use it — CNPG owns/rotates the superuser independently. superuserRefresh
       (e.g. "720h0m0s") makes the RandomSecret regenerate the password on that
       period; CNPG re-applies it to postgres on the secret change → the superuser
       rotates without touching Vault. */ -}}
{{- if not $dbEngineCfg.credentialsSecret }}
{{- $superuserDef := dict
    "name" $superuserSecretName
    "secretType" "kubernetes.io/basic-auth"
    "staticData" (dict "username" "postgres")
    "random" true -}}
{{- with $dbEngineCfg.superuserRefresh }}{{- $_ := set $superuserDef "refreshPeriod" . }}{{- end }}
{{ include "vault.secret" (list $root $superuserDef) }}
{{- end }}
{{- /* vault_mgr credentials: the bootstrap password CNPG sets on the role (cluster
       ns), and a mirror in the Vault namespace for the engine's rootCredentials.
       After bootstrap Vault rotates vault_mgr and owns the password. */ -}}
{{ include "vault.secret" (list $root (dict
    "name" $mgrSecret
    "secretType" "kubernetes.io/basic-auth"
    "staticData" (dict "username" $mgrUser)
    "random" true
)) }}
{{ include "vault.secret" (list $root (dict
    "name" $mgrRootSecret
    "sourceName" $mgrSecret
    "namespace" $configNamespace
    "serviceAccount" "vault"
    "random" false
    "secretType" "kubernetes.io/basic-auth"
    "keys" (list "password")
    "staticData" (dict "username" $mgrUser)
)) }}
{{/* Engine connects as vault_mgr (a dedicated CREATEROLE role, NOT the superuser)
     to the postgres maintenance DB, and rotates vault_mgr's password. CREATE ROLE
     / membership are cluster-global, so one connection serves every app DB. */}}
{{ include "vault.databaseEngine" (list $root (dict
    "name" $clusterName
    "pluginName" "postgresql-database-plugin"
    "connectionPrefix" "postgresql://"
    "connectionSuffix" (printf "@%s-rw.%s.svc:5432/%s" $clusterName $root.Release.Namespace (default "postgres" $dbEngineCfg.database))
    "username" $mgrUser
    "credentialsSecret" $mgrRootSecret
    "allowedRoles" (default (list "*") $dbEngineCfg.allowedRoles)
    "databaseMount" $engineMount
    "configNamespace" $dbEngineCfg.configNamespace
    "selector" $dbEngineCfg.selector
    "rootRotation" $rootRotation
)) }}
{{- /* Custom dynamic roles offered by the cluster (e.g. dba, monitoring). Each is
       a vault.databaseRole against this cluster's connection (dBName=clusterName).
       The caller supplies creationStatements ({{name}}/{{password}}/{{expiration}}
       are Vault placeholders). A SUPERUSER role needs managerSuperuser: true (only
       a superuser can CREATE a superuser). Anyone allowed by Vault policy can then
       `vault read <mount>/creds/<roleName>`. */ -}}
{{- range $roleName, $roleDef := $dbEngineCfg.roles }}
{{ include "vault.databaseRole" (list $root (dict
    "name" $roleName
    "dBName" $clusterName
    "creationStatements" (required (printf "dbEngine.roles.%s.creationStatements is required" $roleName) $roleDef.creationStatements)
    "databaseMount" $engineMount
    "configNamespace" $dbEngineCfg.configNamespace
    "selector" $dbEngineCfg.selector
    "defaultTTL" $roleDef.defaultTTL
    "maxTTL" $roleDef.maxTTL
)) }}
{{- /* expose: true → manifest the role's dynamic creds as a K8s secret in the
       cluster namespace (env: USERNAME/PASSWORD/HOST/DBNAME), reachable by the
       cluster's prolicy SA. Each VaultSecret refresh issues a fresh dynamic cred
       (so refreshPeriod should stay below the role's TTL). The secret is named
       <cluster>-<role>; override its DB with $roleDef.database (default postgres,
       the maintenance DB — apt for an admin/dba role). */ -}}
{{- if $roleDef.expose }}
{{ include "vault.secret" (list $root (dict
    "name" (printf "%s-%s" $clusterName $roleName)
    "random" false
    "generationType" "database"
    "databaseCredsName" $roleName
    "databaseMount" $engineMount
    "serviceAccount" (default (include "common.name" $root) $roleDef.serviceAccount)
    "customRole" $roleDef.authRole
    "format" "env"
    "refreshPeriod" (default "30m0s" $roleDef.refreshPeriod)
    "keys" (list "username" "password")
    "staticData" (dict "HOST" (printf "%s-rw.%s.svc" $clusterName $root.Release.Namespace) "DBNAME" (default "postgres" $roleDef.database))
    "selector" $dbEngineCfg.selector
)) }}
{{- end }}
{{- end }}
{{- end }}

{{- end }}
