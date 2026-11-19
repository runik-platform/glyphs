{{/* Runik Platform — SPDX-License-Identifier: AGPL-3.0-only
Standard CNPG metrics on :9187; Grafana file provisioning via ConfigMaps.
Alloy/Prometheus must retain namespace, pod, cnpg_cluster and role target labels.
*/}}
{{- define "postgresql.observability.config" -}}
{{- $definition := index . 1 -}}
{{- $defaults := dict "enabled" true "dashboard" true "alerts" true "datasourceUid" "mimir" "folder" "PostgreSQL" "thresholds" (dict
  "slotRetainedWarningRatio" 0.10
  "slotRetainedCriticalRatio" 0.20
  "replicationLagSeconds" 120
  "diskWarningRatio" 0.80
  "diskCriticalRatio" 0.90
  "connectionsWarningRatio" 0.80
  "archiveStalledSeconds" 900) -}}
{{- $config := mergeOverwrite $defaults (deepCopy (default dict $definition.observability)) -}}
{{- range $key := list "enabled" "dashboard" "alerts" -}}
  {{- if not (kindIs "bool" (get $config $key)) -}}
    {{- fail (printf "postgresql.observability: %s must be a boolean" $key) -}}
  {{- end -}}
{{- end -}}
{{- if $config.enabled -}}
  {{- range $key := list "slotRetainedWarningRatio" "slotRetainedCriticalRatio" "diskWarningRatio" "diskCriticalRatio" "connectionsWarningRatio" -}}
    {{- $value := float64 (get $config.thresholds $key) -}}
    {{- if or (le $value 0.0) (ge $value 1.0) -}}
      {{- fail (printf "postgresql.observability: thresholds.%s must be between 0 and 1" $key) -}}
    {{- end -}}
  {{- end -}}
  {{- if or (ge (float64 $config.thresholds.slotRetainedWarningRatio) (float64 $config.thresholds.slotRetainedCriticalRatio)) (ge (float64 $config.thresholds.diskWarningRatio) (float64 $config.thresholds.diskCriticalRatio)) -}}
    {{- fail "postgresql.observability: warning ratios must be lower than critical ratios" -}}
  {{- end -}}
{{- end -}}
{{- $config | toJson -}}
{{- end -}}

{{- define "postgresql.observability.ruleIDs" -}}
{{- list "metrics-missing" "instances-missing" "primary-down" "slot-warning" "slot-critical" "slot-unlimited" "slot-budget" "disk-warning" "disk-critical" "disk-metrics" "connections" "collector-error" "streaming" "replication-lag" "archive-stalled" "archive-errors" | toJson -}}
{{- end -}}

{{/* Grafana file provisioning requires explicit deletion of removed rules. */}}
{{- define "postgresql.observability.deleteRules" -}}
{{- $identity := index . 0 -}}
{{- $active := index . 1 -}}
{{- $deletions := list -}}
{{- range $id := include "postgresql.observability.ruleIDs" . | fromJsonArray -}}
  {{- $uid := printf "p%s-%s" (trunc 12 $identity) $id -}}
  {{- if not (hasKey $active $uid) -}}
    {{- $deletions = append $deletions (dict "orgId" 1 "uid" $uid) -}}
  {{- end -}}
{{- end -}}
{{- $deletions | toJson -}}
{{- end -}}

{{- define "postgresql.observability.cleanup" -}}
{{- $root := index . 0 -}}
{{- $definition := index . 1 -}}
{{- $name := default (include "common.name" $root) $definition.name -}}
{{- $identity := printf "%s/%s" $root.Release.Namespace $name | sha256sum | trunc 16 -}}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ printf "%s-alerts" ($name | trunc 56 | trimSuffix "-") }}
  labels:
    {{- include "common.all.labels" $root | nindent 4 }}
    grafana_alert: "1"
data:
  postgresql-{{ $identity }}.yaml: |
    {{- dict "apiVersion" 1 "deleteRules" (include "postgresql.observability.deleteRules" (list $identity dict) | fromJsonArray) | toYaml | nindent 4 }}
{{- end -}}

