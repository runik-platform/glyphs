{{/*Runik Platform
Copyright (C) 2023 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

name defines a template for the name of the chart. It should be used for the `app` label. 
This is common practice in many Kubernetes manifests, and is not Helm-specific.

The prevailing wisdom is that names should only contain a-z, 0-9 plus dot (.) and dash (-), and should
not exceed 63 characters.

Legacy workload identity: Values.name (or Release.Name), with the local
Values.namePrefix and Values.nameSuffix, lowercased and truncated to 54
characters. nameOverride and global prefixes/suffixes are not supported.
Keep this behavior stable for existing names and selectors. For glyph names
and resource-specific affixes, use common.glyph.name.

Usage: 'name: "{{- template "common.name" . -}}"'
*/ -}}
{{- define "common.name"}}
  {{- $base := default .Release.Name .Values.name -}}
  {{- $pre := default "" .Values.namePrefix -}}
  {{- $suf := default "" .Values.nameSuffix -}}
  {{- $name := print $pre $base $suf -}}
  {{- $name | lower | trunc 54 | trimSuffix "-" -}}
{{- end -}}


{{- define "common.serviceAccountName" -}}
{{- $serviceAccount := default dict .Values.serviceAccount -}}
{{- default (include "common.name" .) $serviceAccount.name -}}
{{- end -}}

{{/*
common.storage.resourceName — single source of truth for the Kubernetes
resource name derived from a configMap / secret / volume entry.

Rule: prefer the optional `.name` field inside the definition over the YAML
map key, and sanitize dots to dashes for DNS-1123 compliance.

Parameters (list):
  0: $mapKey     — the YAML map key (string)
  1: $definition — the entry value (map). Uses .name if set.

Usage:
  {{- $rn := include "common.storage.resourceName" (list $name $content) }}
*/}}
{{- define "common.storage.resourceName" -}}
{{- $mapKey := index . 0 -}}
{{- $definition := index . 1 -}}
{{- default $mapKey $definition.name | replace "." "-" -}}
{{- end -}}
