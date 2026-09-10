{{/*Runik Platform
Copyright (C) 2025 laaledesiempre@disroot.org
SPDX-License-Identifier: AGPL-3.0-only

postgresql.instance — Renders a single CloudNativePG Cluster CRD.

This is the pure per-CRD glyph: it emits only the Cluster resource (and the
optional postInit ConfigMaps that the Cluster spec references). It does NOT
provision any S3 bucket, does NOT create a ScheduledBackup. Use the meta
`type: cluster` for a full PG instance with backups and conventions, or call
`type: instance` directly when you want the raw CRD with no orchestration.

Supports `backup:` and `restore:` blocks. Backups use the Barman Cloud
Plugin: `backup:` renders spec.plugins (the ObjectStore CR is the meta's
job), and `restore:` renders spec.bootstrap.recovery + spec.externalClusters
(.plugin). The fields
required for those blocks must be passed explicitly when invoking `instance`
directly; the meta `cluster` glyph computes them via the s3 lexicon.

backup: {} fields when invoking instance directly:
  enabled: true|false                   # if false, skip the plugin reference
  barmanObjectName: "<object-store>"    # required; ObjectStore must exist
  walArchiver: true|false               # optional; default false

restore: {} fields:
  source: "<external-cluster-name>"   # arbitrary label, used both in
                                      # spec.bootstrap.recovery.source AND
                                      # in the externalClusters[].name entry
  barmanObjectName: "<source-object-store>"  # required; ObjectStore must exist
  targetTime: "YYYY-MM-DD HH:MM:SS"  # optional PITR target
*/}}

{{- define "postgresql.instance" }}
{{- $root := index . 0 -}}
{{- $glyphDefinition := index . 1 -}}
{{- $enableSuperuserAccess := true -}}
{{- if hasKey $glyphDefinition "enableSuperuserAccess" -}}
  {{- $enableSuperuserAccess = $glyphDefinition.enableSuperuserAccess -}}
{{- else if hasKey (default dict $glyphDefinition.superuser) "enabled" -}}
  {{- $enableSuperuserAccess = $glyphDefinition.superuser.enabled -}}
{{- end }}

