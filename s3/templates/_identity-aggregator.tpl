{{/*Runik Platform
Copyright (C) 2023 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

s3.identityAggregator - SHARED scaffold for S3 backend infrastructure.

Every S3 backend (seaweed, versity, ...) reconciles the same thing: k8s Secrets
labelled `runik.ing/s3-identity=true` in the provider namespace (emitted by the
`s3.bucket` glyph on the consumer side) into that backend's identity store. The
plumbing is identical across backends:

  1. EventSource  - watches those secrets (argo-events)
  2. ConfigMap    - the aggregator script            <- BACKEND-SPECIFIC
  3. Workflow     - backend reconciliation as one containerSet
  4. Sensor       - triggers that workflow (or the legacy raw Pod)
  5. RBAC         - SA/Role/RoleBinding for event-source + sensor
  6. SA + Role    - for the workflow pod               <- rules are BACKEND-SPECIFIC
  7. prolicy + KubernetesAuthEngineRole - Vault read for the identity creds

So a backend only supplies its script, its pod shape, and the k8s RBAC its pod
needs; everything else lives here. Adding a new S3 system = write one `_xxx.tpl`
with `s3.xxx.aggregatorScript` + a thin `s3.xxx.impl` that calls this helper.

Params (index . 1 = a dict):
  name          provider name (the glyph entry key)
  script        rendered aggregator script text (include your s3.xxx.aggregatorScript)
  image         aggregator pod image
  command       aggregator pod command (list)
  env           extra env (list of {name,value}); NAMESPACE is always injected
  envFrom       extra envFrom (list)                          [optional]
  volumes       extra pod volumes (list); a `script` configMap volume is added
  volumeMounts  extra container volumeMounts (list); `script`->/scripts is added
  nodeSelector  pod nodeSelector (dict)                       [optional]
  tolerations   pod tolerations (list)                        [optional]
  securityContext  aggregator container securityContext (dict) [optional]
  resources     aggregator container resources (dict)         [optional]
  podRbacRules  RBAC rules the aggregator pod needs (list of rule dicts)
  trigger       type: workflow renders and submits the internal WorkflowTemplate
                instead of embedding and creating the legacy Pod directly
                ttlStrategy and podGC override its bounded retention defaults
*/}}

{{- define "s3.identityAggregator" -}}
{{- $root := index . 0 -}}
{{- $p := index . 1 -}}
{{- $name := $p.name -}}
{{- $trigger := default dict $p.trigger -}}
{{- $useWorkflow := eq (default "pod" $trigger.type) "workflow" -}}

{{- /* EventBus discovery (default: book fallback) */}}
{{- $eventBuses := get (include "argo-events.lexicon-index" (list $root.Values.lexicon (dict "default" "book") "event-bus" $root.Values.chapter.name) | fromJson) "results" }}
{{- if not $eventBuses }}
  {{- fail "s3.identityAggregator: No EventBus found. Ensure argo-events is deployed with an event-bus lexicon entry." }}
{{- end }}
{{- $eventBus := index $eventBuses 0 }}

{{- /* 1. EventSource - watch the s3-identity secrets in this (provider) namespace */}}
{{ include "argo-events.eventSource" (list $root (dict
  "name" (printf "%s-s3-secrets" $name)
  "eventBusName" $eventBus.name
  "template" (dict "serviceAccountName" (printf "%s-s3-aggregator" $name))
  "resource" (dict
    "s3-identity-changes" (dict
      "namespace" $root.Release.Namespace
      "group" "" "version" "v1" "resource" "secrets"
      "eventTypes" (list "ADD" "UPDATE" "DELETE")
      "filter" (dict
        "afterStart" true
        "labels" (list (dict "key" "runik.ing/s3-identity" "operation" "=" "value" "true"))
      )
    )
  )
)) }}

{{- /* 2. Aggregator script ConfigMap (BACKEND-SPECIFIC content) */}}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ $name }}-s3-aggregator-script
  labels:
    {{- include "common.all.labels" $root | nindent 4 }}
data:
  aggregator.sh: |
{{ $p.script | indent 4 }}
{{- range $fname, $content := (default dict $p.extraScripts) }}
  {{ $fname }}: |
{{ $content | indent 4 }}
{{- end }}

