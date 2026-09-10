{{/*Runik Platform
Copyright (C) 2025 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

netbird.policy creates a complementary NetBirdPolicy (netbird.io/v1alpha1).
It manages full NetBird access policies, including multiple rules, ICMP, port
ranges and source posture checks.

Exact refs and runicIndexer selectors can be combined:
- sourceGroupRefs + sourceGroupsSelector       (netbird-group)
- destinationGroupRefs + destinationGroupsSelector (netbird-group)
- sourcePostureCheckRefs + sourcePostureChecksSelector
  (netbird-posture-check)

When state is absent only the NetBird-side name and state are rendered. This
allows a CR to continuously enforce the absence of a pre-existing policy such
as Default without depending on groups or posture checks.
*/}}
{{- define "netbird.policy" }}
{{- $root := index . 0 -}}
{{- $definition := index . 1 -}}
{{- $state := default "present" $definition.state -}}
{{- $sourceRefs := list -}}
{{- $destinationRefs := list -}}
{{- $postureRefs := list -}}
{{- if eq $state "present" -}}
  {{- $sourceRefs = get (include "netbird.resolveRefs" (list $root (default (list) $definition.sourceGroupRefs) (default (dict) $definition.sourceGroupsSelector) "netbird-group" "netbird.policy source groups") | fromJson) "refs" -}}
  {{- $destinationRefs = get (include "netbird.resolveRefs" (list $root (default (list) $definition.destinationGroupRefs) (default (dict) $definition.destinationGroupsSelector) "netbird-group" "netbird.policy destination groups") | fromJson) "refs" -}}
  {{- $postureRefs = get (include "netbird.resolveRefs" (list $root (default (list) $definition.sourcePostureCheckRefs) (default (dict) $definition.sourcePostureChecksSelector) "netbird-posture-check" "netbird.policy source posture checks") | fromJson) "refs" -}}
  {{- if not $sourceRefs -}}{{- fail "netbird.policy: at least one source group is required when state=present" -}}{{- end -}}
  {{- if not $destinationRefs -}}{{- fail "netbird.policy: at least one destination group is required when state=present" -}}{{- end -}}
  {{- $_ := required "netbird.policy: rules are required when state=present" $definition.rules -}}
{{- end }}
---
apiVersion: netbird.io/v1alpha1
kind: NetBirdPolicy
metadata:
  name: {{ $definition.name }}
  {{- with $definition.namespace }}
  namespace: {{ . }}
  {{- end }}
  labels:
    {{- include "common.all.labels" $root | nindent 4 }}
    {{- with $definition.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- with $definition.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  name: {{ default $definition.name $definition.nbName | quote }}
  state: {{ $state | quote }}
  {{- if eq $state "present" }}
  description: {{ default "" $definition.description | quote }}
  enabled: {{ if hasKey $definition "enabled" }}{{ $definition.enabled }}{{ else }}true{{ end }}
  sourceGroupRefs:
    {{- range $ref := $sourceRefs }}
    - {{ $ref | quote }}
    {{- end }}
  destinationGroupRefs:
    {{- range $ref := $destinationRefs }}
    - {{ $ref | quote }}
    {{- end }}
  {{- if $postureRefs }}
  sourcePostureCheckRefs:
    {{- range $ref := $postureRefs }}
    - {{ $ref | quote }}
    {{- end }}
  {{- end }}
  rules:
    {{- toYaml $definition.rules | nindent 4 }}
  {{- end }}
{{- end }}
