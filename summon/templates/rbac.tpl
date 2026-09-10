{{/*Runik Platform
Copyright (C) 2023 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

summon.rbac creates RBAC resources (ClusterRole, ClusterRoleBinding, Role, RoleBinding)
Can be used directly from values or via glyph system.

Direct usage in values.yaml:
  rbac:
    platform-admins:
      type: clusterRoleBinding
      group: /tyl/platform
      clusterRole: cluster-admin

    dev-edit:
      type: roleBinding
      namespace: my-app
      group: /devs
      clusterRole: edit

    custom-role:
      type: clusterRole
      rules:
        - apiGroups: [""]
          resources: [pods]
          verbs: [get, list, watch]

    ns-role:
      type: role
      namespace: my-app
      rules:
        - apiGroups: [""]
          resources: [secrets]
          verbs: [get, list]
*/}}

{{/* ========== ClusterRoleBinding ========== */}}
{{- define "summon.clusterRoleBinding" -}}
{{- $root := index . 0 -}}
{{- $glyph := index . 1 -}}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: {{ $glyph.name }}
  labels:
    {{- include "common.all.labels" $root | nindent 4 }}
subjects:
  {{- if $glyph.group }}
  - kind: Group
    name: {{ $glyph.group }}
    apiGroup: rbac.authorization.k8s.io
  {{- end }}
  {{- range $glyph.groups }}
  - kind: Group
    name: {{ . }}
    apiGroup: rbac.authorization.k8s.io
  {{- end }}
  {{- if $glyph.user }}
  - kind: User
    name: {{ $glyph.user }}
    apiGroup: rbac.authorization.k8s.io
  {{- end }}
  {{- range $glyph.users }}
  - kind: User
    name: {{ . }}
    apiGroup: rbac.authorization.k8s.io
  {{- end }}
  {{- if $glyph.serviceAccount }}
  - kind: ServiceAccount
    name: {{ $glyph.serviceAccount.name }}
    namespace: {{ $glyph.serviceAccount.namespace | default $root.Release.Namespace }}
  {{- end }}
  {{- range $glyph.serviceAccounts }}
  - kind: ServiceAccount
    name: {{ .name }}
    namespace: {{ .namespace | default $root.Release.Namespace }}
  {{- end }}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: {{ $glyph.clusterRole }}
{{- end }}

{{/* ========== ClusterRole ========== */}}
{{- define "summon.clusterRole" -}}
{{- $root := index . 0 -}}
{{- $glyph := index . 1 -}}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: {{ $glyph.name }}
  labels:
    {{- include "common.all.labels" $root | nindent 4 }}
rules:
  {{- toYaml $glyph.rules | nindent 2 }}
{{- end }}

{{/* ========== RoleBinding ========== */}}
{{- define "summon.roleBinding" -}}
{{- $root := index . 0 -}}
{{- $glyph := index . 1 -}}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: {{ $glyph.name }}
  namespace: {{ $glyph.namespace | default $root.Release.Namespace }}
  labels:
    {{- include "common.all.labels" $root | nindent 4 }}
subjects:
  {{- if $glyph.group }}
  - kind: Group
    name: {{ $glyph.group }}
    apiGroup: rbac.authorization.k8s.io
  {{- end }}
  {{- range $glyph.groups }}
  - kind: Group
    name: {{ . }}
    apiGroup: rbac.authorization.k8s.io
  {{- end }}
  {{- if $glyph.user }}
  - kind: User
    name: {{ $glyph.user }}
    apiGroup: rbac.authorization.k8s.io
  {{- end }}
  {{- range $glyph.users }}
  - kind: User
    name: {{ . }}
    apiGroup: rbac.authorization.k8s.io
  {{- end }}
  {{- if $glyph.serviceAccount }}
  - kind: ServiceAccount
    name: {{ $glyph.serviceAccount.name }}
    namespace: {{ $glyph.serviceAccount.namespace | default $root.Release.Namespace }}
  {{- end }}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  {{- if $glyph.clusterRole }}
  kind: ClusterRole
  name: {{ $glyph.clusterRole }}
  {{- else }}
  kind: Role
  name: {{ $glyph.role }}
  {{- end }}
{{- end }}

{{/* ========== Role ========== */}}
{{- define "summon.role" -}}
{{- $root := index . 0 -}}
{{- $glyph := index . 1 -}}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: {{ $glyph.name }}
  namespace: {{ $glyph.namespace | default $root.Release.Namespace }}
  labels:
    {{- include "common.all.labels" $root | nindent 4 }}
rules:
  {{- toYaml $glyph.rules | nindent 2 }}
{{- end }}
