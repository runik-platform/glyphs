{{/*Runik Platform
Copyright (C) 2023 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only
*/}}
{{- define "gcp.iamBind" }}
{{- $root := index . 0 -}}
{{- $glyphDefinition := index . 1}}
apiVersion: iam.cnrm.cloud.google.com/v1beta1
kind: IAMPolicyMember
metadata:
  name: {{ default (include "common.name" $root) $glyphDefinition.name }}
  labels:
    {{- include "common.all.labels" $root | nindent 4 }}
    {{- with $glyphDefinition.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- with $glyphDefinition.annotations }}
  annotations:
    {{- include "common.annotations" $root | nindent 4 }}
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  member: {{ $glyphDefinition.member }}
  role: {{ $glyphDefinition.role }}
  resourceRef:
    name: {{ $glyphDefinition.resourceRef }}
    {{- if $glyphDefinition.resourceRefExternal }}
    external: {{ $glyphDefinition.resourceRefExternal }}
    {{- end }}
    {{- if $glyphDefinition.resourceRefApiVersion }}
    apiVersion: {{ $glyphDefinition.resourceRefApiVersion }}
    {{- end }}
    {{- if $glyphDefinition.resourceRefNamespace }}
    namespace: {{ $glyphDefinition.resourceRefNamespace }}
    {{- end }}
    {{- if $glyphDefinition.resourceRefKind }}
    kind: {{ $glyphDefinition.resourceRefKind }}
    {{- end }}
{{- end }}