{{- /* 3. Build the backend execution shape shared by Workflow and legacy Pod modes. */}}
{{- $container := dict "name" "aggregator" "image" $p.image "command" $p.command }}
{{- $_ := set $container "env" (concat (list (dict "name" "NAMESPACE" "value" $root.Release.Namespace)) (default list $p.env)) }}
{{- with $p.envFrom }}{{- $_ := set $container "envFrom" . }}{{- end }}
{{- $_ := set $container "volumeMounts" (concat (list (dict "name" "script" "mountPath" "/scripts")) (default list $p.volumeMounts)) }}
{{- $_ := set $container "resources" (default (dict "requests" (dict "cpu" "50m" "memory" "64Mi") "limits" (dict "cpu" "300m" "memory" "256Mi")) $p.resources) }}
{{- with $p.securityContext }}{{- $_ := set $container "securityContext" . }}{{- end }}
{{- $vols := concat (list (dict "name" "script" "configMap" (dict "name" (printf "%s-s3-aggregator-script" $name)))) (default list $p.volumes) }}
{{- $containers := concat (list $container) (default list $p.extraContainers) }}
{{- $podSpec := dict "serviceAccountName" (printf "%s-s3-aggregator-pod" $name) "restartPolicy" "Never" "containers" $containers "volumes" $vols }}
{{- with $p.nodeSelector }}{{- $_ := set $podSpec "nodeSelector" . }}{{- end }}
{{- with $p.tolerations }}{{- $_ := set $podSpec "tolerations" . }}{{- end }}
{{- if $useWorkflow }}
{{- $workflowContainers := deepCopy $containers }}
{{- range $index, $workflowContainer := $workflowContainers }}
  {{- if and (gt $index 0) (not $workflowContainer.dependencies) }}
    {{- $_ := set $workflowContainer "dependencies" (list $container.name) }}
  {{- end }}
{{- end }}
{{- $workflowTemplate := dict
  "name" "reconcile"
  "serviceAccountName" (printf "%s-s3-aggregator-pod" $name)
  "volumes" $vols
  "containerSet" (dict "containers" $workflowContainers)
}}
{{- with $p.nodeSelector }}{{- $_ := set $workflowTemplate "nodeSelector" . }}{{- end }}
{{- with $p.tolerations }}{{- $_ := set $workflowTemplate "tolerations" . }}{{- end }}
{{- $ttlStrategy := default (dict "secondsAfterSuccess" 86400 "secondsAfterFailure" 604800) $trigger.ttlStrategy }}
{{- $podGC := default (dict "strategy" "OnWorkflowCompletion" "deleteDelayDuration" "30m") $trigger.podGC }}
{{ include "workflow.template" (list $root (dict
  "name" (printf "%s-s3-reconcile" $name)
  "labels" (dict
    "runik.ing/s3-provider" $name
    "runik.ing/s3-backend" (default "unknown" $p.backend)
  )
  "spec" (dict
    "entrypoint" "reconcile"
    "ttlStrategy" $ttlStrategy
    "podGC" $podGC
    "templates" (list $workflowTemplate)
  )
)) }}
{{- end }}
{{- $sensorDefinition := dict
  "name" (printf "%s-s3-aggregator" $name)
  "eventBusName" $eventBus.name
  "template" (dict "serviceAccountName" (printf "%s-s3-aggregator" $name))
}}
{{- if $useWorkflow }}
  {{- $_ := set $sensorDefinition "labels" (default (dict "purpose" "s3-identity-reconciliation" "provider" $name) $trigger.sensorLabels) }}
  {{- $_ := set $sensorDefinition "dependencies" (list (dict
    "name" "s3-secret-event"
    "eventSourceName" (printf "%s-s3-secrets" $name)
    "eventName" "s3-identity-changes"
  )) }}
  {{- $_ := set $sensorDefinition "triggers" (list (dict
    "name" "run-aggregator"
    "type" "argoWorkflow"
    "conditions" "s3-secret-event"
    "rateLimit" (default (dict "unit" "Minute" "requestsPerUnit" 1) $trigger.rateLimit)
    "argoWorkflow" (dict
      "operation" "submit"
      "source" (dict "resource" (dict
        "apiVersion" "argoproj.io/v1alpha1" "kind" "Workflow"
        "metadata" (dict "generateName" (printf "%s-s3-aggregator-" $name) "namespace" $root.Release.Namespace)
        "spec" (dict "workflowTemplateRef" (dict "name" (printf "%s-s3-reconcile" $name)))
      ))
    )
  )) }}
{{- else }}
  {{- $_ := set $sensorDefinition "dependencies" (list (dict
    "name" "s3-secret-event"
    "eventSourceName" (printf "%s-s3-secrets" $name)
    "eventName" "s3-identity-changes"
  )) }}
  {{- $_ := set $sensorDefinition "triggers" (list (dict
    "name" "run-aggregator"
    "type" "k8s"
    "rateLimit" (dict "unit" "Minute" "requestsPerUnit" 1)
    "k8s" (dict
      "group" "" "version" "v1" "resource" "pods" "operation" "create"
      "source" (dict "resource" (dict
        "apiVersion" "v1" "kind" "Pod"
        "metadata" (dict "generateName" (printf "%s-s3-aggregator-" $name) "namespace" $root.Release.Namespace)
        "spec" $podSpec
      ))
    )
  )) }}
{{- end }}
{{ include "argo-events.sensor" (list $root $sensorDefinition) }}

{{- /* 5. SA for EventSource + Sensor (lives in the EventBus namespace) */}}
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ $name }}-s3-aggregator
  {{- with $eventBus.namespace }}
  namespace: {{ . }}
  {{- end }}
  labels:
    {{- include "common.all.labels" $root | nindent 4 }}