{{- define "postgresql.observability" -}}
{{- $root := index . 0 -}}
{{- $definition := index . 1 -}}
{{- $config := include "postgresql.observability.config" . | fromJson -}}
{{- if $config.enabled -}}
{{- $name := default (include "common.name" $root) $definition.name -}}
{{- $namespace := $root.Release.Namespace -}}
{{- $identity := printf "%s/%s" $namespace $name | sha256sum | trunc 16 -}}
{{- $uid := printf "pg-%s" $identity -}}
{{- $datasource := dict "type" "prometheus" "uid" $config.datasourceUid -}}
{{- $selector := printf "namespace=%s,cnpg_cluster=%s" (toJson $namespace) (toJson $name) -}}
{{- $primary := printf "%s,role=\"primary\"" $selector -}}
{{- $pvcPattern := printf "%s-[0-9]+(-wal)?" (regexQuoteMeta $name) -}}
{{- $volumes := printf "namespace=%s,persistentvolumeclaim=~%s" (toJson $namespace) (toJson $pvcPattern) -}}
{{- $diskUsage := printf "1 - kubelet_volume_stats_available_bytes{%s} / kubelet_volume_stats_capacity_bytes{%s}" $volumes $volumes -}}
{{- $connections := printf "sum by (namespace,pod,cnpg_cluster) (cnpg_backends_total{%s}) / on(namespace,pod,cnpg_cluster) max by (namespace,pod,cnpg_cluster) (cnpg_pg_settings_setting{%s,name=\"max_connections\"})" $selector $selector -}}
{{- $retained := printf "cnpg_pg_replication_slots_pg_wal_lsn_diff{%s}" $primary -}}
{{- $limit := printf "cnpg_pg_settings_setting{%s,name=\"max_slot_wal_keep_size\"}" $primary -}}
{{- $dataPattern := printf "(%s-[0-9]+)" (regexQuoteMeta $name) -}}
{{- $walPattern := printf "(%s-[0-9]+)-wal" (regexQuoteMeta $name) -}}
{{- $dataCapacity := printf "max by(namespace,pod) (label_replace(kubelet_volume_stats_capacity_bytes{namespace=%s,persistentvolumeclaim=~%s}, \"pod\", \"$1\", \"persistentvolumeclaim\", %s))" (toJson $namespace) (toJson $dataPattern) (toJson $dataPattern) -}}
{{- $walCapacity := printf "max by(namespace,pod) (label_replace(kubelet_volume_stats_capacity_bytes{namespace=%s,persistentvolumeclaim=~%s}, \"pod\", \"$1\", \"persistentvolumeclaim\", %s)) or on(namespace,pod) %s" (toJson $namespace) (toJson $walPattern) (toJson $walPattern) $dataCapacity -}}
{{- $slotPressure := printf "%s / on(namespace,pod) group_left() (%s)" $retained $walCapacity -}}
{{- $instances := int (default 1 $definition.instances) -}}
{{- $thresholds := $config.thresholds -}}

