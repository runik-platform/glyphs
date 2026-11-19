{{/*Runik Platform
Copyright (C) 2026 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only
*/}}
{{/* Materialize one CNPG password and publish the same persisted value.
The caller supplies the CNPG namespace; only the optional app copy is elsewhere.
externalSecrets.remoteKey is the complete backend key, never a generated password.
*/}}
{{- define "postgresql.externalCredentials" -}}
{{- $root := index . 0 -}}
{{- $g := index . 1 -}}
{{- $c := default dict $g.credentials -}}
{{- $eso := default dict $c.externalSecrets -}}
{{- $remoteKey := required "postgresql: credentials.externalSecrets.remoteKey is required" $eso.remoteKey -}}
{{- $selector := default dict $eso.selector -}}
{{- $sourceName := required "postgresql.externalCredentials: sourceName is required" $g.sourceName -}}
{{- $sourceNamespace := required "postgresql.externalCredentials: namespace is required" $g.namespace -}}
{{- $annotations := mergeOverwrite (dict "argocd.argoproj.io/sync-wave" "-4") (deepCopy (default dict $c.annotations)) -}}
{{- $data := mergeOverwrite (dict "username" $g.username "password" "{{ .password }}") (deepCopy (default dict $g.staticData)) -}}
{{- $generated := dict
    "name" $sourceName
    "namespace" $sourceNamespace
    "password" $eso.password
    "annotations" $annotations
    "template" (dict "type" "kubernetes.io/basic-auth" "metadata" (dict "labels" (dict "cnpg.io/reload" "true")) "data" $data)
-}}
{{- with $eso.rotationInterval -}}
  {{- $_ := set $generated "refreshInterval" . -}}
{{- end -}}
{{ include "external-secrets.generated-secret" (list $root $generated) }}
{{- $pushName := include "common.glyph.name" (dict "root" $root "glyph" (dict "name" $sourceName) "options" (dict "suffix" "-publish" "normalize" true)) -}}
{{ include "external-secrets.push-secret" (list $root (dict
    "name" $pushName
    "namespace" $sourceNamespace
    "sourceSecret" $sourceName
    "selector" $selector
    "refreshInterval" (default "1m" $eso.pushInterval)
    "updatePolicy" "Replace"
    "deletionPolicy" "None"
    "annotations" (dict "argocd.argoproj.io/sync-wave" "-3")
    "data" (list (dict "match" (dict "remoteRef" (dict "remoteKey" $remoteKey))))
)) }}
{{- $targetNamespace := default $sourceNamespace $g.targetNamespace -}}
{{- $targetName := default $sourceName $g.targetName -}}
{{- if or (ne $sourceNamespace $targetNamespace) (ne $sourceName $targetName) -}}
{{- $consumerSelector := $selector -}}
{{- if hasKey $eso "consumerSelector" -}}
  {{- $consumerSelector = $eso.consumerSelector -}}
{{- end -}}
{{ include "external-secrets.external-secret" (list $root (dict
    "name" $targetName
    "namespace" $targetNamespace
    "selector" $consumerSelector
    "refreshInterval" (default "1m" $eso.refreshInterval)
    "deletionPolicy" "Retain"
    "annotations" (dict "argocd.argoproj.io/sync-wave" "0")
    "template" (dict "type" "kubernetes.io/basic-auth" "data" $data)
    "dataFrom" (list (dict "extract" (dict "key" $remoteKey)))
)) }}
{{- end -}}
{{- end -}}
