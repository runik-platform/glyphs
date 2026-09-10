{{/*Runik Platform
Copyright (C) 2026 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

mongodb.cluster owns a PerconaServerMongoDB cluster and its scheduled backup
storage. When operations is enabled it also composes one MongoDBEngine and the
stable administrative identity used by the logical operations controller.

No bootstrap Job is rendered. Percona creates the stable administrative user
from spec.users; application users are reconciled through MongoDBUser resources.
*/}}
{{- define "mongodb.cluster" -}}
{{- $root := index . 0 -}}
{{- $definition := index . 1 -}}
{{- $clusterName := default (include "common.name" $root) $definition.name -}}
{{- $namespace := default $root.Release.Namespace $definition.namespace -}}

{{- $operations := deepCopy (default dict $definition.operations) -}}
{{- $operationsEnabled := false -}}
{{- if hasKey $definition "operations" }}{{- $operationsEnabled = ne false $operations.enabled -}}{{- end -}}
{{- $credentials := deepCopy (default dict $operations.credentials) -}}
{{- $generateCredentials := true -}}
{{- if hasKey $credentials "generate" }}{{- $generateCredentials = $credentials.generate -}}{{- end -}}
{{- $managerUser := default "mongodb_operator" $operations.username -}}
{{- $managerSecretRef := deepCopy (default dict $operations.credentialsSecretRef) -}}
{{- $managerSecret := default (printf "%s-operator-admin" $clusterName) $managerSecretRef.name -}}
{{- $managerSecretNamespace := default $namespace $managerSecretRef.namespace -}}
{{- $managerUsernameKey := default "USERNAME" $managerSecretRef.usernameKey -}}
{{- $managerPasswordKey := default "PASSWORD" $managerSecretRef.passwordKey -}}
{{- $managerSourceName := $managerSecret -}}
{{- with $credentials.generationRevision }}{{- $managerSourceName = include "mongodb.safeName" (printf "%s-%s" $managerSecret .) -}}{{- end -}}
{{- if and $operationsEnabled (ne $managerSecretNamespace $namespace) -}}
  {{- fail "mongodb.cluster: operations credentials Secret must be in the Percona cluster namespace" -}}
{{- end -}}
{{- $users := list -}}
{{- if $operationsEnabled -}}
  {{- $users = append $users (dict
        "name" $managerUser
        "db" "admin"
        "passwordSecretRef" (dict "name" $managerSecret "key" $managerPasswordKey)
        "roles" (default (list
          (dict "name" "userAdminAnyDatabase" "db" "admin")
          (dict "name" "dbAdminAnyDatabase" "db" "admin")) $operations.roles)) -}}
{{- end -}}

{{- /* Build the Percona spec with conservative production defaults and allow a raw spec override. */ -}}
{{- $spec := deepCopy (default dict $definition.spec) -}}
{{- if not (hasKey $spec "crVersion") }}{{- $_ := set $spec "crVersion" (default "1.23.0" $definition.crVersion) -}}{{- end -}}
{{- if not (hasKey $spec "image") }}{{- $_ := set $spec "image" (default "percona/percona-server-mongodb:8.0.26-11" $definition.image) -}}{{- end -}}
{{- if not (hasKey $spec "updateStrategy") }}{{- $_ := set $spec "updateStrategy" (default "SmartUpdate" $definition.updateStrategy) -}}{{- end -}}
{{- if not (hasKey $spec "upgradeOptions") }}{{- $_ := set $spec "upgradeOptions" (dict "apply" "disabled" "schedule" "0 2 * * *" "setFCV" false "versionServiceEndpoint" "https://check.percona.com") -}}{{- end -}}
{{- if not (hasKey $spec "tls") }}{{- $_ := set $spec "tls" (default (dict "mode" "requireTLS" "allowInvalidCertificates" true "certManagementPolicy" "auto") $definition.tls) -}}{{- end -}}
{{- if not (hasKey $spec "pmm") }}{{- $_ := set $spec "pmm" (default (dict "enabled" false "image" "percona/pmm-client:3.8.1" "serverHost" "monitoring-service") $definition.pmm) -}}{{- end -}}
{{- if not (hasKey $spec "replsets") -}}
  {{- $storage := default dict $definition.storage -}}
  {{- $pvc := dict "resources" (dict "requests" (dict "storage" (default "10Gi" $storage.size))) -}}
  {{- with $storage.storageClassName }}{{- $_ := set $pvc "storageClassName" . -}}{{- end -}}
  {{- $replset := dict
        "name" (default "rs0" $definition.replsetName)
        "size" (default 3 $definition.size)
        "affinity" (default (dict "antiAffinityTopologyKey" "kubernetes.io/hostname") $definition.affinity)
        "podDisruptionBudget" (default (dict "maxUnavailable" 1) $definition.podDisruptionBudget)
        "resources" (default (dict "requests" (dict "cpu" "300m" "memory" "1Gi") "limits" (dict "cpu" "2" "memory" "4Gi")) $definition.resources)
        "volumeSpec" (dict "persistentVolumeClaim" $pvc) -}}
  {{- /* The logical controller and application users authenticate with SCRAM, not
         client certificates. Keep TLS mandatory while allowing those clients
         to complete the handshake. A caller-supplied MongoDB configuration is
         authoritative and must include this setting when applicable. */ -}}
  {{- if and $operationsEnabled (not (hasKey (default dict $definition.replset) "configuration")) -}}
    {{- $_ := set $replset "configuration" "net:\n  tls:\n    allowConnectionsWithoutCertificates: true\n" -}}
  {{- end -}}
  {{- with $definition.replset }}{{- $_ := mergeOverwrite $replset (deepCopy .) -}}{{- end -}}
  {{- $_ := set $spec "replsets" (list $replset) -}}
{{- end -}}
{{- if not (hasKey $spec "sharding") }}{{- $_ := set $spec "sharding" (default (dict "enabled" false) $definition.sharding) -}}{{- end -}}
{{- if gt (len $users) 0 }}{{- $_ := set $spec "users" (concat (default list $spec.users) $users) -}}{{- end -}}