{{- if $config.dashboard -}}
{{- $panels := list -}}
{{- $definitions := list
  (dict "title" "PostgreSQL instances up" "type" "stat" "unit" "short" "expr" (printf "sum(cnpg_collector_up{%s})" $selector))
  (dict "title" "Streaming replicas" "type" "stat" "unit" "short" "expr" (printf "max(cnpg_pg_replication_streaming_replicas{%s})" $primary))
  (dict "title" "WAL retained by replication slots" "unit" "bytes" "expr" $retained "legend" "{{pod}} / {{slot_name}}")
  (dict "title" "WAL directory size" "unit" "bytes" "expr" (printf "cnpg_collector_pg_wal{%s,value=\"size\"}" $selector) "legend" "{{pod}}")
  (dict "title" "Slot WAL limit (negative = unlimited)" "type" "stat" "unit" "bytes" "expr" (printf "%s * 1048576" $limit))
  (dict "title" "Replication lag" "unit" "s" "expr" (printf "cnpg_pg_replication_lag{%s,role=\"replica\"}" $selector) "legend" "{{pod}}")
  (dict "title" "PVC space used" "unit" "percentunit" "expr" $diskUsage "legend" "{{persistentvolumeclaim}}")
  (dict "title" "PVC space available" "unit" "bytes" "expr" (printf "kubelet_volume_stats_available_bytes{%s}" $volumes) "legend" "{{persistentvolumeclaim}}")
  (dict "title" "Seconds since successful WAL archive" "unit" "s" "expr" (printf "cnpg_pg_stat_archiver_seconds_since_last_archival{%s}" $primary))
  (dict "title" "WAL archive failures in 15 minutes" "unit" "short" "expr" (printf "increase(cnpg_pg_stat_archiver_failed_count{%s}[15m])" $primary))
  (dict "title" "Connection utilization" "unit" "percentunit" "expr" $connections "legend" "{{pod}}")
  (dict "title" "Database sizes" "unit" "bytes" "expr" (printf "cnpg_pg_database_size_bytes{%s}" $primary) "legend" "{{datname}}")
  (dict "title" "Transactions per second" "unit" "ops" "expr" (printf "sum by (datname) (rate(cnpg_pg_stat_database_xact_commit{%s}[5m]))" $primary) "legend" "{{datname}}")
  (dict "title" "Exporter collection errors" "unit" "short" "expr" (printf "cnpg_collector_last_collection_error{%s}" $selector) "legend" "{{pod}}")
-}}
{{- range $index, $panel := $definitions -}}
  {{- $target := dict "refId" "A" "expr" $panel.expr "legendFormat" (default "" $panel.legend) "datasource" $datasource -}}
  {{- $panels = append $panels (dict "id" (add1 $index) "title" $panel.title "type" (default "timeseries" $panel.type) "datasource" $datasource
    "gridPos" (dict "x" (mul (mod $index 2) 12) "y" (mul (div $index 2) 8) "w" 12 "h" 8)
    "targets" (list $target) "fieldConfig" (dict "defaults" (dict "unit" $panel.unit) "overrides" list)
    "options" (dict "legend" (dict "displayMode" "list" "placement" "bottom"))) -}}
{{- end }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ printf "%s-dashboard" ($name | trunc 53 | trimSuffix "-") }}
  labels:
    {{- include "common.all.labels" $root | nindent 4 }}
    grafana_dashboard: "1"
  annotations:
    grafana_folder: {{ $config.folder | quote }}
data:
  postgresql-{{ $identity }}.json: |
    {{- dict "uid" $uid "title" (printf "PostgreSQL / %s / %s" $namespace $name) "schemaVersion" 39 "version" 1 "editable" false
      "tags" (list "postgresql" "cloudnative-pg" "runik") "refresh" "1m" "time" (dict "from" "now-6h" "to" "now")
      "description" "Standard CNPG and kubelet metrics. Missing volume data is reported by PostgreSQLVolumeMetricsMissing; it is not treated as free disk space."
      "panels" $panels | toPrettyJson | nindent 4 }}
{{- end -}}

