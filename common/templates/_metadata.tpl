{{/*
Named-argument metadata API. All three public helpers return JSON maps; callers
use fromJson and render toYaml once. None modifies its inputs.

common.metadata.labels / common.metadata.annotations:
  dict "root" $root "local" $localMap "generated" $generatedMap
local/generated are optional. Precedence: conventions < root < local < generated.
Labels: existing Kubernetes/infra/FinOps/Covenant conventions, then
Values.labels.custom. Annotations: Values.description, then Values.annotations.
Scalar values become strings; null, maps and lists are rejected. Selector label
values cannot be overridden by labels.custom, local or generated labels.

common.metadata.selectorLabels:
  dict "root" $root
Same identity as legacy common.selectorLabels, for selectors and pod metadata.
Only this subset belongs in matchLabels. Label groups and selectors keep their
existing keys (including the historical 'spelbook' spelling).

Legacy helpers retain their signatures, YAML/JSON formats, and behavior.
*/}}
{{- define "common.metadata.selectorLabels" -}}
{{- dict "app.kubernetes.io/name" (include "common.name" .root) "app.kubernetes.io/instance" (toString .root.Release.Name) | toJson -}}
{{- end -}}

{{/* Private scalar-map conversion shared by labels and annotations. */}}
{{- define "common.metadata._strings" -}}
{{- $result := dict -}}
{{- if and (not (kindIs "invalid" .values)) (not (kindIs "map" .values)) -}}
  {{- fail (printf "%s must be a map" .field) -}}
{{- end -}}
{{- range $key, $value := .values -}}
  {{- if not (has (kindOf $value) (list "string" "bool" "int" "int32" "int64" "uint" "uint64" "float32" "float64")) -}}
    {{- fail (printf "%s[%s] must be a scalar string, number or boolean" $.field $key) -}}
  {{- end -}}
  {{- $_ := set $result $key (toString $value) -}}
{{- end -}}
{{- toJson $result -}}
{{- end -}}

{{/* Normalize each source before merging, so invalid overwritten values also fail. */}}
{{- define "common.metadata._merge" -}}
{{- $result := dict -}}
{{- range $index, $source := .sources -}}
  {{- $strings := include "common.metadata._strings" (dict "values" $source "field" (printf "%s source %d" $.field $index)) | fromJson -}}
  {{- range $key, $value := $strings -}}
    {{- if and (hasKey (default dict $.protected) $key) (ne (get $.protected $key) $value) -}}
      {{- fail (printf "%s: selector label %s must remain %q" $.field $key (get $.protected $key)) -}}
    {{- end -}}
    {{- $_ := set $result $key $value -}}
  {{- end -}}
{{- end -}}
{{- toJson $result -}}
{{- end -}}

{{- define "common.metadata.labels" -}}
{{- $root := .root -}}
{{- $values := $root.Values -}}
{{- $selectors := include "common.metadata.selectorLabels" (dict "root" $root) | fromJson -}}
{{- $labels := deepCopy $selectors -}}
{{- $_ := set $labels "app.kubernetes.io/managed-by" $root.Release.Service -}}
{{- with $root.Chart.AppVersion -}}{{- $_ := set $labels "app.kubernetes.io/version" . -}}{{- end -}}
{{- with $values.component -}}{{- $_ := set $labels "app.kubernetes.io/component" . -}}{{- end -}}
{{- with $values.spellbook -}}
  {{- with .name -}}
    {{- $_ := set $labels "app.kubernetes.io/part-of" . -}}
    {{- $_ := set $labels "spelbook" . -}}
  {{- end -}}
{{- end -}}
{{- with $values.chapter -}}{{- with .name -}}{{- $_ := set $labels "chapter" . -}}{{- end -}}{{- end -}}
{{- $_ := set $labels "spell" (default $root.Chart.Name $values.name) -}}
{{- $config := default dict $values.labels -}}
{{- if and (not (kindIs "invalid" $values.labels)) (not (kindIs "map" $values.labels)) -}}
  {{- fail "common.metadata.labels: Values.labels must be a map" -}}
{{- end -}}
{{- with $config.finops -}}
  {{- if .enabled -}}
    {{- range $input, $output := dict "team" "team" "owner" "owner" "costCenter" "cost-center" "department" "department" "project" "project" -}}
      {{- with get $config.finops $input -}}{{- $_ := set $labels $output . -}}{{- end -}}
    {{- end -}}
    {{- $environment := default (get (default dict $values.chapter) "name") .environment -}}
    {{- with $environment -}}{{- $_ := set $labels "environment" . -}}{{- end -}}
  {{- end -}}
{{- end -}}
{{- with $config.covenant -}}
  {{- if .enabled -}}
    {{- range $key := list "team" "owner" "department" "member" "organization" -}}
      {{- with get $config.covenant $key -}}{{- $_ := set $labels (print "covenant.runik.io/" $key) . -}}{{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- include "common.metadata._merge" (dict "field" "common.metadata.labels" "protected" $selectors "sources" (list $labels $config.custom .local .generated)) -}}
{{- end -}}

{{- define "common.metadata.annotations" -}}
{{- $root := .root -}}
{{- $defaults := dict -}}
{{- with $root.Values.description -}}{{- $_ := set $defaults "kubernetes.io/description" . -}}{{- end -}}
{{- include "common.metadata._merge" (dict "field" "common.metadata.annotations" "sources" (list $defaults $root.Values.annotations .local .generated)) -}}
{{- end -}}