{{- /* Backups are on by default and use the same S3 provider/bucket convention as PostgreSQL. */ -}}
{{- $manageBackup := or (not (hasKey $spec "backup")) (hasKey $definition "backup") -}}
{{- if $manageBackup -}}
{{- $backup := default dict $definition.backup -}}
{{- $backupEnabled := true -}}
{{- if hasKey $backup "enabled" }}{{- $backupEnabled = $backup.enabled -}}{{- end -}}
{{- if $backupEnabled -}}
  {{- $selector := default (dict "default" "book") $backup.selector -}}
  {{- $providers := get (include "runic-system.runic-indexer" (list $root.Values.lexicon $selector "s3-provider" $root.Values.chapter.name) | fromJson) "results" -}}
  {{- if not $providers }}{{- fail (printf "mongodb.cluster: no s3-provider matches selector %v; set backup.enabled=false to opt out" $selector) -}}{{- end -}}
  {{- $provider := index $providers 0 -}}
  {{- $backupName := default (printf "%s-backup" $clusterName) $backup.name -}}
  {{- $bucket := default (printf "%s-%s-%s-backup" $root.Values.spellbook.name $root.Values.chapter.name $clusterName) $backup.bucket -}}
  {{- $credentialsSecret := default $backupName $backup.credentialsSecret -}}
{{- if not $backup.credentialsSecret -}}
{{ include "s3.bucket.impl" (list $root (dict "name" $backupName "namespace" $namespace "bucket" $bucket "selector" $backup.selector "permissions" (list "Read" "Write" "List") "serviceAccount" $clusterName "customRole" (printf "%s-mongodb-system" $clusterName))) }}
{{ printf "\n" }}
  {{- end -}}
  {{- $storageName := default "s3" $backup.storageName -}}
  {{- $storage := dict "type" "s3" "main" true "s3" (dict
        "bucket" $bucket
        "credentialsSecret" $credentialsSecret
        "endpointUrl" (default $provider.endpoint $provider.internalEndpoint)
        "region" (default "us-east-1" $provider.region)
        "prefix" (default $clusterName $backup.prefix)
        "insecureSkipTLSVerify" (default false $backup.insecureSkipTLSVerify)) -}}
  {{- $tasks := default (list (dict
        "name" "weekly"
        "enabled" true
        "schedule" (default "0 3 * * 0" $backup.schedule)
        "storageName" $storageName
        "retention" (dict "count" (default 7 $backup.retentionCount) "type" "count" "deleteFromStorage" true)
        "compressionType" "gzip")) $backup.tasks -}}
  {{- $backupSpec := dict
        "enabled" true
        "image" (default "percona/percona-backup-mongodb:2.15.0" $backup.image)
        "storages" (dict $storageName $storage)
        "pitr" (default (dict "enabled" false "oplogOnly" false "compressionType" "gzip" "compressionLevel" 6) $backup.pitr)
        "tasks" $tasks -}}
  {{- with $backup.resources }}{{- $_ := set $backupSpec "resources" . -}}{{- end -}}
  {{- $_ := set $spec "backup" $backupSpec -}}
{{- else -}}
  {{- $_ := set $spec "backup" (dict "enabled" false "image" (default "percona/percona-backup-mongodb:2.15.0" $backup.image)) -}}
{{- end -}}
{{- end -}}

