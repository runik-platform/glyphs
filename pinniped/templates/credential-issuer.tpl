{{/*Runik Platform
Copyright (C) 2026 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only
*/}}
{{- define "pinniped.credentialIssuer" -}}
{{- $root := index . 0 -}}
{{- $glyph := index . 1 -}}
{{ include "pinniped.nativeResource" (list $root $glyph "config.concierge.pinniped.dev/v1alpha1" "CredentialIssuer" false "" "pinniped.credentialIssuer") }}
{{- end }}
