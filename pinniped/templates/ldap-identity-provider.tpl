{{/*Runik Platform
Copyright (C) 2026 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only
*/}}
{{- define "pinniped.ldapIdentityProvider" -}}
{{- $root := index . 0 -}}
{{- $glyph := index . 1 -}}
{{ include "pinniped.nativeResource" (list $root $glyph "idp.supervisor.pinniped.dev/v1alpha1" "LDAPIdentityProvider" true "pinniped-supervisor" "pinniped.ldapIdentityProvider") }}
{{- end }}
