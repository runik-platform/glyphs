{{/*Runik Platform
Copyright (C) 2026 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

postgresql.objectStore — Renders a barmancloud.cnpg.io/v1 ObjectStore for the
Barman Cloud Plugin (CNPG-I). spec.configuration uses the same schema as the
legacy in-tree spec.backup.barmanObjectStore (removed in CNPG 1.30). Note that
retentionPolicy lives HERE in plugin mode — it moves off the Cluster CRD.

Rendered by the postgresql.cluster meta (one per cluster with backups, one
more for a restore source); not dispatched directly from spells.

Fields:
  name:                # ObjectStore name (required) — referenced as barmanObjectName
  destinationPath:     # s3://... (required)
  endpointURL:         # object store URL (required)
  s3SecretRef:         # secret holding the S3 credentials (required)
  accessKeyIdKey:      # default AWS_ACCESS_KEY_ID
  secretAccessKeyKey:  # default AWS_SECRET_ACCESS_KEY
  compression:         # wal+data compression, default gzip
  retention:           # optional — renders spec.retentionPolicy
*/}}

{{- define "postgresql.objectStore" }}
{{- $root := index . 0 -}}
{{- $glyphDefinition := index . 1}}
---
apiVersion: barmancloud.cnpg.io/v1
kind: ObjectStore
metadata:
  name: {{ required "postgresql.objectStore: name is required" $glyphDefinition.name }}
  labels:
    {{- include "common.all.labels" $root | nindent 4 }}
spec:
  configuration:
    destinationPath: {{ required "postgresql.objectStore: destinationPath is required" $glyphDefinition.destinationPath | quote }}
    endpointURL: {{ required "postgresql.objectStore: endpointURL is required" $glyphDefinition.endpointURL | quote }}
    s3Credentials:
      accessKeyId:
        name: {{ required "postgresql.objectStore: s3SecretRef is required" $glyphDefinition.s3SecretRef }}
        key: {{ default "AWS_ACCESS_KEY_ID" $glyphDefinition.accessKeyIdKey }}
      secretAccessKey:
        name: {{ $glyphDefinition.s3SecretRef }}
        key: {{ default "AWS_SECRET_ACCESS_KEY" $glyphDefinition.secretAccessKeyKey }}
    wal:
      compression: {{ default "gzip" $glyphDefinition.compression }}
    data:
      compression: {{ default "gzip" $glyphDefinition.compression }}
  {{- with $glyphDefinition.retention }}
  retentionPolicy: {{ . | quote }}
  {{- end }}
{{- end }}
