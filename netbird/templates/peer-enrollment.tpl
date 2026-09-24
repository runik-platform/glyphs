{{/*Runik Platform
Copyright (C) 2026 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

netbird.peerEnrollment renders exactly one NetBirdPeerEnrollment.

enroll is deliberately local: the referenced workload and temporary Secret
must live beside the CR. adopt never creates a Secret and selects an existing
peer exclusively by immutable NetBird peer ID; hostname, DNS label and serial
number remain assertions.
*/}}
{{- define "netbird.peerEnrollment" -}}
{{- $root := index . 0 -}}
{{- $definition := index . 1 -}}
{{- $_ := include "netbird.requireInstance" (list $root $definition "netbird.peerEnrollment") }}
{{- $mode := required "netbird.peerEnrollment: mode is required" $definition.mode -}}
{{- if not (has $mode (list "enroll" "adopt")) -}}
  {{- fail "netbird.peerEnrollment: mode must be enroll or adopt" -}}
{{- end -}}
{{- $identity := required "netbird.peerEnrollment: peerIdentity is required" $definition.peerIdentity -}}
{{- if not (kindIs "map" $identity) -}}
  {{- fail "netbird.peerEnrollment: peerIdentity must be an object" -}}
{{- end -}}
{{- $peerID := default "" $identity.id -}}
{{- $hostname := default "" $identity.hostname -}}
{{- $workload := default (dict) $definition.workloadRef -}}
{{- $enrollment := default (dict) $definition.enrollment -}}

{{- if eq $mode "enroll" -}}
  {{- if $peerID -}}
    {{- fail "netbird.peerEnrollment: enroll forbids peerIdentity.id; the operator discovers the new immutable ID" -}}
  {{- end -}}
  {{- $_ := required "netbird.peerEnrollment: enroll requires peerIdentity.hostname" $hostname -}}
  {{- if not (kindIs "map" $workload) -}}
    {{- fail "netbird.peerEnrollment: workloadRef must be an object" -}}
  {{- end -}}
  {{- if hasKey $workload "namespace" -}}
    {{- fail "netbird.peerEnrollment: remote enrollment is forbidden; workloadRef cannot set namespace" -}}
  {{- end -}}
  {{- $apiVersion := default "apps/v1" $workload.apiVersion -}}
  {{- if ne $apiVersion "apps/v1" -}}
    {{- fail "netbird.peerEnrollment: workloadRef.apiVersion must be apps/v1" -}}
  {{- end -}}
  {{- $kind := required "netbird.peerEnrollment: enroll requires workloadRef.kind" $workload.kind -}}
  {{- if not (has $kind (list "Deployment" "StatefulSet" "DaemonSet")) -}}
    {{- fail "netbird.peerEnrollment: workloadRef.kind must be Deployment, StatefulSet or DaemonSet" -}}
  {{- end -}}
  {{- $_ := required "netbird.peerEnrollment: enroll requires workloadRef.name" $workload.name -}}
  {{- if not (kindIs "map" $enrollment) -}}
    {{- fail "netbird.peerEnrollment: enrollment must be an object" -}}
  {{- end -}}
  {{- $secretRef := required "netbird.peerEnrollment: enroll requires enrollment.secretRef" $enrollment.secretRef -}}
  {{- if not (kindIs "map" $secretRef) -}}
    {{- fail "netbird.peerEnrollment: enrollment.secretRef must be an object" -}}
  {{- end -}}
  {{- if hasKey $secretRef "namespace" -}}
    {{- fail "netbird.peerEnrollment: remote enrollment is forbidden; enrollment.secretRef cannot set namespace" -}}
  {{- end -}}
  {{- $_ := required "netbird.peerEnrollment: enrollment.secretRef.name is required" $secretRef.name -}}
  {{- $expires := 600 -}}
  {{- if hasKey $enrollment "expiresInSeconds" -}}{{- $expires = int $enrollment.expiresInSeconds -}}{{- end -}}
  {{- if or (lt $expires 60) (gt $expires 3600) -}}
    {{- fail "netbird.peerEnrollment: enrollment.expiresInSeconds must be between 60 and 3600" -}}
  {{- end -}}
  {{- $revision := 0 -}}
  {{- if hasKey $enrollment "replacementRevision" -}}{{- $revision = int $enrollment.replacementRevision -}}{{- end -}}
  {{- if lt $revision 0 -}}
    {{- fail "netbird.peerEnrollment: enrollment.replacementRevision cannot be negative" -}}
  {{- end -}}
{{- else -}}
  {{- $_ := required "netbird.peerEnrollment: adopt requires peerIdentity.id" $peerID -}}
  {{- if $workload -}}
    {{- fail "netbird.peerEnrollment: adopt forbids workloadRef" -}}
  {{- end -}}
  {{- if $enrollment -}}
    {{- fail "netbird.peerEnrollment: adopt forbids enrollment and never creates a Secret" -}}
  {{- end -}}
{{- end -}}