{{- /* The cluster meta never permits backup configuration without a schedule. */ -}}
{{- $finalBackup := default dict $spec.backup -}}
{{- if and $finalBackup.enabled (eq (len (default list $finalBackup.tasks)) 0) -}}
  {{- fail "mongodb.cluster: backup.enabled=true requires at least one scheduled task" -}}
{{- end -}}
{{- range $task := default list $finalBackup.tasks -}}
  {{- if and (ne false $task.enabled) (not $task.schedule) -}}
    {{- fail (printf "mongodb.cluster: backup task %q requires schedule" (default "unnamed" $task.name)) -}}
  {{- end -}}
{{- end -}}

{{ include "mongodb.instance" (list $root (dict
    "name" $clusterName
    "namespace" $namespace
    "labels" $definition.labels
    "annotations" $definition.annotations
    "finalizers" (default (list "percona.com/delete-psmdb-pods-in-order") $definition.finalizers)
    "spec" $spec
)) }}

---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ $clusterName }}
  namespace: {{ $namespace }}
  labels:
    {{- include "common.all.labels" $root | nindent 4 }}
{{- if and $operationsEnabled $generateCredentials -}}
{{- $vaultServers := get (include "runic-system.runic-indexer" (list $root.Values.lexicon (merge (default dict $credentials.vaultSelector) (dict "provider" "operator")) "secret-store" $root.Values.chapter.name) | fromJson) "results" -}}
{{- if not $vaultServers }}{{- fail "mongodb.cluster: operations credential generation requires an operator-backed secret-store; set operations.credentials.generate=false to use an existing Secret" -}}{{- end -}}
{{ include "vault.prolicy" (list $root (dict
    "nameOverride" (printf "%s-mongodb-system" $clusterName)
    "serviceAccount" $clusterName
    "targetNamespace" $namespace
    "selector" $credentials.vaultSelector
)) }}
{{ printf "\n" }}
{{ include "vault.secret" (list $root (dict
    "name" $managerSourceName
    "nameOverwrite" $managerSecret
    "namespace" $namespace
    "serviceAccount" $clusterName
    "customRole" (printf "%s-mongodb-system" $clusterName)
    "secretType" "Opaque"
    "path" $credentials.path
    "format" "plain"
    "staticData" (dict $managerUsernameKey $managerUser)
    "random" true
    "randomKey" $managerPasswordKey
    "passPolicyName" (default "short-policy" $credentials.passPolicyName)
    "kvSecretRetainPolicy" (default "Retain" $credentials.kvSecretRetainPolicy)
    "selector" $credentials.vaultSelector
)) }}
{{ printf "\n" }}
{{- end -}}
{{- if $operationsEnabled -}}
{{- $replsetName := default "rs0" $definition.replsetName -}}
{{- $sharded := default false (($spec.sharding).enabled) -}}
{{- /* Percona includes .svc.cluster.local in the generated certificate SANs;
       the shorter .svc hostname is resolvable but cannot be verified. */ -}}
{{- $host := ternary (printf "%s-mongos.%s.svc.cluster.local" $clusterName $namespace) (printf "%s-%s.%s.svc.cluster.local" $clusterName $replsetName $namespace) $sharded -}}
{{- $tlsEnabled := ne "disabled" (default "requireTLS" (($spec.tls).mode)) -}}
{{- $connection := dict
      "host" $host
      "port" 27017
      "authenticationDatabase" "admin"
      "credentialsSecretRef" (dict
        "namespace" $managerSecretNamespace
        "name" $managerSecret
        "usernameKey" $managerUsernameKey
        "passwordKey" $managerPasswordKey)
      "tls" (dict "enabled" $tlsEnabled)
      "timeouts" (default (dict "connectMS" 5000 "serverSelectionMS" 5000 "socketMS" 10000) $operations.timeouts)
      "retry" (default (dict "attempts" 3 "initialBackoffMS" 200) $operations.retry)
      "options" (default (dict "maxPoolSize" 10 "retryReads" true "retryWrites" true) $operations.options) -}}
{{- if and (not $sharded) (not (hasKey $connection.options "replicaSet")) }}{{- $_ := set $connection.options "replicaSet" $replsetName -}}{{- end -}}
{{- if $tlsEnabled -}}
  {{- $_ := set $connection.tls "caRef" (default (dict "kind" "Secret" "namespace" $namespace "name" (printf "%s-ssl" $clusterName) "key" "ca.crt") $operations.tlsCARef) -}}
{{- end -}}
{{- with $operations.connection }}{{- $_ := mergeOverwrite $connection (deepCopy .) -}}{{- end -}}
{{- if (($operations.connection).uri) }}{{- $_ := unset $connection "host" -}}{{- $_ := unset $connection "port" -}}{{- end -}}
{{ include "mongodb.engine" (list $root (dict
    "name" $clusterName
    "connection" $connection
    "allowedNamespaces" (required "mongodb.cluster: operations.allowedNamespaces is required" $operations.allowedNamespaces)
    "labels" $operations.labels
    "annotations" $operations.annotations
)) }}
{{- end -}}
{{- end -}}
