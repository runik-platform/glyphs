{{/*Runik Platform
Copyright (C) 2026 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

cockroachdb.bootstrap owns the retained Vault manager identity and the SQL used
to initialize a physical cluster. Its default Job executor supports secure and
insecure clusters without duplicating bootstrap logic in the physical spell.
*/}}
{{- define "cockroachdb.bootstrap" -}}
{{- $root := index . 0 -}}
{{- $g := index . 1 -}}
{{- $crdb := include "cockroachdb.resolveLexicon" (list $root $g.selector) | fromJson -}}
{{- $manager := deepCopy (default dict $g.manager) -}}
{{- $username := include "cockroachdb.identifier" (list "manager.username" (default "vault_mgr" $manager.username)) -}}
{{- $secretName := default (printf "%s-vault-manager" $crdb.clusterName) $manager.secretName -}}
{{- $passwordTemplate := "{{ .secret.password }}" -}}

{{- $bootstrapSQL := default "" $g.bootstrapSQL -}}
{{- if not $bootstrapSQL -}}
  {{- if $crdb.tlsEnabled -}}
    {{- $bootstrapSQL = printf "CREATE ROLE IF NOT EXISTS \"%s\" WITH LOGIN PASSWORD '%s' CREATEDB CREATEROLE CREATELOGIN;\nALTER ROLE \"%s\" WITH LOGIN PASSWORD '%s' CREATEDB CREATEROLE CREATELOGIN;" $username $passwordTemplate $username $passwordTemplate -}}
  {{- else -}}
    {{- $bootstrapSQL = printf "CREATE ROLE IF NOT EXISTS \"%s\" WITH LOGIN CREATEDB CREATEROLE CREATELOGIN;\nALTER ROLE \"%s\" WITH LOGIN CREATEDB CREATEROLE CREATELOGIN;" $username $username -}}
  {{- end -}}
  {{- $backup := deepCopy (default dict $g.backup) -}}
  {{- $backupEnabled := false -}}
  {{- if hasKey $backup "enabled" -}}
    {{- $backupEnabled = $backup.enabled -}}
    {{- if not (kindIs "bool" $backupEnabled) -}}
      {{- fail "cockroachdb.bootstrap: backup.enabled must be a boolean" -}}
    {{- end -}}
  {{- end -}}
  {{- if $backupEnabled -}}
    {{- $scheduleName := include "cockroachdb.identifier" (list "backup.scheduleName" (default (printf "%s_s3_backup" ($crdb.clusterName | replace "-" "_")) $backup.scheduleName)) -}}
    {{- $uri := required "cockroachdb.bootstrap: backup.uri is required when backup.enabled=true" $backup.uri | replace "'" "''" -}}
    {{- $recurring := default "@daily" $backup.recurring | replace "'" "''" -}}
    {{- $fullBackup := default "@weekly" $backup.fullBackup | replace "'" "''" -}}
    {{- $bootstrapSQL = printf "%s\nCREATE SCHEDULE IF NOT EXISTS %s\nFOR BACKUP INTO '%s'\nWITH revision_history\nRECURRING '%s'\nFULL BACKUP '%s'\nWITH SCHEDULE OPTIONS first_run = 'now', on_execution_failure = 'retry', on_previous_running = 'wait', updates_cluster_last_backup_time_metric;" $bootstrapSQL $scheduleName $uri $recurring $fullBackup -}}
  {{- end -}}
{{- end -}}

{{- $annotations := deepCopy (default dict $g.annotations) -}}
{{- $_ := set $annotations "runik.ing/cockroachdb-cluster" $crdb.clusterName -}}
{{ include "vault.secret" (list $root (dict
    "name" $secretName
    "namespace" $crdb.namespace
    "serviceAccount" (default $crdb.clusterName $manager.serviceAccount)
    "secretType" "kubernetes.io/basic-auth"
    "path" (default "book" $manager.path)
    "staticData" (dict "username" $username)
    "templateData" (dict "bootstrap.sql" $bootstrapSQL)
    "annotations" $annotations
    "kvSecretRetainPolicy" (default "Retain" $manager.kvSecretRetainPolicy)
    "passPolicyName" $manager.passPolicyName
    "random" true
)) }}

