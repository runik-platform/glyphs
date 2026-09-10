{{/*Runik Platform
Copyright (C) 2026 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only
*/}}
{{- define "mongodb.restore" -}}
{{- $root := index . 0 -}}
{{- $definition := index . 1 -}}
{{- $mongo := include "mongodb.resolveCluster" (list $root (default dict $definition.cluster)) | fromJson -}}
{{- if and (not $definition.backupName) (not $definition.backupSource) -}}
  {{- fail "mongodb.restore: backupName or backupSource is required" -}}
{{- end -}}
{{ printf "\n---\n" }}
apiVersion: psmdb.percona.com/v1
kind: PerconaServerMongoDBRestore
metadata:
  name: {{ required "mongodb.restore: name is required" $definition.name }}
  namespace: {{ default $mongo.namespace $definition.namespace }}
  labels:
    {{- include "common.all.labels" $root | nindent 4 }}
    {{- with $definition.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  clusterName: {{ $mongo.clusterName }}
  {{- with $definition.backupName }}
  backupName: {{ . }}
  {{- end }}
  {{- with $definition.backupSource }}
  backupSource:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $definition.pitr }}
  pitr:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $definition.selective }}
  selective:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $definition.replsetRemapping }}
  replsetRemapping:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end -}}
