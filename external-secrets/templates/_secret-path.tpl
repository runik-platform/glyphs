{{/*Runik Platform
Copyright (C) 2026 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only
*/}}
{{/* Resolve the logical path against the selected store before applying the
provider's existing representation. Explicit remote keys bypass this helper. */}}
{{- define "external-secrets.secretPath" -}}
{{- $root := index . 0 -}}
{{- $definition := index . 1 -}}
{{- $store := index . 2 -}}
{{- $provider := default "vault" $store.provider -}}
{{- $options := dict "store" $store -}}
{{- if eq $provider "vault" -}}
  {{- include "vault.secretPath" (list $root $definition $store $options) -}}
{{- else if eq $provider "aws" -}}
  {{- include "aws.secretPath" (list $root $definition $options) -}}
{{- else if eq $provider "gcp" -}}
  {{- include "gcp.secretPath" (list $root $definition $options) -}}
{{- else -}}
  {{- include "common.secretPath" (list $root $definition "" $options) -}}
{{- end -}}
{{- end -}}
