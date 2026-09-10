{{/*Runik Platform
Copyright (C) 2026 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

mongodb.engine registers one existing MongoDB-compatible server with the
logical operations controller. Credentials and TLS material are references;
this primitive never creates or copies a Secret.
*/}}
{{- define "mongodb.engine" -}}
{{- $root := index . 0 -}}
{{- $definition := index . 1 -}}
---
apiVersion: mongodb.example.io/v1alpha1
kind: MongoDBEngine
metadata:
  name: {{ include "mongodb.safeName" (required "mongodb.engine: name is required" $definition.name) }}
  labels:
    {{- include "common.all.labels" $root | nindent 4 }}
    {{- with $definition.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- with $definition.annotations }}
  annotations:
    {{- include "common.annotations" $root | nindent 4 }}
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  connection:
    {{- toYaml (required "mongodb.engine: connection is required" $definition.connection) | nindent 4 }}
  allowedNamespaces:
    {{- toYaml (required "mongodb.engine: allowedNamespaces is required" $definition.allowedNamespaces) | nindent 4 }}
{{- printf "\n" -}}
{{- end -}}