---
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: {{ default (include "common.name" $root ) $glyphDefinition.name }}
  labels:
    {{- include "common.all.labels" $root | nindent 4 }}
    {{- with $glyphDefinition.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- with $glyphDefinition.annotations }}
  annotations:
    {{- include "common.annotations" $root | nindent 4 }}
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  description: {{ default (print "PostgreSQL cluster for " (default (include "common.name" $root ) $glyphDefinition.name)) $glyphDefinition.description }}

  {{- with $glyphDefinition.image }}
  imageName: {{ include "summon.getImage" (list $root $glyphDefinition) }}
  {{- end}}

  instances: {{ default 1 $glyphDefinition.instances }}

  {{- with $glyphDefinition.minSyncReplicas }}
  minSyncReplicas: {{ . }}
  {{- end }}

  {{- with $glyphDefinition.maxSyncReplicas }}
  maxSyncReplicas: {{ . }}
  {{- end }}

  {{- with $glyphDefinition.startDelay }}
  startDelay: {{ . }}
  {{- end}}

  {{- with $glyphDefinition.stopDelay }}
  stopDelay: {{ . }}
  {{- end}}

  {{- with $glyphDefinition.primaryUpdateStrategy }}
  primaryUpdateStrategy: {{ . }}
  {{- end}}

  {{- with $glyphDefinition.primaryUpdateMethod }}
  primaryUpdateMethod: {{ . }}
  {{- end}}

  {{- with $glyphDefinition.roles}}
  managed:
     roles:
       {{- toYaml . | nindent 6 }}
  {{- end}}

  enableSuperuserAccess: {{ $enableSuperuserAccess }}
  {{- if $glyphDefinition.superuserSecret }}
  superuserSecret:
    name: {{ $glyphDefinition.superuserSecret }}
  {{- end }}

  {{- if $glyphDefinition.restore }}
  {{- $r := $glyphDefinition.restore }}
  bootstrap:
    recovery:
      source: {{ required "postgresql.instance: restore.source is required" $r.source | quote }}
      {{- if or $r.targetTime $r.targetXID $r.targetName $r.targetTLI $r.targetImmediate }}
      recoveryTarget:
        {{- with $r.targetTime }}
        targetTime: {{ . | quote }}
        {{- end }}
        {{- with $r.targetXID }}
        targetXID: {{ . | quote }}
        {{- end }}
        {{- with $r.targetName }}
        targetName: {{ . | quote }}
        {{- end }}
        {{- with $r.targetTLI }}
        targetTLI: {{ . | quote }}
        {{- end }}
        {{- with $r.targetImmediate }}
        targetImmediate: {{ . }}
        {{- end }}
      {{- end }}
  externalClusters:
    - name: {{ $r.source | quote }}
      plugin:
        name: barman-cloud.cloudnative-pg.io
        parameters:
          barmanObjectName: {{ required "postgresql.instance: restore.barmanObjectName is required" $r.barmanObjectName }}
          serverName: {{ $r.source | quote }}
  {{- else if or $glyphDefinition.dbName $glyphDefinition.userName $glyphDefinition.secret $glyphDefinition.postInitSQL $glyphDefinition.postInitApp $glyphDefinition.postInitTemplate $glyphDefinition.postInitPostgres }}
  bootstrap:
    initdb:
      database: {{ default (include "common.name" $root ) $glyphDefinition.dbName }}
      owner: {{ default (include "common.name" $root ) $glyphDefinition.userName }}

      {{- with $glyphDefinition.secret }}
      secret:
        name: {{ . }}
      {{- end }}

      {{- with $glyphDefinition.postInitSQL }}

      {{- if eq .type "cm" }}
      {{- $cmName := default (print "postgres-postinit-sql-" $glyphDefinition.name) .name }}

      postInitSQLRefs:
        configMapRefs:
          - name: {{ $cmName }}
            key: {{ $cmName }}

      {{- end }}

      {{- end }}

      {{- with $glyphDefinition.postInitApp }}

      {{- if eq .type "cm" }}
      {{- $cmName := default (print "postgres-postinit-app-" $glyphDefinition.name) .name }}

      postInitApplicationSQLRefs:
        configMapRefs:
          - name: {{ $cmName }}
            key: {{ $cmName }}

      {{- end }}

      {{- end }}
  {{- end}}

  {{- with $glyphDefinition.backup }}
  {{- if not (eq (toString .enabled) "false") }}
  plugins:
    - name: barman-cloud.cloudnative-pg.io
      isWALArchiver: {{ eq (toString .walArchiver) "true" }}
      parameters:
        barmanObjectName: {{ required "postgresql.instance: backup.barmanObjectName is required" .barmanObjectName }}
  {{- end }}
  {{- end }}

  storage:
    {{- if $glyphDefinition.storage }}
    {{- with $glyphDefinition.storage.storageClass }}
    storageClass: {{ . }}
    {{- end}}
    size: {{ default "1Gi" $glyphDefinition.storage.size }}
    {{- else }}
    size: 1Gi
    {{- end }}

  {{- with $glyphDefinition.resources }}
  resources:
    {{- toYaml . | nindent 4 }}
  {{- end }}

  {{- with $glyphDefinition.affinity }}
  affinity:
    {{- toYaml . | nindent 4 }}
  {{- end }}

  {{- with $glyphDefinition.postgresql }}
  postgresql:
    {{- toYaml . | nindent 4 }}
  {{- end }}

{{/* Create ConfigMaps for postInitSQL if needed */}}
{{- with $glyphDefinition.postInitSQL }}
{{- if and (eq .type "cm") (eq .create true) }}
{{- $cmName := default (print "postgres-postinit-sql-" $glyphDefinition.name) .name }}
{{- $defaultValues := dict "name" $cmName "definition" (dict "content" .content "contentType" "file") }}
{{- include "summon.configMap" ( list $root $defaultValues ) }}
{{- end}}
{{- end}}

{{/* Create ConfigMaps for postInitApp if needed */}}
{{- with $glyphDefinition.postInitApp }}
{{- if and (eq .type "cm") (eq .create true) }}
{{- $cmName := default (print "postgres-postinit-app-" $glyphDefinition.name) .name }}
{{- $defaultValues := dict "name" $cmName "definition" (dict "content" .content "contentType" "file") }}
{{- include "summon.configMap" ( list $root $defaultValues ) }}
{{- end}}
{{- end}}

{{- end}}
