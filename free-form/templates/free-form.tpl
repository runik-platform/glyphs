{{/*Runik Platform
Copyright (C) 2023 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only
*/}}
{{- define "free-form.manifest" -}}
{{- $root := index . 0 -}}
{{- $glyphDefinition := index . 1}}
---
{{ toYaml $glyphDefinition.definition }}
{{- end }}
