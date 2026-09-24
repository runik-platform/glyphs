{{/*Runik Platform
Copyright (C) 2026 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only
*/}}
{{- define "pinniped.jwtAuthenticator" -}}
{{- $root := index . 0 -}}
{{- $glyph := index . 1 -}}
{{ include "pinniped.nativeResource" (list $root $glyph "authentication.concierge.pinniped.dev/v1alpha1" "JWTAuthenticator" false "" "pinniped.jwtAuthenticator") }}
{{- end }}
