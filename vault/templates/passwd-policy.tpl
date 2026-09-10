{{/*Runik Platform
Copyright (C) 2023 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only
TODO hardcoded all of it
*/}}

{{- define "vault.passwordPolicy" }}
{{- $root := index . 0 -}}
{{- $glyphDefinition := index . 1 }}
{{- $vaultServer := get (include "runic-system.runic-indexer" (list $root.Values.lexicon (merge (default dict $glyphDefinition.selector) (dict "provider" "operator")) "secret-store" $root.Values.chapter.name ) | fromJson) "results" }}
{{- range $vaultConf := $vaultServer }}
---
apiVersion: redhatcop.redhat.io/v1alpha1
kind: PasswordPolicy
metadata:
  name: simple-password-policy
  labels:
    {{- include "common.all.labels" $root | nindent 4 }}
    {{- with $glyphDefinition.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  annotations:
    {{- include "common.annotations" $root | nindent 4 }}
    argocd.argoproj.io/sync-wave: "5"
    {{- with $glyphDefinition.annotations }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  {{- include "vault.connect" (list $root $vaultConf "") | nindent 2 }}
  passwordPolicy: |
    length = 36
    rule "charset" {
      charset = "abcdefghijklmnopqrstuvwxyz"
      min-chars = 3
    }
    rule "charset" {
      charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
      min-chars = 3
    }
    rule "charset" {
      charset = "0123456789"
      min-chars = 3
    }
    rule "charset" {
      charset = "#%~^_-+=.,:?"
      min-chars = 3
    }
{{- end -}}
{{- end -}}