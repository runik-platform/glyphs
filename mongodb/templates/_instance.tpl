{{/*Runik Platform
Copyright (C) 2026 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

mongodb.instance renders exactly one PerconaServerMongoDB resource. It is the
raw primitive used by mongodb.cluster; callers that use it directly own the
entire atomic spec.roles and spec.users arrays.
*/}}
{{- define "mongodb.instance" -}}
{{- $root := index . 0 -}}
{{- $definition := index . 1 -}}
---
apiVersion: psmdb.percona.com/v1
kind: PerconaServerMongoDB
metadata:
  name: {{ required "mongodb.instance: name is required" $definition.name }}
  {{- with $definition.namespace }}
  namespace: {{ . }}
  {{- end }}
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
  {{- with $definition.finalizers }}
  finalizers:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- toYaml (required "mongodb.instance: spec is required" $definition.spec) | nindent 2 }}
{{- printf "\n" -}}
{{- end -}}
