{{/*Runik Platform
Copyright (C) 2025 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

netbird.exitNode is the safe, reusable exit-node abstraction. It emits:
- one NetBirdRoute for 0.0.0.0/0 with masquerade and explicit distribution/ACL
  groups; and
- one NetBirdPolicy granting the required ICMP access from those source groups
  to the routing-peer groups, optionally gated by posture checks.

It intentionally requires routing-peer groups rather than a lone peer because
NetBird policies target groups and the group model supports HA without changing
the glyph contract. DNS for full-tunnel clients remains a separate
nameserverGroup concern.
*/}}
{{- define "netbird.exitNode" }}
{{- $root := index . 0 -}}
{{- $definition := index . 1 -}}
{{- $sourceRefs := get (include "netbird.resolveRefs" (list $root (default (list) $definition.sourceGroupRefs) (default (dict) $definition.sourceGroupsSelector) "netbird-group" "netbird.exitNode source groups") | fromJson) "refs" -}}
{{- $routerRefs := get (include "netbird.resolveRefs" (list $root (default (list) $definition.routingPeerGroupRefs) (default (dict) $definition.routingPeerGroupsSelector) "netbird-group" "netbird.exitNode routing peer groups") | fromJson) "refs" -}}
{{- $postureRefs := get (include "netbird.resolveRefs" (list $root (default (list) $definition.sourcePostureCheckRefs) (default (dict) $definition.sourcePostureChecksSelector) "netbird-posture-check" "netbird.exitNode source posture checks") | fromJson) "refs" -}}
{{- if not $sourceRefs -}}{{- fail "netbird.exitNode: at least one source group is required" -}}{{- end -}}
{{- if not $routerRefs -}}{{- fail "netbird.exitNode: at least one routing-peer group is required" -}}{{- end -}}
{{- $autoApply := false -}}
{{- if hasKey $definition "autoApply" -}}{{- $autoApply = $definition.autoApply -}}{{- end }}
{{- $networkId := default $definition.name $definition.networkId -}}
{{- if gt (len $networkId) 40 -}}{{- fail "netbird.exitNode: networkId must be at most 40 characters" -}}{{- end -}}
{{- $policyResourceName := printf "%s-peer-access" $definition.name -}}
{{- if gt (len $policyResourceName) 63 -}}{{- fail "netbird.exitNode: glyph name must be at most 51 characters so the generated policy name is valid" -}}{{- end }}
---
apiVersion: netbird.io/v1alpha1
kind: NetBirdRoute
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
  description: {{ default (printf "Exit node %s" $definition.name) $definition.description | quote }}
  networkId: {{ $networkId | quote }}
  network: "0.0.0.0/0"
  peerGroupRefs:
    {{- range $ref := $routerRefs }}
    - {{ $ref | quote }}
    {{- end }}
  groupRefs:
    {{- range $ref := $sourceRefs }}
    - {{ $ref | quote }}
    {{- end }}
  accessControlGroupRefs:
    {{- range $ref := $sourceRefs }}
    - {{ $ref | quote }}
    {{- end }}
  enabled: {{ if hasKey $definition "enabled" }}{{ $definition.enabled }}{{ else }}true{{ end }}
  masquerade: true
  metric: {{ if hasKey $definition "metric" }}{{ $definition.metric }}{{ else }}9999{{ end }}
  keepRoute: {{ if hasKey $definition "keepRoute" }}{{ $definition.keepRoute }}{{ else }}false{{ end }}
  skipAutoApply: {{ not $autoApply }}
---
apiVersion: netbird.io/v1alpha1
kind: NetBirdPolicy
metadata:
  name: {{ $policyResourceName }}
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
  name: {{ printf "%s-peer-access" (default $definition.name $definition.nbName) | quote }}
  description: {{ default (printf "Permit clients to reach exit-node peers for %s" $definition.name) $definition.policyDescription | quote }}
  enabled: {{ if hasKey $definition "enabled" }}{{ $definition.enabled }}{{ else }}true{{ end }}
  state: "present"
  sourceGroupRefs:
    {{- range $ref := $sourceRefs }}
    - {{ $ref | quote }}
    {{- end }}
  destinationGroupRefs:
    {{- range $ref := $routerRefs }}
    - {{ $ref | quote }}
    {{- end }}
  {{- if $postureRefs }}
  sourcePostureCheckRefs:
    {{- range $ref := $postureRefs }}
    - {{ $ref | quote }}
    {{- end }}
  {{- end }}
  rules:
    - name: icmp
      enabled: true
      action: accept
      bidirectional: false
      protocol: icmp
{{- end }}
