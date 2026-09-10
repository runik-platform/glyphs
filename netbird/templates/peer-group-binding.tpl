{{/*Runik Platform
Copyright (C) 2025 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

netbird.peerGroupBinding creates a complementary NetBirdPeerGroupBinding. The
CR owns one membership edge and preserves every other peer and Network
Resource in the group.

Both the peer and group may be explicit or discovered via runicIndexer. Each
side must resolve exactly one name.
*/}}
{{- define "netbird.peerGroupBinding" }}
{{- $root := index . 0 -}}
{{- $definition := index . 1 -}}
{{- $peerRef := get (include "netbird.singleRef" (list $root $definition.peerRef (default (dict) $definition.peerSelector) "netbird-peer" "netbird.peerGroupBinding peer") | fromJson) "ref" -}}
{{- $groupRef := get (include "netbird.singleRef" (list $root $definition.groupRef (default (dict) $definition.groupSelector) "netbird-group" "netbird.peerGroupBinding group") | fromJson) "ref" }}
---
apiVersion: netbird.io/v1alpha1
kind: NetBirdPeerGroupBinding
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
  peerRef: {{ $peerRef | quote }}
  groupRef: {{ $groupRef | quote }}
{{- end }}
