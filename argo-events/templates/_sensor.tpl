{{/*Runik Platform
Copyright (C) 2023 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

argo-events.sensor creates Sensor resources for Argo Events
Follows runik glyph parameter pattern with runic indexer integration

Parameters:
- Glyph usage: (list $root $glyphDefinition)

Usage:
- {{- include "argo-events.sensor" (list $root $glyphDefinition) }}

Example glyphDefinition:
  name: workflow-sensor
  selector:
    type: jetstream
    environment: production
  dependencies:
    - name: github-push
      eventSourceName: github-webhook
      eventName: my-repo
  triggers:
    - name: trigger-workflow
      type: argoWorkflow
      argoWorkflow:
        operation: submit
        source:
          resource:
            apiVersion: argoproj.io/v1alpha1
            kind: Workflow
 */}}
{{- define "argo-events.sensor" }}
{{- $root := index . 0 }}
{{- $glyphDefinition := index . 1 }}
{{- $resourceName := default (include "common.name" $root) $glyphDefinition.name }}

{{/* Find EventBus using runicIndexer */}}
{{- $eventBuses := get (include "argo-events.lexicon-index" (list $root.Values.lexicon (default dict $glyphDefinition.selector) "event-bus" $root.Values.chapter.name ) | fromJson) "results" }}

{{/* Find EventSources using runicIndexer if eventSourceSelector is provided */}}
{{- $eventSources := list }}
{{- if $glyphDefinition.eventSourceSelector }}
{{- $eventSources = get (include "argo-events.lexicon-index" (list $root.Values.lexicon (default dict $glyphDefinition.eventSourceSelector) "event-source" $root.Values.chapter.name ) | fromJson) "results" }}
{{- end }}

{{/* Discover workflow targets inversely: each target selects the Sensor that
     owns it. triggerSelector remains as a compatibility path for callers that
     have not migrated their publications yet. */}}
{{- $triggers := list }}
{{- if $glyphDefinition.triggerSelector }}
{{- $triggers = get (include "runic-system.runic-indexer" (list $root.Values.lexicon (default dict $glyphDefinition.triggerSelector) "workflow-trigger" $root.Values.chapter.name ) | fromJson) "results" }}
{{- else }}
  {{- $sensorRegistry := dict $resourceName (dict
    "name" $resourceName
    "type" "sensor"
    "labels" (deepCopy (default dict $glyphDefinition.labels))
  ) }}
  {{- range $triggerName, $triggerDefinition := (default dict $root.Values.lexicon) }}
    {{- if and (eq (default "" $triggerDefinition.type) "workflow-trigger") $triggerDefinition.sensorSelector }}
      {{- $matchingSensors := get (include "runic-system.runic-indexer" (list $sensorRegistry $triggerDefinition.sensorSelector "sensor" $root.Values.chapter.name) | fromJson) "results" }}
      {{- if gt (len $matchingSensors) 0 }}
        {{- $trigger := deepCopy $triggerDefinition }}
        {{- if not $trigger.name }}{{- $_ := set $trigger "name" $triggerName }}{{- end }}
        {{- $triggers = append $triggers $trigger }}
      {{- end }}
    {{- end }}
  {{- end }}
{{- end }}