{{ $engine := deepCopy (default dict $g.engine) -}}
{{- $engineEnabled := true -}}
{{- if hasKey $engine "enabled" -}}
  {{- $engineEnabled = $engine.enabled -}}
  {{- if not (kindIs "bool" $engineEnabled) -}}
    {{- fail "cockroachdb.bootstrap: engine.enabled must be a boolean" -}}
  {{- end -}}
{{- end -}}
{{- if $engineEnabled -}}
{{- $vaultSelector := merge (deepCopy (default dict $engine.vaultSelector)) (dict "provider" "operator") -}}
{{- $vaultServers := get (include "runic-system.runic-indexer" (list $root.Values.lexicon $vaultSelector "secret-store" $root.Values.chapter.name) | fromJson) "results" -}}
{{- if not $vaultServers -}}
  {{- fail "cockroachdb.bootstrap: engine.enabled=true requires an operator-backed secret-store in the lexicon" -}}
{{- end -}}
{{- $vaultConf := index $vaultServers 0 -}}
{{- $engineNamespace := default (default "vault" $vaultConf.namespace) $engine.configNamespace -}}
{{- $engineCredentialsSecret := default (printf "%s-vault-manager-root" $crdb.clusterName) $engine.credentialsSecret -}}
{{- $verifyConnection := true -}}
{{- if hasKey $engine "verifyConnection" -}}
  {{- $verifyConnection = $engine.verifyConnection -}}
  {{- if not (kindIs "bool" $verifyConnection) -}}
    {{- fail "cockroachdb.bootstrap: engine.verifyConnection must be a boolean" -}}
  {{- end -}}
{{- end -}}
{{ include "vault.secret" (list $root (dict
    "name" $engineCredentialsSecret
    "sourceName" $secretName
    "namespace" $engineNamespace
    "serviceAccount" (default "vault" $engine.serviceAccount)
    "secretType" "kubernetes.io/basic-auth"
    "path" (default "book" $manager.path)
    "keys" (list "password")
    "staticData" (dict "username" $username)
    "annotations" $annotations
    "refreshThreshold" (default 90 $engine.refreshThreshold)
    "refreshPeriod" (default "3m0s" $engine.refreshPeriod)
    "random" false
)) }}
{{ include "vault.databaseEngine" (list $root (dict
    "name" (default $crdb.clusterName $engine.name)
    "pluginName" "postgresql-database-plugin"
    "verifyConnection" $verifyConnection
    "connectionPrefix" "postgresql://"
    "connectionSuffix" (printf "@%s:%s/%s?sslmode=%s" $crdb.host $crdb.port (default "defaultdb" $engine.database) $crdb.sslmode)
    "credentialsSecret" $engineCredentialsSecret
    "configNamespace" $engineNamespace
    "databaseMount" (default $crdb.databaseMount $engine.databaseMount)
    "allowedRoles" $engine.allowedRoles
    "rootRotation" $engine.rootRotation
    "rootRotationPeriod" $engine.rootRotationPeriod
    "rootRotationStatements" $engine.rootRotationStatements
)) }}
{{- end }}

{{ $execution := deepCopy (default dict $g.execution) -}}
{{- $executionMode := default "job" $execution.mode -}}
{{- if not (has $executionMode (list "postInitSQL" "job")) -}}
  {{- fail (printf "cockroachdb.bootstrap: execution.mode must be postInitSQL or job; got %q" $executionMode) -}}
{{- end -}}
{{- if and (eq $executionMode "postInitSQL") (not $crdb.tlsEnabled) -}}
  {{- fail "cockroachdb.bootstrap: execution.mode=postInitSQL requires tls.enabled=true; use job for an insecure cluster" -}}
{{- end -}}
{{- $renderJob := eq $executionMode "job" -}}
{{- if $renderJob }}
{{- $jobName := default (printf "%s-bootstrap" $crdb.clusterName) $execution.name -}}
{{- $jobAnnotations := deepCopy (default dict $execution.annotations) -}}
{{- if not (hasKey $jobAnnotations "argocd.argoproj.io/hook") -}}{{- $_ := set $jobAnnotations "argocd.argoproj.io/hook" "Sync" -}}{{- end -}}
{{- if not (hasKey $jobAnnotations "argocd.argoproj.io/hook-delete-policy") -}}{{- $_ := set $jobAnnotations "argocd.argoproj.io/hook-delete-policy" "BeforeHookCreation" -}}{{- end -}}
{{- if not (hasKey $jobAnnotations "argocd.argoproj.io/sync-wave") -}}{{- $_ := set $jobAnnotations "argocd.argoproj.io/sync-wave" "0" -}}{{- end -}}
---
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ $jobName }}
  namespace: {{ $crdb.namespace }}
  labels:
    {{- include "common.all.labels" $root | nindent 4 }}
  annotations:
    {{- toYaml $jobAnnotations | nindent 4 }}
spec:
  backoffLimit: {{ default 20 $execution.backoffLimit }}
  activeDeadlineSeconds: {{ default 1800 $execution.activeDeadlineSeconds }}
  template:
    metadata:
      labels:
        {{- include "common.selectorLabels" $root | nindent 8 }}
    spec:
      automountServiceAccountToken: false
      restartPolicy: OnFailure
      containers:
        - name: bootstrap
          image: {{ default "cockroachdb/cockroach:v26.2.5" $execution.image }}
          imagePullPolicy: {{ default "IfNotPresent" $execution.imagePullPolicy }}
          args:
            - sql
            - --host={{ $crdb.host }}:{{ $crdb.port }}
            - --user=root
            - --file=/bootstrap/bootstrap.sql
            {{- if $crdb.tlsEnabled }}
            - --certs-dir=/cockroach-certs
            {{- else }}
            - --insecure
            {{- end }}
          resources:
            {{- toYaml (default (dict "requests" (dict "cpu" "50m" "memory" "64Mi") "limits" (dict "cpu" "250m" "memory" "256Mi")) $execution.resources) | nindent 12 }}
          volumeMounts:
            - name: bootstrap
              mountPath: /bootstrap
              readOnly: true
            {{- if $crdb.tlsEnabled }}
            - name: client-certs
              mountPath: /cockroach-certs
              readOnly: true
            {{- end }}
      volumes:
        - name: bootstrap
          secret:
            secretName: {{ $secretName }}
            items:
              - key: bootstrap.sql
                path: bootstrap.sql
        {{- if $crdb.tlsEnabled }}
        - name: client-certs
          secret:
            secretName: {{ default (printf "%s-client-secret" $crdb.clusterName) $execution.rootClientSecret }}
            items:
              - key: ca.crt
                path: ca.crt
              - key: tls.crt
                path: client.root.crt
              - key: tls.key
                path: client.root.key
        {{- end }}
{{- end -}}
{{- end -}}
