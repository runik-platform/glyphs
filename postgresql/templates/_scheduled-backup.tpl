{{/*Runik Platform
Copyright (C) 2025 laaledesiempre@disroot.org
SPDX-License-Identifier: AGPL-3.0-only

postgresql.scheduledBackup — Renders a single CloudNativePG ScheduledBackup CRD.

A ScheduledBackup is the cron trigger that creates Backup objects on a
schedule. Retention is NOT a field of ScheduledBackup — with the Barman
Cloud Plugin it lives on the ObjectStore CR (spec.retentionPolicy), shared
by every backup against that store.

CNPG uses Quartz cron syntax (6 fields: seconds minutes hours day month dow).
Examples:
  "0 0 3 ? * *"   - every day at 03:00:00
  "0 0 0 ? * 0"   - every Sunday at midnight

Fields:
  name:                          # ScheduledBackup name (required)
  cluster:                       # Cluster name to back up (required)
  schedule: "0 0 3 * * *"        # Quartz cron (required)
  method: plugin                 # default; also accepts "volumeSnapshot"
  backupOwnerReference: none     # default; also "self" or "cluster"
  target: primary                # default; also "prefer-standby"
  immediate: false               # if true, run once right after creation
  suspend: false                 # if true, pause the schedule
*/}}

{{- define "postgresql.scheduledBackup" }}
{{- $root := index . 0 -}}
{{- $glyphDefinition := index . 1}}

---
apiVersion: postgresql.cnpg.io/v1
kind: ScheduledBackup
metadata:
  name: {{ required "postgresql.scheduledBackup: name is required" $glyphDefinition.name }}
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
  schedule: {{ required "postgresql.scheduledBackup: schedule is required" $glyphDefinition.schedule | quote }}
  cluster:
    name: {{ required "postgresql.scheduledBackup: cluster is required" $glyphDefinition.cluster }}
  method: {{ default "plugin" $glyphDefinition.method }}
  {{- if eq (default "plugin" $glyphDefinition.method) "plugin" }}
  pluginConfiguration:
    name: barman-cloud.cloudnative-pg.io
  {{- end }}
  backupOwnerReference: {{ default "none" $glyphDefinition.backupOwnerReference }}
  {{- with $glyphDefinition.target }}
  target: {{ . }}
  {{- end }}
  {{- if hasKey $glyphDefinition "immediate" }}
  immediate: {{ $glyphDefinition.immediate }}
  {{- end }}
  {{- if hasKey $glyphDefinition "suspend" }}
  suspend: {{ $glyphDefinition.suspend }}
  {{- end }}

{{- end}}
