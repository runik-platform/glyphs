{{/*Runik Platform
Copyright (C) 2026 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only
*/}}
{{- define "pinniped.activeDirectoryIdentityProvider" -}}
{{- $root := index . 0 -}}
{{- $glyph := index . 1 -}}
{{ include "pinniped.nativeResource" (list $root $glyph "idp.supervisor.pinniped.dev/v1alpha1" "ActiveDirectoryIdentityProvider" true "pinniped-supervisor" "pinniped.activeDirectoryIdentityProvider") }}
{{- end }}
