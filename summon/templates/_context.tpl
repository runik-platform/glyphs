{{/*Runik Platform
Copyright (C) 2023 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only
*/}}

{{/*
summon.getName gets the appropriate name for summon resources
Supports both direct usage and glyph parameter patterns

Parameters:
- Direct usage: . (root context) 
- Glyph usage: (list $root $glyphDefinition)

Returns: Resource name (glyphDefinition.name takes priority over common.name)
*/}}
{{- define "summon.getName" -}}
{{- if kindIs "slice" . -}}
  {{- $root := index . 0 -}}
  {{- $glyphDefinition := index . 1 -}}
  {{- default (include "common.name" $root) $glyphDefinition.name -}}
{{- else -}}
  {{- include "common.name" . -}}
{{- end -}}
{{- end -}}
