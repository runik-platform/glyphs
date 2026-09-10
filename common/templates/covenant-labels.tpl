{{/*Runik Platform
Copyright (C) 2023 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only
*/}}

{{/*
Covenant Identity & Access Management Labels
These labels are used for tracking identity and access management resources.
Enable via: .Values.labels.covenant.enabled

These labels support:
- User and member tracking
- Team and organizational structure
- Integration and client identification
- Access control and permissions

Usage in values.yaml:
  labels:
    covenant:
      enabled: true
      team: platform-team
      owner: john.doe@company.com
      department: engineering
      member: john-doe
      organization: my-org
*/}}
{{- define "common.covenant.labels" -}}
{{- if .Values.labels }}
{{- if .Values.labels.covenant }}
{{- if .Values.labels.covenant.enabled }}
{{- with .Values.labels.covenant.team }}
covenant.runik.io/team: {{ . }}
{{- end }}
{{- with .Values.labels.covenant.owner }}
covenant.runik.io/owner: {{ . }}
{{- end }}
{{- with .Values.labels.covenant.department }}
covenant.runik.io/department: {{ . }}
{{- end }}
{{- with .Values.labels.covenant.member }}
covenant.runik.io/member: {{ . }}
{{- end }}
{{- with .Values.labels.covenant.organization }}
covenant.runik.io/organization: {{ . }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