{{/* A trigger may select a published Tarot reading instead of hardcoding the
     WorkflowTemplate name. The appendix contains only the small reference;
     the reading and its cards stay owned by Tarot. */}}
{{- $resolvedTriggers := list }}
{{- range $trigger := $triggers }}
  {{- $resolvedTrigger := deepCopy $trigger }}
  {{- if $trigger.readingSelector }}
    {{- if $trigger.template }}
      {{- fail (printf "workflow-trigger '%s' cannot combine template and readingSelector" $trigger.name) }}
    {{- end }}
    {{- if eq (len $trigger.readingSelector) 0 }}
      {{- fail (printf "workflow-trigger '%s' readingSelector cannot be empty" $trigger.name) }}
    {{- end }}
    {{- $readings := get (include "runic-system.runic-indexer" (list $root.Values.lexicon $trigger.readingSelector "tarot-reading" $root.Values.chapter.name) | fromJson) "results" }}
    {{- if eq (len $readings) 0 }}
      {{- fail (printf "workflow-trigger '%s' readingSelector matched no tarot-reading" $trigger.name) }}
    {{- else if gt (len $readings) 1 }}
      {{- fail (printf "workflow-trigger '%s' readingSelector matched multiple tarot-readings" $trigger.name) }}
    {{- end }}
    {{- $reading := index $readings 0 }}
    {{- $readingLabels := default dict $reading.labels }}
    {{- $exactMatch := true }}
    {{- range $key, $value := $trigger.readingSelector }}
      {{- if and (hasKey $readingLabels $key) (eq (index $readingLabels $key) $value) }}
      {{- else if and (hasKey $reading $key) (eq (toString (index $reading $key)) (toString $value)) }}
      {{- else }}
        {{- $exactMatch = false }}
      {{- end }}
    {{- end }}
    {{- if not $exactMatch }}
      {{- fail (printf "workflow-trigger '%s' readingSelector matched only a lexicon default; named readings require an exact selector match" $trigger.name) }}
    {{- end }}
    {{- if not $reading.name }}
      {{- fail "tarot-reading requires name (normally injected from its lexicon key)" }}
    {{- end }}
    {{- if $reading.reference }}
      {{- fail (printf "tarot-reading '%s' uses removed nested reference; publish scope and namespace directly on the lexicon entry" $reading.name) }}
    {{- end }}
    {{- $scope := default "namespace" $reading.scope }}
    {{- if not (has $scope (list "namespace" "cluster")) }}
      {{- fail (printf "tarot-reading '%s' has unsupported scope '%s'; use namespace or cluster" $reading.name $scope) }}
    {{- end }}
    {{- $_ := set $resolvedTrigger "template" $reading.name }}
    {{- $_ := set $resolvedTrigger "clusterScope" (eq $scope "cluster") }}
    {{- if eq $scope "namespace" }}
      {{- $_ := set $resolvedTrigger "namespace" (default $reading.name $reading.namespace) }}
    {{- end }}
    {{- $parameterDefinitions := default dict (dig "contract" "inputs" "parameters" dict $reading) }}
    {{- $acceptedParameters := list }}
    {{- if kindIs "map" $parameterDefinitions }}
      {{- $acceptedParameters = keys $parameterDefinitions }}
    {{- else if kindIs "slice" $parameterDefinitions }}
      {{- range $parameterDefinitions }}
        {{- if kindIs "string" . }}
          {{- $acceptedParameters = append $acceptedParameters . }}
        {{- else if and (kindIs "map" .) (hasKey . "name") }}
          {{- $acceptedParameters = append $acceptedParameters .name }}
        {{- end -}}
      {{- end }}
    {{- end }}
    {{- range $name, $parameter := (default dict $trigger.parameters) }}
      {{- if not (has $name $acceptedParameters) }}
        {{- fail (printf "workflow-trigger '%s' provides parameter '%s' not declared by tarot-reading '%s'" $trigger.name $name $reading.name) }}
      {{- end }}
      {{- if eq (kindOf $parameter) "invalid" }}
        {{- fail (printf "workflow-trigger '%s' parameter '%s' cannot be null" $trigger.name $name) }}
      {{- end }}
      {{- if and (kindIs "map" $parameter) (not (or (hasKey $parameter "from") (hasKey $parameter "dataTemplate") (hasKey $parameter "value") (hasKey $parameter "default"))) }}
        {{- fail (printf "workflow-trigger '%s' parameter '%s' requires from, dataTemplate, value or default" $trigger.name $name) }}
      {{- end }}
    {{- end }}
    {{- if kindIs "map" $parameterDefinitions }}
      {{- range $name, $definition := $parameterDefinitions }}
        {{- $hasBinding := hasKey (default dict $trigger.parameters) $name }}
        {{- if and $hasBinding (eq (kindOf (index $trigger.parameters $name)) "invalid") }}
          {{- $hasBinding = false }}
        {{- end }}
        {{- if and (kindIs "map" $definition) $definition.required (not $hasBinding) (not (hasKey $definition "default")) (not (hasKey $definition "value")) }}
          {{- fail (printf "workflow-trigger '%s' is missing required tarot-reading parameter '%s'" $trigger.name $name) }}
        {{- end }}
      {{- end }}
    {{- end }}
  {{- end }}
  {{- $resolvedTriggers = append $resolvedTriggers $resolvedTrigger }}
{{- end }}
{{- $triggers = $resolvedTriggers }}
{{- if and $glyphDefinition.requireWorkflowTriggers (eq (len $triggers) 0) -}}
  {{- fail (printf "Sensor '%s' requires at least one workflow-trigger publication selecting it" $resourceName) -}}
{{- end }}
{{- if and (gt (len $triggers) 0) $glyphDefinition.dependencies -}}
  {{- fail "A Sensor cannot combine discovered workflow-trigger targets with inline dependencies" -}}
{{- end }}
{{- if and (gt (len $triggers) 0) $glyphDefinition.triggers -}}
  {{- fail "A Sensor cannot combine discovered workflow-trigger targets with inline triggers" -}}
{{- end }}

