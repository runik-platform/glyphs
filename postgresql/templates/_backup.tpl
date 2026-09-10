{{/*Runik Platform
Copyright (C) 2025 laaledesiempre@disroot.org
SPDX-License-Identifier: AGPL-3.0-only

postgresql.backup — Renders a single CloudNativePG Backup CRD (one-shot).

Backup is a one-time trigger; the operator runs the backup once and the
resource records its result (.status.phase: running|completed|failed).
Useful for ad-hoc snapshots before risky migrations or manual recovery
points. For recurring backups use postgresql.scheduledBackup instead.

Fields:
  name:                          # Backup name (required)
  cluster:                       # Cluster name to back up (required)
  method: plugin                 # default; also "volumeSnapshot"
  target: primary                # default; also "prefer-standby"
*/}}

{{- define "postgresql.backup" }}
{{- $root := index . 0 -}}
{{- $glyphDefinition := index . 1}}

---
apiVersion: postgresql.cnpg.io/v1
kind: Backup
metadata:
  name: {{ required "postgresql.backup: name is required" $glyphDefinition.name }}
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
  cluster:
    name: {{ required "postgresql.backup: cluster is required" $glyphDefinition.cluster }}
  method: {{ default "plugin" $glyphDefinition.method }}
  {{- if eq (default "plugin" $glyphDefinition.method) "plugin" }}
  pluginConfiguration:
    name: barman-cloud.cloudnative-pg.io
  {{- end }}
  {{- with $glyphDefinition.target }}
  target: {{ . }}
  {{- end }}

{{- end}}
