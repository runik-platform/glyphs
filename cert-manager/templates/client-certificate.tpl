{{/*Runik Platform
Copyright (C) 2026 namenmalkav@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

cert-manager.clientCertificate creates a namespaced client Certificate without
changing the established cert-manager.certificate contract. The issuer can be
resolved from a type=cert-issuer lexicon entry or supplied through issuerRef.
*/}}
{{- define "cert-manager.clientCertificate" -}}
{{- $root := index . 0 -}}
{{- $definition := index . 1 -}}
{{- $issuers := list -}}
{{- if $definition.issuerRef -}}
  {{- $issuers = list $definition.issuerRef -}}
{{- else -}}
  {{- $issuers = get (include "runic-system.runic-indexer" (list $root.Values.lexicon (default dict $definition.selector) "cert-issuer" $root.Values.chapter.name) | fromJson) "results" -}}
{{- end -}}
{{- if not $issuers -}}
  {{- fail "cert-manager.clientCertificate: issuerRef is required when no type=cert-issuer lexicon entry matches selector" -}}
{{- end -}}
{{- range $issuer := $issuers -}}
{{- $issuerName := required "cert-manager.clientCertificate: issuerRef.name or matched cert-issuer name is required" $issuer.name -}}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: {{ default (printf "%s-%s-cert" $definition.name $issuerName) $definition.resourceName }}
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
    {{- include "common.annotations" $root | nindent 4 }}
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  commonName: {{ required "cert-manager.clientCertificate: commonName is required" $definition.commonName }}
  {{- with $definition.dnsNames }}
  dnsNames:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  issuerRef:
    name: {{ $issuerName }}
    kind: {{ default "ClusterIssuer" $issuer.kind }}
    {{- with $issuer.group }}
    group: {{ . }}
    {{- end }}
  secretName: {{ required "cert-manager.clientCertificate: secretName is required" $definition.secretName }}
  usages:
    {{- toYaml (default (list "client auth") $definition.usages) | nindent 4 }}
  {{- with $definition.duration }}
  duration: {{ . }}
  {{- end }}
  {{- with $definition.renewBefore }}
  renewBefore: {{ . }}
  {{- end }}
  {{- with $definition.privateKey }}
  privateKey:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $definition.subject }}
  subject:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $definition.secretTemplate }}
  secretTemplate:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- printf "\n" -}}
{{- end -}}
{{- end -}}
