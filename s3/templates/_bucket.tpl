{{/*Runik Platform
Copyright (C) 2023 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

s3.bucket - Creates dual-namespace VaultSecrets for S3 bucket access

Creates:
1. VaultSecret in app namespace (for app consumption via secrets.contentType:env)
2. VaultSecret in provider namespace (for aggregation into S3 config)

Both secrets read the same named credential keys under the consumer Vault path.
instance opts into isolated physical names; the YAML key remains logical.
*/}}

{{- define "s3.bucket.impl" -}}
{{- $root := index . 0 -}}
{{- $glyphDefinition := index . 1 -}}
{{- if hasKey $glyphDefinition "instance" -}}{{- $glyphDefinition = deepCopy $glyphDefinition -}}{{- end -}}
{{- $s3Providers := include "s3.bucket.providers" (list $root $glyphDefinition) | fromJsonArray }}

{{- range $s3Provider := $s3Providers }}

{{- /* Generate identity name and defaults */}}
{{- $names := include "s3.bucket.names" (list $root $glyphDefinition $s3Provider) | fromJson }}
{{- $consumerNamespace := $names.namespace }}
{{- $pathOptions := dict "namespace" $consumerNamespace }}
{{- $identityName := $names.identity }}
{{- $bucketName := $names.bucket }}
{{- $permissions := default (list "Admin") $glyphDefinition.permissions }}

{{- /* Bucket patterns: exact bucket by default, pattern:true adds -*, pattern:[list] uses custom patterns */}}
{{- $bucketPatterns := list }}
{{- if $glyphDefinition.pattern }}
  {{- if eq (kindOf $glyphDefinition.pattern) "bool" }}
    {{- /* pattern: true -> bucket-* */}}
    {{- $bucketPatterns = list (printf "%s-*" $bucketName) }}
  {{- else if eq (kindOf $glyphDefinition.pattern) "slice" }}
    {{- /* pattern: ["prefix-*", "*-suffix"] -> custom patterns */}}
    {{- $bucketPatterns = $glyphDefinition.pattern }}
  {{- end }}
{{- else }}
  {{- /* Default: exact bucket name */}}
  {{- $bucketPatterns = list $bucketName }}
{{- end }}

{{- /* Generate unique identity name for vault secret */}}
{{- $secretName := $names.credentials }}

{{- /* 1. VaultSecret in APP NAMESPACE (for app consumption) */}}
{{- /* Legacy skips a shared namespace. Opt-in has distinct CR/output names. */}}
{{- if or (hasKey $glyphDefinition "instance") (ne $consumerNamespace $s3Provider.namespace) }}
{{- /* Build dict explicitly to ensure secretName is used */}}
{{- $s3Labels := merge (default dict $glyphDefinition.labels) (dict
  "runik.ing/s3-identity" "true"
  "runik.ing/s3-provider" $s3Provider.name
  "runik.ing/identity-name" $identityName
) }}
{{- if and (hasKey $glyphDefinition "instance") (eq $consumerNamespace $s3Provider.namespace) }}
{{- /* Only the provider-facing Secret may enter the aggregator in this namespace. */}}
{{- $_ := set $s3Labels "runik.ing/s3-identity" "false" }}
{{- end }}
{{ include "vault.secret" (list $root (dict
  "name" $secretName
  "nameOverwrite" $names.appSecret
  "namespace" $consumerNamespace
  "pathOptions" $pathOptions
  "format" "env"
  "randomKeys" (list "AWS_ACCESS_KEY_ID" "AWS_SECRET_ACCESS_KEY")
  "staticData" (dict
    "AWS_ENDPOINT" $s3Provider.endpoint
    "AWS_ENDPOINTS" $s3Provider.endpoint
    "AWS_REGION" (default "us-east-1" $s3Provider.region)
    "S3_BUCKET" $bucketName
  )
  "labels" $s3Labels
  "selector" $glyphDefinition.selector
  "passPolicyName" (default "short-policy" $glyphDefinition.passPolicyName)
  "refreshPeriod" $glyphDefinition.refreshPeriod
  "serviceAccount" $glyphDefinition.serviceAccount
  "customRole" (default $glyphDefinition.role $glyphDefinition.customRole)
)) }}
{{- end }}

{{- /* 2. VaultSecret in PROVIDER NAMESPACE (for aggregation) */}}
{{- /* Clean dict with provider credentials only - no app glyphDefinition */}}
{{- /* Reads from same vault paths where RandomSecrets write (separate secrets per key) */}}
{{- /* Logical consumer namespace is resolved by common against each selected Vault store */}}
{{- /* public is bucket metadata, not a secret -> rides as a k8s label (string,
   only present when true), not in the secret data. The aggregator reads it off
   the secret's metadata.labels. */}}
{{- $labels := dict "runik.ing/s3-identity" "true" "runik.ing/s3-provider" $s3Provider.name "runik.ing/source-namespace" $consumerNamespace "runik.ing/identity-name" $identityName }}
{{- if $glyphDefinition.public }}{{- $_ := set $labels "runik.ing/s3-public" "true" }}{{- end }}
{{ include "vault.secret" (list $root (dict
  "name" $secretName
  "nameOverwrite" $identityName
  "namespace" $s3Provider.namespace
  "format" "plain"
  "random" false
  "randomKeys" (list "AWS_ACCESS_KEY_ID" "AWS_SECRET_ACCESS_KEY")
  "pathOptions" $pathOptions
  "staticData" (dict
    "IDENTITY_NAME" $identityName
    "PERMISSIONS" (join "," $permissions)
    "BUCKETS" (join "," $bucketPatterns)
  )
  "labels" $labels
  "serviceAccount" $s3Provider.serviceAccount
  "role" $s3Provider.role
) $names.providerResource) }}

{{- end }}
{{- end }}
