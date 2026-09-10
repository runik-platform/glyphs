{{/*
Deprecated template aliases for spells using the legacy certManager key.
Implementations live exclusively in the cert-manager chart.
*/}}
{{- define "certManager.certificate" -}}
{{- include "cert-manager.certificate" . -}}
{{- end -}}

{{- define "certManager.clientCertificate" -}}
{{- include "cert-manager.clientCertificate" . -}}
{{- end -}}

{{- define "certManager.clusterIssuer" -}}
{{- include "cert-manager.clusterIssuer" . -}}
{{- end -}}

{{- define "certManager.dnsEndpoint" -}}
{{- include "cert-manager.dnsEndpoint" . -}}
{{- end -}}

{{- define "certManager.dnsEndpointSourced" -}}
{{- include "cert-manager.dnsEndpointSourced" . -}}
{{- end -}}
