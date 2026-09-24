{{/*Runik Platform
Copyright (C) 2026 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only
*/}}
{{- define "pinniped.oidcClient" -}}
{{- $root := index . 0 -}}
{{- $glyph := index . 1 -}}
{{ include "pinniped.nativeResource" (list $root $glyph "config.supervisor.pinniped.dev/v1alpha1" "OIDCClient" true "pinniped-supervisor" "pinniped.oidcClient") }}
{{- end }}