---
{{- /* EventSource needs to watch secrets in the provider namespace */}}
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: {{ $name }}-s3-eventsource
  namespace: {{ $root.Release.Namespace }}
  labels:
    {{- include "common.all.labels" $root | nindent 4 }}
rules:
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: {{ $name }}-s3-eventsource
  namespace: {{ $root.Release.Namespace }}
  labels:
    {{- include "common.all.labels" $root | nindent 4 }}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: {{ $name }}-s3-eventsource
subjects:
  - kind: ServiceAccount
    name: {{ $name }}-s3-aggregator
    {{- with $eventBus.namespace }}
    namespace: {{ . }}
    {{- end }}
---
{{- /* Sensor creates either the legacy Pod or a Workflow in the provider ns. */}}
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: {{ $name }}-s3-sensor
  namespace: {{ $root.Release.Namespace }}
  labels:
    {{- include "common.all.labels" $root | nindent 4 }}
rules:
  {{- if $useWorkflow }}
  - apiGroups: ["argoproj.io"]
    resources: ["workflows"]
    verbs: ["create", "get", "list"]
  {{- else }}
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["create", "get", "list"]
  {{- end }}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: {{ $name }}-s3-sensor
  namespace: {{ $root.Release.Namespace }}
  labels:
    {{- include "common.all.labels" $root | nindent 4 }}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: {{ $name }}-s3-sensor
subjects:
  - kind: ServiceAccount
    name: {{ $name }}-s3-aggregator
    {{- with $eventBus.namespace }}
    namespace: {{ . }}
    {{- end }}

{{- /* 5. Aggregator pod SA + Role (BACKEND-SPECIFIC rules) in the provider ns */}}
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ $name }}-s3-aggregator-pod
  labels:
    {{- include "common.all.labels" $root | nindent 4 }}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: {{ $name }}-s3-aggregator-pod
  labels:
    {{- include "common.all.labels" $root | nindent 4 }}
rules:
{{ toYaml $p.podRbacRules | indent 2 }}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: {{ $name }}-s3-aggregator-pod
  labels:
    {{- include "common.all.labels" $root | nindent 4 }}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: {{ $name }}-s3-aggregator-pod
subjects:
  - kind: ServiceAccount
    name: {{ $name }}-s3-aggregator-pod
    namespace: {{ $root.Release.Namespace }}

{{- /* 6. Vault: prolicy + KubernetesAuthEngineRole so the provider-namespace
       VaultSecrets (created by s3.bucket with serviceAccount/role pointing here)
       can read the identity creds from Vault. */}}
{{- $vaultServers := get (include "runic-system.runic-indexer" (list $root.Values.lexicon (dict "provider" "operator") "secret-store" $root.Values.chapter.name) | fromJson) "results" }}
{{- $vault := index $vaultServers 0 }}
{{ include "vault.prolicy" (list $root (dict
  "nameOverride" (printf "%s-s3-identities" $name)
  "serviceAccount" (printf "%s-s3-aggregator-pod" $name)
  "extraPolicy" (list
    (dict "path" (printf "%s/data/%s/+/publics/s3-identities-%s-*" $vault.secretPath $root.Values.spellbook.name $name) "capabilities" (list "read" "list"))
    (dict "path" (printf "%s/metadata/%s/+/publics/s3-identities-%s-*" $vault.secretPath $root.Values.spellbook.name $name) "capabilities" (list "read" "list"))
    (dict "path" (printf "%s/data/%s/+/+/publics/s3-identities-%s-*" $vault.secretPath $root.Values.spellbook.name $name) "capabilities" (list "read" "list"))
    (dict "path" (printf "%s/metadata/%s/+/+/publics/s3-identities-%s-*" $vault.secretPath $root.Values.spellbook.name $name) "capabilities" (list "read" "list"))
    (dict "path" (printf "%s/data/%s/+/+/+/publics/s3-identities-%s-*" $vault.secretPath $root.Values.spellbook.name $name) "capabilities" (list "read" "list"))
    (dict "path" (printf "%s/metadata/%s/+/+/+/publics/s3-identities-%s-*" $vault.secretPath $root.Values.spellbook.name $name) "capabilities" (list "read" "list"))
  )
)) }}
---
apiVersion: redhatcop.redhat.io/v1alpha1
kind: KubernetesAuthEngineRole
metadata:
  name: {{ $name }}-s3-aggregator-pod
  namespace: {{ $vault.namespace }}
  labels:
    {{- include "common.all.labels" $root | nindent 4 }}
spec:
  {{- include "vault.connect" (list $root $vault "True") | nindent 2 }}
  path: {{ default $root.Values.spellbook.name $vault.path }}
  policies:
    - {{ $name }}-s3-identities
  targetServiceAccounts:
    - {{ $name }}-s3-aggregator-pod
  targetNamespaces:
    targetNamespaces:
      - {{ $root.Release.Namespace }}
{{- end -}}
