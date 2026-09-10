{{/*Runik Platform
Copyright (C) 2026 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

mongodb.user renders a MongoDBUser backed by an exact Secret reference. For the
normal Runik path it also composes a stable Vault RandomSecret + VaultSecret;
set credentials.generate=false to reference a Secret managed by another system.
The password changes only when that external Secret changes and
credentialsRevision is advanced deliberately.
*/}}
{{- define "mongodb.user" -}}
{{- $root := index . 0 -}}
{{- $definition := index . 1 -}}
{{- $userName := include "mongodb.safeName" (default (include "common.name" $root) $definition.name) -}}
{{- $namespace := default $root.Release.Namespace $definition.namespace -}}
{{- $databaseRef := deepCopy (default dict $definition.databaseRef) -}}
{{- $databaseRefName := required "mongodb.user: databaseRef.name is required" $databaseRef.name -}}
{{- $databaseName := default $databaseRefName $definition.databaseName -}}
{{- $access := include "mongodb.access" $definition.access -}}
{{- $credentials := deepCopy (default dict $definition.credentials) -}}
{{- $generate := true -}}
{{- if hasKey $credentials "generate" }}{{- $generate = $credentials.generate -}}{{- end -}}
{{- $secretRef := deepCopy (default dict $definition.credentialsSecretRef) -}}
{{- $secretName := default $userName $secretRef.name -}}
{{- $usernameKey := default "USERNAME" $secretRef.usernameKey -}}
{{- $passwordKey := default "PASSWORD" $secretRef.passwordKey -}}
{{- $sourceName := $secretName -}}
{{- with $credentials.generationRevision }}{{- $sourceName = include "mongodb.safeName" (printf "%s-%s" $secretName .) -}}{{- end -}}

{{- if $generate -}}
{{- $mongo := include "mongodb.resolveCluster" (list $root (default dict $definition.cluster)) | fromJson -}}
{{- $vaults := get (include "runic-system.runic-indexer" (list $root.Values.lexicon (merge (default dict $credentials.vaultSelector) (dict "provider" "operator")) "secret-store" $root.Values.chapter.name) | fromJson) "results" -}}
{{- if not $vaults }}{{- fail "mongodb.user: credentials.generate=true requires an operator-backed secret-store; set credentials.generate=false to use an existing Secret" -}}{{- end -}}
{{- $staticData := dict $usernameKey (default $userName $credentials.username) -}}
{{- $templateData := dict
      "HOST" $mongo.host
      "PORT" $mongo.port
      "DATABASE" $databaseName
      "AUTH_DATABASE" $databaseName
      "REPLICA_SET" (ternary "" $mongo.replset $mongo.sharded)
      "TLS" (toString $mongo.tls) -}}
{{- with $credentials.templateData }}{{- $_ := mergeOverwrite $templateData (deepCopy .) -}}{{- end -}}
{{ include "vault.secret" (list $root (dict
    "name" $sourceName
    "nameOverwrite" $secretName
    "namespace" $namespace
    "serviceAccount" (default (include "common.name" $root) $credentials.serviceAccount)
    "customRole" $credentials.customRole
    "secretType" (default "Opaque" $credentials.secretType)
    "path" $credentials.path
    "format" "plain"
    "staticData" $staticData
    "templateData" $templateData
    "random" true
    "randomKey" $passwordKey
    "passPolicyName" (default "short-policy" $credentials.passPolicyName)
    "kvSecretRetainPolicy" (default "Retain" $credentials.kvSecretRetainPolicy)
    "selector" $credentials.vaultSelector
)) }}
{{- end }}
{{ printf "\n" }}
---
apiVersion: mongodb.example.io/v1alpha1
kind: MongoDBUser
metadata:
  name: {{ $userName }}
  namespace: {{ $namespace }}
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
  databaseRef:
    name: {{ $databaseRefName }}
  credentialsSecretRef:
    name: {{ $secretName }}
    usernameKey: {{ $usernameKey }}
    passwordKey: {{ $passwordKey }}
  access: {{ $access }}
  credentialsRevision: {{ default "1" $definition.credentialsRevision | quote }}
  deletionPolicy: {{ default "Delete" $definition.deletionPolicy }}
{{- printf "\n" -}}
{{- end -}}
