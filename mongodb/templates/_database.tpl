{{/*Runik Platform
Copyright (C) 2026 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

mongodb.database is the application-facing meta glyph. It renders a logical
MongoDBDatabase and, by default, one MongoDBUser with readWrite access. MongoDB
materializes collections lazily when the application first writes data.

Set defaultUser.enabled=false when only the database claim is wanted. Additional
identities are rendered independently with mongodb.user.
*/}}
{{- define "mongodb.databaseResource" -}}
{{- $root := index . 0 -}}
{{- $definition := index . 1 -}}
{{- $namespace := default $root.Release.Namespace $definition.namespace -}}
---
apiVersion: mongodb.example.io/v1alpha1
kind: MongoDBDatabase
metadata:
  name: {{ include "mongodb.safeName" (required "mongodb.database: name is required" $definition.name) }}
  namespace: {{ $namespace }}
  labels:
    {{- include "common.all.labels" $root | nindent 4 }}
    {{- with $definition.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- $annotations := deepCopy (default dict $definition.annotations) -}}
  {{- if $definition.allowDrop }}{{- $_ := set $annotations "mongodb.example.io/allow-drop-database" "true" -}}{{- end }}
  {{- with $annotations }}
  annotations:
    {{- include "common.annotations" $root | nindent 4 }}
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  engineRef:
    name: {{ required "mongodb.database: engineRef.name is required" $definition.engineName }}
  databaseName: {{ required "mongodb.database: databaseName is required" $definition.databaseName | quote }}
  deletionPolicy: {{ default "Retain" $definition.deletionPolicy }}
{{- printf "\n" -}}
{{- end -}}

{{- define "mongodb.database" -}}
{{- $root := index . 0 -}}
{{- $definition := index . 1 -}}
{{- $mongo := include "mongodb.resolveCluster" (list $root (default dict $definition.cluster)) | fromJson -}}
{{- $resourceName := include "mongodb.safeName" (default (include "common.name" $root) $definition.name) -}}
{{- $databaseName := default $resourceName $definition.databaseName -}}
{{- $namespace := default $root.Release.Namespace $definition.namespace -}}

{{ include "mongodb.databaseResource" (list $root (dict
    "name" $resourceName
    "namespace" $namespace
    "engineName" $mongo.engineName
    "databaseName" $databaseName
    "deletionPolicy" $definition.deletionPolicy
    "allowDrop" $definition.allowDrop
    "labels" $definition.labels
    "annotations" $definition.annotations
)) }}

{{- $defaultUser := deepCopy (default dict $definition.defaultUser) -}}
{{- $userEnabled := true -}}
{{- if hasKey $defaultUser "enabled" }}{{- $userEnabled = $defaultUser.enabled -}}{{- end -}}
{{- if $userEnabled -}}
{{- $credentials := mergeOverwrite (deepCopy (default dict $definition.credentials)) (deepCopy (default dict $defaultUser.credentials)) -}}
{{ include "mongodb.user" (list $root (dict
    "name" (default $resourceName $defaultUser.name)
    "namespace" $namespace
    "databaseRef" (dict "name" $resourceName)
    "databaseName" $databaseName
    "cluster" $definition.cluster
    "access" (default $definition.access $defaultUser.access)
    "credentialsSecretRef" (default $definition.credentialsSecretRef $defaultUser.credentialsSecretRef)
    "credentials" $credentials
    "credentialsRevision" (default $definition.credentialsRevision $defaultUser.credentialsRevision)
    "deletionPolicy" (default $definition.userDeletionPolicy $defaultUser.deletionPolicy)
    "labels" $defaultUser.labels
    "annotations" $defaultUser.annotations
)) }}
{{- end -}}
{{- end -}}
