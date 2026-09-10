{{/*Runik Platform
Copyright (C) 2025 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

netbird.peer creates a NetBirdPeer (netbird.io/v1alpha1) — declarative peer
settings (login expiration, ssh, approval, ...) against a peer's hostname.

Required:
- $definition.name (auto-injected)
- $definition.peerRef (peer hostname) — NOT resolved via lexicon because this
  glyph *is* the lexicon publisher for peers.

Optional:
- $definition.approvalRequired
- $definition.inactivityExpirationEnabled
- $definition.loginExpirationEnabled
- $definition.sshEnabled

Lifecycle warning: deleting the rendered NetBirdPeer CR unregisters the peer
from the NetBird account. Use this glyph only when that ownership model is
intentional; a lexicon-only netbird-peer entry is enough for discovery.

Lexicon: author a lexicon entry with `type: netbird-peer` (name = peerRef) to
make this peer discoverable by networkRouter/route via selector.

Usage: {{- include "netbird.peer" (list $root $glyph) }}
*/}}
{{- define "netbird.peer" }}
{{- $root := index . 0 -}}
{{- $definition := index . 1 }}
---
apiVersion: netbird.io/v1alpha1
kind: NetBirdPeer
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
  peerRef: {{ required "netbird.peer: peerRef (peer hostname) is required" $definition.peerRef | quote }}
  {{- if hasKey $definition "approvalRequired" }}
  approvalRequired: {{ $definition.approvalRequired }}
  {{- end }}
  {{- if hasKey $definition "inactivityExpirationEnabled" }}
  inactivityExpirationEnabled: {{ $definition.inactivityExpirationEnabled }}
  {{- end }}
  {{- if hasKey $definition "loginExpirationEnabled" }}
  loginExpirationEnabled: {{ $definition.loginExpirationEnabled }}
  {{- end }}
  {{- if hasKey $definition "sshEnabled" }}
  sshEnabled: {{ $definition.sshEnabled }}
  {{- end }}
{{- end }}