{{- if $config.alerts -}}
{{- $rules := list -}}
{{- $definitions := list
  (dict "id" "metrics-missing" "title" "PostgreSQLMetricsMissing" "severity" "critical" "for" "2m" "expr" (printf "absent_over_time(cnpg_collector_up{%s}[5m])" $selector) "threshold" 0 "summary" "No PostgreSQL metrics for five minutes; check discovery, scrape and exporter.")
  (dict "id" "instances-missing" "title" "PostgreSQLInstancesUnavailable" "severity" "warning" "for" "5m" "expr" (printf "clamp_min(%d - (sum(cnpg_collector_up{%s}) or vector(0)), 0)" $instances $selector) "threshold" 0 "summary" "Fewer healthy PostgreSQL instances than configured; inspect replication before WAL accumulates.")
  (dict "id" "primary-down" "title" "PostgreSQLPrimaryUnavailable" "severity" "critical" "for" "2m" "expr" (printf "clamp_min(1 - (sum(cnpg_collector_up{%s}) or vector(0)), 0)" $primary) "threshold" 0 "summary" "No healthy PostgreSQL primary is being monitored.")
  (dict "id" "slot-warning" "title" "PostgreSQLSlotRetainedWALHigh" "severity" "warning" "for" "5m" "expr" $slotPressure "threshold" $thresholds.slotRetainedWarningRatio "summary" "A replication slot is retaining a significant fraction of its WAL filesystem. Check the replica and remaining disk space.")
  (dict "id" "slot-critical" "title" "PostgreSQLSlotRetainedWALCritical" "severity" "critical" "for" "5m" "expr" $slotPressure "threshold" $thresholds.slotRetainedCriticalRatio "summary" "Replication slot WAL retention threatens primary and standby storage; repair or rebuild the lagging replica.")
  (dict "id" "slot-unlimited" "title" "PostgreSQLSlotWALRetentionUnbounded" "severity" "warning" "for" "5m" "expr" (printf "(%s > on(namespace,pod,cnpg_cluster) group_left() (cnpg_pg_settings_setting{%s,name=\"max_wal_size\"} * 1048576)) and on(namespace,pod,cnpg_cluster) (%s < 0)" $retained $primary $limit) "threshold" 0 "summary" "An unlimited slot is retaining more than max_wal_size. Restore replication or set a retention budget before storage fills.")
  (dict "id" "slot-budget" "title" "PostgreSQLSlotWALBudgetLow" "severity" "warning" "for" "5m" "expr" (printf "%s / on(namespace,pod,cnpg_cluster) group_left() ((%s > 0) * 1048576)" $retained $limit) "threshold" 0.75 "summary" "A slot has used over 75% of its configured WAL retention budget; catch up before WAL becomes unavailable.")
  (dict "id" "disk-warning" "title" "PostgreSQLDiskAlmostFull" "severity" "warning" "for" "5m" "expr" $diskUsage "threshold" $thresholds.diskWarningRatio "summary" "PostgreSQL PVC free space is low. Inspect WAL retention, archiving and volume growth.")
  (dict "id" "disk-critical" "title" "PostgreSQLDiskCritical" "severity" "critical" "for" "2m" "expr" $diskUsage "threshold" $thresholds.diskCriticalRatio "summary" "PostgreSQL PVC is critically full; act before PostgreSQL stops and failover candidates run out of space.")
  (dict "id" "disk-metrics" "title" "PostgreSQLVolumeMetricsMissing" "severity" "warning" "for" "10m" "expr" (printf "cnpg_collector_up{%s} unless on(namespace,pod) label_replace((kubelet_volume_stats_capacity_bytes{%s} and on(namespace,persistentvolumeclaim) kubelet_volume_stats_available_bytes{%s}), \"pod\", \"$1\", \"persistentvolumeclaim\", %s)" $selector $volumes $volumes (toJson (printf "(%s-[0-9]+)(-wal)?" (regexQuoteMeta $name)))) "threshold" 0 "summary" "PostgreSQL is up but its PVC metrics are missing. Disk alerts cannot evaluate; check kubelet volume metrics.")
  (dict "id" "connections" "title" "PostgreSQLConnectionsHigh" "severity" "warning" "for" "5m" "expr" $connections "threshold" $thresholds.connectionsWarningRatio "summary" "PostgreSQL connection usage is approaching max_connections.")
  (dict "id" "collector-error" "title" "PostgreSQLMetricsCollectionFailed" "severity" "warning" "for" "5m" "expr" (printf "cnpg_collector_last_collection_error{%s}" $selector) "threshold" 0 "summary" "CNPG cannot collect one or more PostgreSQL metrics; inspect exporter errors.")
-}}
{{- if gt $instances 1 -}}
  {{- $definitions = append $definitions (dict "id" "streaming" "title" "PostgreSQLStreamingReplicasMissing" "severity" "warning" "for" "5m" "expr" (printf "clamp_min(%d - (max(cnpg_pg_replication_streaming_replicas{%s}) or vector(0)), 0)" (sub $instances 1) $primary) "threshold" 0 "summary" "A configured standby is not streaming. Inspect its WAL receiver and replication slot.") -}}
  {{- $definitions = append $definitions (dict "id" "replication-lag" "title" "PostgreSQLReplicationLagHigh" "severity" "warning" "for" "5m" "expr" (printf "cnpg_pg_replication_lag{%s,role=\"replica\"}" $selector) "threshold" $thresholds.replicationLagSeconds "summary" "A standby is behind the primary; inspect connectivity, replay and retained WAL.") -}}
{{- end -}}
{{- $backup := default dict $definition.backup -}}
{{- if and $backup (ne false $backup.enabled) -}}
  {{- $definitions = append $definitions (dict "id" "archive-stalled" "title" "PostgreSQLWALArchivingStalled" "severity" "critical" "for" "5m" "expr" (printf "(time() - cnpg_pg_stat_archiver_last_archived_time{%s}) and on(namespace,pod,cnpg_cluster) (cnpg_collector_pg_wal_archive_status{%s,value=\"ready\"} > 0)" $primary $primary) "threshold" $thresholds.archiveStalledSeconds "summary" "No successful WAL archive within the expected window. Inspect Barman and S3 before local WAL fills the volume.") -}}
  {{- $definitions = append $definitions (dict "id" "archive-errors" "title" "PostgreSQLWALArchivingFailed" "severity" "warning" "for" "2m" "expr" (printf "cnpg_pg_stat_archiver_last_failed_time{%s} > time() - 900" $primary) "threshold" 0 "summary" "WAL archiving failed in the last 15 minutes; inspect Barman, S3 and their dependencies.") -}}
{{- end -}}
{{- $active := dict -}}
{{- range $rule := $definitions -}}
  {{- $_ := set $active (printf "p%s-%s" (trunc 12 $identity) $rule.id) true -}}
  {{- $annotations := dict "summary" $rule.summary -}}
  {{- $panel := "1" -}}
  {{- if hasPrefix "slot-" $rule.id -}}{{- $panel = "3" -}}
  {{- else if hasPrefix "disk-" $rule.id -}}{{- $panel = "7" -}}
  {{- else if hasPrefix "archive-" $rule.id -}}{{- $panel = "9" -}}
  {{- else if eq $rule.id "replication-lag" -}}{{- $panel = "6" -}}
  {{- else if eq $rule.id "connections" -}}{{- $panel = "11" -}}
  {{- else if eq $rule.id "collector-error" -}}{{- $panel = "14" -}}
  {{- end -}}
  {{- if $config.dashboard -}}
    {{- $_ := set $annotations "__dashboardUid__" $uid -}}
    {{- $_ := set $annotations "__panelId__" $panel -}}
  {{- end -}}
  {{- $data := list
    (dict "refId" "A" "datasourceUid" $config.datasourceUid "relativeTimeRange" (dict "from" 900 "to" 0) "model" (dict "refId" "A" "expr" $rule.expr "instant" true "range" false "editorMode" "code" "intervalMs" 60000 "maxDataPoints" 43200))
    (dict "refId" "B" "datasourceUid" "__expr__" "relativeTimeRange" (dict "from" 900 "to" 0) "model" (dict "refId" "B" "type" "reduce" "expression" "A" "reducer" "last"))
    (dict "refId" "C" "datasourceUid" "__expr__" "relativeTimeRange" (dict "from" 900 "to" 0) "model" (dict "refId" "C" "type" "threshold" "expression" "B" "conditions" (list (dict "evaluator" (dict "type" "gt" "params" (list $rule.threshold)))))) -}}
  {{- $rules = append $rules (dict "uid" (printf "p%s-%s" (trunc 12 $identity) $rule.id) "title" (printf "%s / %s / %s" $rule.title $namespace $name) "condition" "C" "for" $rule.for "noDataState" "OK" "execErrState" "Alerting" "isPaused" false
    "labels" (dict "severity" $rule.severity "namespace" $namespace "cnpg_cluster" $name "component" "postgresql")
    "annotations" $annotations "data" $data) -}}
{{- end }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ printf "%s-alerts" ($name | trunc 56 | trimSuffix "-") }}
  labels:
    {{- include "common.all.labels" $root | nindent 4 }}
    grafana_alert: "1"
data:
  postgresql-{{ $identity }}.yaml: |
    {{- dict "apiVersion" 1 "groups" (list (dict "orgId" 1 "name" (printf "postgresql-%s" $identity) "folder" $config.folder "interval" "1m" "rules" $rules)) "deleteRules" (include "postgresql.observability.deleteRules" (list $identity $active) | fromJsonArray) | toYaml | nindent 4 }}
{{- else -}}
{{ include "postgresql.observability.cleanup" . }}
{{- end -}}
{{- else -}}
{{ include "postgresql.observability.cleanup" . }}
{{- end -}}
{{- end -}}