{{- range $eventBus := $eventBuses }}
---
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: {{ $resourceName }}
  {{- if $eventBus.namespace }}
  namespace: {{ $eventBus.namespace }}
  {{- end }}
  labels:
    {{- include "common.labels" $root | nindent 4 }}
    {{- with $glyphDefinition.labels }}
    {{- . | toYaml | nindent 4 }}
    {{- end }}
  {{- with $glyphDefinition.annotations }}
  annotations:
    {{- . | toYaml | nindent 4 }}
  {{- end }}
spec:
  eventBusName: {{ default $eventBus.name $glyphDefinition.eventBusName }}
  {{- if $glyphDefinition.template }}
  template:
    {{- with $glyphDefinition.template.serviceAccountName }}
    serviceAccountName: {{ . }}
    {{- end }}
    {{- if $glyphDefinition.template.container }}
    container:
      {{- $glyphDefinition.template.container | toYaml | nindent 6 }}
    {{- end }}
    {{- with $glyphDefinition.template.volumes }}
    volumes:
      {{- . | toYaml | nindent 6 }}
    {{- end }}
    {{- with $glyphDefinition.template.nodeSelector }}
    nodeSelector:
      {{- . | toYaml | nindent 6 }}
    {{- end }}
    {{- with $glyphDefinition.template.tolerations }}
    tolerations:
      {{- . | toYaml | nindent 6 }}
    {{- end }}
    {{- with $glyphDefinition.template.metadata }}
    metadata:
      {{- . | toYaml | nindent 6 }}
    {{- end }}
    {{- with $glyphDefinition.template.securityContext }}
    securityContext:
      {{- . | toYaml | nindent 6 }}
    {{- end }}
    {{- with $glyphDefinition.template.affinity }}
    affinity:
      {{- . | toYaml | nindent 6 }}
    {{- end }}
    {{- with $glyphDefinition.template.priorityClassName }}
    priorityClassName: {{ . }}
    {{- end }}
    {{- with $glyphDefinition.template.priority }}
    priority: {{ . }}
    {{- end }}
    {{- with $glyphDefinition.template.imagePullSecrets }}
    imagePullSecrets:
      {{- . | toYaml | nindent 6 }}
    {{- end }}
  {{- end }}
  {{- if or $glyphDefinition.dependencies (gt (len $eventSources) 0) (gt (len $triggers) 0) }}
  dependencies:
    {{- if $glyphDefinition.dependencies }}
    {{/* Use inline dependencies (backward compatibility) */}}
    {{- range $glyphDefinition.dependencies }}
    - name: {{ .name }}
      {{- with .eventSourceName }}
      eventSourceName: {{ . }}
      {{- end }}
      {{- with .eventName }}
      eventName: {{ . }}
      {{- end }}
      {{- if .filters }}
      filters:
        {{- if .filters.expression }}
        expression: |
          {{- .filters.expression | nindent 10 }}
        {{- end }}
        {{- if .filters.exprs }}
        exprs:
          {{- range .filters.exprs }}
          - expr: {{ .expr }}
            {{- if .fields }}
            fields:
              {{- range .fields }}
              - name: {{ .name }}
                path: {{ .path }}
              {{- end }}
            {{- end }}
          {{- end }}
        {{- end }}
        {{- if .filters.data }}
        data:
          {{- range .filters.data }}
          - path: {{ .path }}
            type: {{ .type }}
            value:
              {{- .value | toYaml | nindent 14 }}
            {{- with .comparator }}
            comparator: {{ . }}
            {{- end }}
          {{- end }}
        {{- end }}
        {{- if .filters.context }}
        context:
          {{- .filters.context | toYaml | nindent 10 }}
        {{- end }}
        {{- if .filters.time }}
        time:
          {{- .filters.time | toYaml | nindent 10 }}
        {{- end }}
        {{- if .filters.script }}
        script: {{ .filters.script }}
        {{- end }}
      {{- end }}
      {{- if .transform }}
      transform:
        {{- .transform | toYaml | nindent 8 }}
      {{- end }}
    {{- end }}
    {{- else if gt (len $triggers) 0 }}
    {{- /* Each published target owns one dependency so its match filters and
         trigger condition remain isolated from every other target. */ -}}
    {{- range $trigger := $triggers }}
      {{- $eventSourceName := default "" $trigger.eventSourceName -}}
      {{- $eventName := default "" $trigger.eventName -}}
      {{- if not $eventSourceName -}}
        {{- if eq (len $eventSources) 0 -}}
          {{- fail (printf "workflow-trigger '%s' requires an eventSourceSelector result or eventSourceName" $trigger.name) -}}
        {{- else if gt (len $eventSources) 1 -}}
          {{- fail (printf "workflow-trigger '%s' matched multiple EventSources; set eventSourceName explicitly" $trigger.name) -}}
        {{- else -}}
          {{- $eventSource := index $eventSources 0 -}}
          {{- $eventSourceName = $eventSource.name -}}
          {{- $eventName = default (default $eventSource.name $eventSource.eventName) $eventName -}}
        {{- end }}
      {{- end }}
    - name: {{ $trigger.name }}
      eventSourceName: {{ $eventSourceName }}
      eventName: {{ default $eventSourceName $eventName }}
      {{- if $trigger.filters }}
      filters:
        {{- $trigger.filters | toYaml | nindent 8 }}
      {{- else if $trigger.match }}
      filters:
        data:
        {{- range $field, $match := $trigger.match }}
          {{- $path := printf "body.%s" $field -}}
          {{- $type := "string" -}}
          {{- $value := $match -}}
          {{- $comparator := "=" -}}
          {{- if kindIs "map" $match -}}
            {{- if not (hasKey $match "value") -}}
              {{- fail (printf "workflow-trigger '%s' match '%s' requires value" $trigger.name $field) -}}
            {{- end -}}
            {{- $path = default $path $match.path -}}
            {{- $type = default $type $match.type -}}
            {{- $value = $match.value -}}
            {{- $comparator = default $comparator $match.comparator -}}
          {{- end }}
        - path: {{ $path }}
          type: {{ $type }}
          value:
            - {{ $value | quote }}
          comparator: {{ $comparator }}
        {{- end }}
      {{- end }}
    {{- end }}
    {{- else }}
    {{- /* Build dependencies dynamically from EventSources when no target
         publications are selected (backward-compatible sensor composition). */ -}}
    {{- range $eventSource := $eventSources }}
    - name: {{ $eventSource.name }}
      eventSourceName: {{ $eventSource.name }}
      eventName: {{ default $eventSource.name $eventSource.eventName }}
      {{- if $glyphDefinition.dependencyFilters }}
      filters:
        {{- $glyphDefinition.dependencyFilters | toYaml | nindent 8 }}
      {{- end }}
    {{- end }}
    {{- end }}
  {{- end }}
  {{- if or $glyphDefinition.triggers (gt (len $triggers) 0) }}
  triggers:
    {{- if $glyphDefinition.triggers }}
    {{- /* Use inline triggers (backward compatibility) */ -}}
    {{- range $glyphDefinition.triggers }}
    - template:
        name: {{ .name }}
        {{- if .conditions }}
        conditions: {{ .conditions }}
        {{- end }}
        {{- if eq .type "argoWorkflow" }}
        argoWorkflow:
          {{- with .argoWorkflow.operation }}
          operation: {{ . }}
          {{- end }}
          {{- if .argoWorkflow.source }}
          source:
            {{- if .argoWorkflow.source.resource }}
            resource:
              {{- .argoWorkflow.source.resource | toYaml | nindent 14 }}
            {{- end }}
            {{- if .argoWorkflow.source.file }}
            file:
              {{- .argoWorkflow.source.file | toYaml | nindent 14 }}
            {{- end }}
            {{- if .argoWorkflow.source.url }}
            url:
              {{- .argoWorkflow.source.url | toYaml | nindent 14 }}
            {{- end }}
            {{- if .argoWorkflow.source.configmap }}
            configmap:
              {{- .argoWorkflow.source.configmap | toYaml | nindent 14 }}
            {{- end }}
            {{- if .argoWorkflow.source.git }}
            git:
              {{- .argoWorkflow.source.git | toYaml | nindent 14 }}
            {{- end }}
          {{- end }}
          {{/* Workflow resource paths must be parameterized by the Argo
               Workflow trigger, not by the enclosing TriggerTemplate. */}}
          {{- if .parameters }}
          parameters:
            {{- range .parameters }}
            - src:
                dependencyName: {{ .src.dependencyName }}
                {{- with .src.dataKey }}
                dataKey: {{ . }}
                {{- end }}
                {{- with .src.dataTemplate }}
                dataTemplate: {{ . }}
                {{- end }}
                {{- with .src.value }}
                value: {{ . }}
                {{- end }}
              dest: {{ .dest }}
              {{- with .operation }}
              operation: {{ . }}
              {{- end }}
            {{- end }}
          {{- end }}
        {{- else if eq .type "http" }}
        http:
          {{- with .http.url }}
          url: {{ . }}
          {{- end }}
          {{- with .http.payload }}
          payload:
            {{- . | toYaml | nindent 12 }}
          {{- end }}
          {{- with .http.method }}
          method: {{ . }}
          {{- end }}
          {{- with .http.headers }}
          headers:
            {{- . | toYaml | nindent 12 }}
          {{- end }}
          {{- if .http.basicAuth }}
          basicAuth:
            {{- .http.basicAuth | toYaml | nindent 12 }}
          {{- end }}
          {{- with .http.tls }}
          tls:
            {{- . | toYaml | nindent 12 }}
          {{- end }}
        {{- else if eq .type "k8s" }}
        k8s:
          {{- with .k8s.group }}
          group: {{ . }}
          {{- end }}
          {{- with .k8s.version }}
          version: {{ . }}
          {{- end }}
          {{- with .k8s.resource }}
          resource: {{ . }}
          {{- end }}
          {{- with .k8s.operation }}
          operation: {{ . }}
          {{- end }}
          {{- if .k8s.source }}
          source:
            {{- .k8s.source | toYaml | nindent 12 }}
          {{- end }}
          {{- with .k8s.liveObject }}
          liveObject: {{ . }}
          {{- end }}
        {{- else if eq .type "nats" }}
        nats:
          {{- with .nats.url }}
          url: {{ . }}
          {{- end }}
          {{- with .nats.subject }}
          subject: {{ . }}
          {{- end }}
          {{- with .nats.payload }}
          payload:
            {{- . | toYaml | nindent 12 }}
          {{- end }}
          {{- if .nats.parameters }}
          parameters:
            {{- .nats.parameters | toYaml | nindent 12 }}
          {{- end }}
          {{- if .nats.tls }}
          tls:
            {{- .nats.tls | toYaml | nindent 12 }}
          {{- end }}
        {{- else if eq .type "kafka" }}
        kafka:
          {{- with .kafka.url }}
          url: {{ . }}
          {{- end }}
          {{- with .kafka.topic }}
          topic: {{ . }}
          {{- end }}
          {{- with .kafka.partition }}
          partition: {{ . }}
          {{- end }}
          {{- with .kafka.payload }}
          payload:
            {{- . | toYaml | nindent 12 }}
          {{- end }}
          {{- if .kafka.requiredAcks }}
          requiredAcks: {{ .kafka.requiredAcks }}
          {{- end }}
          {{- if .kafka.compress }}
          compress: {{ .kafka.compress }}
          {{- end }}
          {{- if .kafka.flushFrequency }}
          flushFrequency: {{ .kafka.flushFrequency }}
          {{- end }}
          {{- if .kafka.tls }}
          tls:
            {{- .kafka.tls | toYaml | nindent 12 }}
          {{- end }}
          {{- if .kafka.sasl }}
          sasl:
            {{- .kafka.sasl | toYaml | nindent 12 }}
          {{- end }}
        {{- else if eq .type "slack" }}
        slack:
          {{- if .slack.token }}
          token:
            {{- .slack.token | toYaml | nindent 12 }}
          {{- end }}
          {{- with .slack.channel }}
          channel: {{ . }}
          {{- end }}
          {{- with .slack.message }}
          message: {{ . }}
          {{- end }}
          {{- if .slack.parameters }}
          parameters:
            {{- .slack.parameters | toYaml | nindent 12 }}
          {{- end }}
        {{- else if eq .type "log" }}
        log:
          {{- with .log.intervalSeconds }}
          intervalSeconds: {{ . }}
          {{- end }}
        {{- end }}
      {{- if .policy }}
      policy:
        {{- .policy | toYaml | nindent 8 }}
      {{- end }}
      {{- if .retryStrategy }}
      retryStrategy:
        {{- .retryStrategy | toYaml | nindent 8 }}
      {{- end }}
      {{- if .rateLimit }}
      rateLimit:
        {{- with .rateLimit.unit }}
        unit: {{ . }}
        {{- end }}
        {{- with .rateLimit.requestsPerUnit }}
        requestsPerUnit: {{ . }}
        {{- end }}
      {{- end }}
      {{- if and .parameters (ne .type "argoWorkflow") }}
      parameters:
        {{- range .parameters }}
        - src:
            dependencyName: {{ .src.dependencyName }}
            {{- with .src.dataKey }}
            dataKey: {{ . }}
            {{- end }}
            {{- with .src.dataTemplate }}
            dataTemplate: {{ . }}
            {{- end }}
            {{- with .src.value }}
            value: {{ . }}
            {{- end }}
          dest: {{ .dest }}
          {{- with .operation }}
          operation: {{ . }}
          {{- end }}
        {{- end }}
      {{- end }}
    {{- end }}
    {{- else }}
    {{- /* Build triggers dynamically from workflow-trigger publications. */ -}}
    {{- range $trigger := $triggers }}
      {{- if not $trigger.template }}
        {{- fail (printf "workflow-trigger '%s' requires template" $trigger.name) }}
      {{- end }}
    - template:
        name: {{ $trigger.name }}
        conditions: {{ default $trigger.name $trigger.conditions | quote }}
        argoWorkflow:
          operation: {{ default "submit" $trigger.operation }}
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: {{ $trigger.template }}-
                namespace: {{ default $root.Release.Namespace $trigger.namespace }}
              spec:
                workflowTemplateRef:
                  name: {{ $trigger.template }}
                  {{- if $trigger.clusterScope }}
                  clusterScope: true
                  {{- end }}
                {{- if $trigger.parameters }}
                arguments:
                  parameters:
                  {{- range $parameterName, $parameter := $trigger.parameters }}
                    - name: {{ $parameterName }}
                      {{- if kindIs "map" $parameter }}
                      value: {{ default "" $parameter.default | quote }}
                      {{- else }}
                      value: {{ $parameter | quote }}
                      {{- end }}
                  {{- end }}
                {{- end }}
          {{/* Keep resource parameter bindings on ArgoWorkflowTrigger.
               Trigger-level bindings target TriggerTemplate instead. */}}
          {{- if $trigger.parameters }}
          parameters:
            {{- $parameterIndex := 0 }}
            {{- range $parameterName, $parameter := $trigger.parameters }}
              {{- $hasSource := not (kindIs "map" $parameter) }}
              {{- if kindIs "map" $parameter }}
                {{- $hasSource = or (hasKey $parameter "from") (hasKey $parameter "dataTemplate") (hasKey $parameter "value") }}
              {{- end }}
              {{- if $hasSource }}
            - src:
                dependencyName: {{ $trigger.name }}
                {{- if kindIs "map" $parameter }}
                  {{- with $parameter.from }}
                dataKey: {{ . }}
                  {{- end }}
                  {{- with $parameter.dataTemplate }}
                dataTemplate: {{ . | quote }}
                  {{- end }}
                  {{- if hasKey $parameter "value" }}
                value: {{ $parameter.value | quote }}
                  {{- end }}
                {{- else }}
                value: {{ $parameter | quote }}
                {{- end }}
              dest: {{ printf "spec.arguments.parameters.%d.value" $parameterIndex }}
              {{- end }}
            {{- $parameterIndex = add1 $parameterIndex }}
            {{- end }}
          {{- end }}
      {{- with $trigger.policy }}
      policy:
        {{- . | toYaml | nindent 8 }}
      {{- end }}
      {{- with $trigger.retryStrategy }}
      retryStrategy:
        {{- . | toYaml | nindent 8 }}
      {{- end }}
      {{- with $trigger.rateLimit }}
      rateLimit:
        {{- . | toYaml | nindent 8 }}
      {{- end }}
    {{- end }}
    {{- end }}
  {{- end }}
  {{- if $glyphDefinition.errorOnFailedRound }}
  errorOnFailedRound: {{ .errorOnFailedRound }}
  {{- end }}
  {{- if $glyphDefinition.replicas }}
  replicas: {{ .replicas }}
  {{- end }}
{{- end }}
{{- end}}
