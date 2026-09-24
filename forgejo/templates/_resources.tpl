{{/*Runik Platform
Copyright (C) 2026 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only
*/}}

{{- define "forgejo.org" -}}
{{- $root := index . 0 -}}{{- $d := index . 1 -}}
{{- $spec := deepCopy (required "forgejo.org: spec is required" $d.spec) -}}
{{- $_ := set $spec "instance" (include "forgejo.ref" (list $root $d.instanceRef (default dict $d.instanceSelector) "forgejo-instance" "forgejo.org instance") | fromJson) -}}
{{ include "forgejo.resource" (list $root $d "Org" $spec) }}
{{- end -}}

{{- define "forgejo.user" -}}
{{- $root := index . 0 -}}{{- $d := index . 1 -}}
{{- $spec := deepCopy (required "forgejo.user: spec is required" $d.spec) -}}
{{- $_ := set $spec "instance" (include "forgejo.ref" (list $root $d.instanceRef (default dict $d.instanceSelector) "forgejo-instance" "forgejo.user instance") | fromJson) -}}
{{ include "forgejo.resource" (list $root $d "User" $spec) }}
{{- end -}}

{{- define "forgejo.repo" -}}
{{- $root := index . 0 -}}{{- $d := index . 1 -}}
{{- $spec := deepCopy (required "forgejo.repo: spec is required" $d.spec) -}}
{{- $hasOrg := or $d.orgRef (hasKey $d "orgSelector") -}}
{{- if or $d.userRef (hasKey $d "userSelector") }}{{- fail "forgejo.repo: user-owned repositories are not supported; configure orgRef or orgSelector" -}}{{- end -}}
{{- if not $hasOrg }}{{- fail "forgejo.repo: configure orgRef or orgSelector" -}}{{- end -}}
{{- $_ := set $spec "org" (include "forgejo.ref" (list $root $d.orgRef (default dict $d.orgSelector) "forgejo-org" "forgejo.repo org") | fromJson) -}}
{{ include "forgejo.resource" (list $root $d "Repo" $spec) }}
{{- end -}}