{{- $groups := get (include "netbird.resolveRefs" (list $root (default (list) $definition.groupRefs) (default (dict) $definition.groupsSelector) "netbird-group" "netbird.peerEnrollment groups") | fromJson) "refs" -}}
{{- $settings := default (dict) $definition.settings -}}
{{- if not (kindIs "map" $settings) -}}
  {{- fail "netbird.peerEnrollment: settings must be an object" -}}
{{- end -}}
{{- $ownership := default (dict) $definition.ownership -}}
{{- if not (kindIs "map" $ownership) -}}
  {{- fail "netbird.peerEnrollment: ownership must be an object" -}}
{{- end -}}
{{- $takeOwnership := false -}}
{{- if hasKey $ownership "takeOwnership" -}}{{- $takeOwnership = $ownership.takeOwnership -}}{{- end -}}
{{- $deletionPolicy := default "Retain" $definition.deletionPolicy -}}
{{- if not (has $deletionPolicy (list "Retain" "Delete")) -}}
  {{- fail "netbird.peerEnrollment: deletionPolicy must be Retain or Delete" -}}
{{- end -}}
{{- if and (eq $mode "adopt") (eq $deletionPolicy "Delete") (not $takeOwnership) -}}
  {{- fail "netbird.peerEnrollment: adopted peer deletion requires ownership.takeOwnership=true" -}}
{{- end -}}
{{- $restoreSettings := true -}}
{{- if hasKey $definition "restoreSettingsOnDelete" -}}{{- $restoreSettings = $definition.restoreSettingsOnDelete -}}{{- end -}}
---
apiVersion: netbird.io/v1alpha1
kind: NetBirdPeerEnrollment
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
  mode: {{ $mode | quote }}
  peerIdentity:
    {{- with $peerID }}
    id: {{ . | quote }}
    {{- end }}
    {{- with $hostname }}
    hostname: {{ . | quote }}
    {{- end }}
    {{- with $identity.dnsLabel }}
    dnsLabel: {{ . | quote }}
    {{- end }}
    {{- with $identity.serialNumber }}
    serialNumber: {{ . | quote }}
    {{- end }}
  {{- if eq $mode "enroll" }}
  workloadRef:
    apiVersion: {{ default "apps/v1" $workload.apiVersion | quote }}
    kind: {{ $workload.kind | quote }}
    name: {{ $workload.name | quote }}
  enrollment:
    secretRef:
      name: {{ $enrollment.secretRef.name | quote }}
      key: {{ default "setupKey" $enrollment.secretRef.key | quote }}
    {{- if hasKey $enrollment "expiresInSeconds" }}
    expiresInSeconds: {{ $enrollment.expiresInSeconds }}
    {{- end }}
    {{- if hasKey $enrollment "ephemeral" }}
    ephemeral: {{ $enrollment.ephemeral }}
    {{- end }}
    {{- if hasKey $enrollment "replacementRevision" }}
    replacementRevision: {{ $enrollment.replacementRevision }}
    {{- end }}
  {{- end }}
  {{- if $settings }}
  settings:
    {{- toYaml $settings | nindent 4 }}
  {{- end }}
  {{- if $groups }}
  groupRefs:
    {{- range $group := $groups }}
    - {{ $group | quote }}
    {{- end }}
  {{- end }}
  ownership:
    takeOwnership: {{ $takeOwnership }}
  deletionPolicy: {{ $deletionPolicy | quote }}
  restoreSettingsOnDelete: {{ $restoreSettings }}
{{ end }}
