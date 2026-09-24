{{/*Runik Platform
Copyright (C) 2026 namenmalkav@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

netbird.networkLocation composes an account Network from the existing NetBird
glyph primitives. It deliberately owns no enrollment credential: routers are
existing peers, existing peer groups, or peers managed by a separately
declared peerEnrollment.

Generated names are scoped by the glyph name so multiple locations can share
one namespace without collisions.
*/}}
{{- define "netbird.networkLocation" -}}
{{- $root := index . 0 -}}
{{- $definition := index . 1 -}}
{{- $_ := include "netbird.requireInstance" (list $root $definition "netbird.networkLocation") }}
{{- $namespace := default $root.Release.Namespace $definition.namespace -}}
{{- $name := $definition.name -}}
{{- $networkName := default $name $definition.networkName -}}
{{- $routerGroupName := default (printf "%s-routers" $name) $definition.routerGroupName -}}
{{- $resourceGroupName := default (printf "%s-resources" $name) $definition.resourceGroupName -}}
{{- $routerResourceName := default (printf "%s-router" $name) $definition.routerResourceName -}}
{{- $accessPolicyName := default (printf "%s-access" $name) $definition.accessPolicyName -}}
{{- $routerInputPolicyName := default (printf "%s-router-input" $name) $definition.routerInputPolicyName -}}
{{- range $generated := list $networkName $routerGroupName $resourceGroupName $routerResourceName $accessPolicyName $routerInputPolicyName -}}
  {{- if gt (len $generated) 63 -}}
    {{- fail (printf "netbird.networkLocation: generated name %q exceeds 63 characters; use a shorter glyph name or explicit group/network overrides" $generated) -}}
  {{- end -}}
{{- end -}}

{{- $routers := required "netbird.networkLocation: routers is required" $definition.routers -}}
{{- if not (kindIs "map" $routers) -}}{{- fail "netbird.networkLocation: routers must be a map" -}}{{- end -}}
{{- if eq (len $routers) 0 -}}{{- fail "netbird.networkLocation: at least one router is required" -}}{{- end -}}
{{- $sourceRefs := get (include "netbird.resolveRefs" (list $root (default (list) $definition.sourceGroupRefs) (default (dict) $definition.sourceGroupsSelector) "netbird-group" "netbird.networkLocation source groups") | fromJson) "refs" -}}
{{- $postureRefs := get (include "netbird.resolveRefs" (list $root (default (list) $definition.sourcePostureCheckRefs) (default (dict) $definition.sourcePostureChecksSelector) "netbird-posture-check" "netbird.networkLocation source posture checks") | fromJson) "refs" -}}
{{- $routerGroupRefs := list $routerGroupName -}}
{{- $directRouters := list -}}

{{- range $routerKey, $router := $routers -}}
  {{- if not (kindIs "map" $router) -}}{{- fail (printf "netbird.networkLocation: routers.%s must be an object" $routerKey) -}}{{- end -}}
  {{- $selectionCount := 0 -}}
  {{- if $router.enrollmentRef -}}{{- $selectionCount = add1 $selectionCount -}}{{- end -}}
  {{- if $router.peerRef -}}{{- $selectionCount = add1 $selectionCount -}}{{- end -}}
  {{- if $router.peerGroupRef -}}{{- $selectionCount = add1 $selectionCount -}}{{- end -}}
  {{- if ne $selectionCount 1 -}}{{- fail (printf "netbird.networkLocation: routers.%s requires exactly one of enrollmentRef, peerRef or peerGroupRef" $routerKey) -}}{{- end -}}
  {{- if and (hasKey $router "manageBinding") (not $router.enrollmentRef) -}}{{- fail (printf "netbird.networkLocation: routers.%s.manageBinding is only valid with enrollmentRef" $routerKey) -}}{{- end -}}
  {{- if $router.peerGroupRef -}}
    {{- $routerGroupRefs = append $routerGroupRefs (toString $router.peerGroupRef) -}}
  {{- else -}}
    {{- $peerName := default $router.peerRef $router.peerName -}}
    {{- if $router.enrollmentRef -}}
      {{- if kindIs "map" $router.enrollmentRef -}}
        {{- $enrollmentName := required (printf "netbird.networkLocation: routers.%s.enrollmentRef.name is required" $routerKey) $router.enrollmentRef.name -}}
        {{- $peerName = default $enrollmentName $router.enrollmentRef.peerName -}}
      {{- else -}}
        {{- $peerName = default (toString $router.enrollmentRef) $router.peerName -}}
      {{- end -}}
    {{- end -}}
    {{- $_ := required (printf "netbird.networkLocation: routers.%s must resolve a peer name" $routerKey) $peerName -}}
    {{- $manageBinding := true -}}
    {{- if hasKey $router "manageBinding" -}}{{- $manageBinding = $router.manageBinding -}}{{- end -}}
    {{- if $manageBinding -}}
      {{- $bindingName := default (printf "%s-router-%s" $name $routerKey) $router.bindingName -}}
      {{- if gt (len $bindingName) 63 -}}{{- fail (printf "netbird.networkLocation: generated router binding name %q exceeds 63 characters" $bindingName) -}}{{- end -}}
      {{- $directRouters = append $directRouters (dict "bindingName" $bindingName "peerName" $peerName) -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- $routerGroupRefs = uniq $routerGroupRefs -}}

{{ include "netbird.accountNetwork" (list $root (dict
  "name" $networkName
  "namespace" $namespace
  "instanceRef" $definition.instanceRef
  "instanceSelector" $definition.instanceSelector
  "nbName" (default $name $definition.nbName)
  "description" (default (printf "Network location %s" $name) $definition.description)
  "labels" $definition.labels
  "annotations" $definition.annotations
)) }}

{{ include "netbird.group" (list $root (dict
  "name" $routerGroupName
  "namespace" $namespace
  "instanceRef" $definition.instanceRef
  "instanceSelector" $definition.instanceSelector
  "nbName" $routerGroupName
  "labels" $definition.labels
  "annotations" $definition.annotations
)) }}

{{- range $router := $directRouters }}
{{ include "netbird.peerGroupBinding" (list $root (dict
  "name" $router.bindingName
  "namespace" $namespace
  "instanceRef" $definition.instanceRef
  "instanceSelector" $definition.instanceSelector
  "peerRef" $router.peerName
  "groupRef" $routerGroupName
  "labels" $definition.labels
  "annotations" $definition.annotations
)) }}
{{- end }}

{{ include "netbird.accountNetworkRouter" (list $root (dict
  "name" $routerResourceName
  "namespace" $namespace
  "instanceRef" $definition.instanceRef
  "instanceSelector" $definition.instanceSelector
  "networkRef" $networkName
  "peerGroupRefs" $routerGroupRefs
  "enabled" (ternary $definition.enabled true (hasKey $definition "enabled"))
  "masquerade" (ternary $definition.masquerade true (hasKey $definition "masquerade"))
  "metric" (ternary $definition.metric 9999 (hasKey $definition "metric"))
  "labels" $definition.labels
  "annotations" $definition.annotations
)) }}

{{- $resources := default (dict) $definition.resources -}}
{{- if not (kindIs "map" $resources) -}}{{- fail "netbird.networkLocation: resources must be a map" -}}{{- end -}}
{{- if $resources }}
  {{- if not $sourceRefs -}}{{- fail "netbird.networkLocation: sourceGroupRefs or sourceGroupsSelector is required when resources are declared" -}}{{- end -}}
  {{- $access := required "netbird.networkLocation: access is required when resources are declared" $definition.access -}}
  {{- $accessRules := required "netbird.networkLocation: access.rules is required when resources are declared" $access.rules -}}
{{ include "netbird.group" (list $root (dict
  "name" $resourceGroupName
  "namespace" $namespace
  "instanceRef" $definition.instanceRef
  "instanceSelector" $definition.instanceSelector
  "nbName" $resourceGroupName
  "labels" $definition.labels
  "annotations" $definition.annotations
)) }}
  {{- range $resourceKey, $resource := $resources -}}
    {{- if not (kindIs "map" $resource) -}}{{- fail (printf "netbird.networkLocation: resources.%s must be an object" $resourceKey) -}}{{- end -}}
    {{- $resourceName := default (printf "%s-%s" $name $resourceKey) $resource.resourceName -}}
    {{- if gt (len $resourceName) 63 -}}{{- fail (printf "netbird.networkLocation: generated resource name %q exceeds 63 characters" $resourceName) -}}{{- end -}}
{{ include "netbird.accountNetworkResource" (list $root (dict
  "name" $resourceName
  "namespace" $namespace
  "instanceRef" $definition.instanceRef
  "instanceSelector" $definition.instanceSelector
  "nbName" (default $resourceKey $resource.nbName)
  "description" (default "" $resource.description)
  "address" $resource.address
  "enabled" (ternary $resource.enabled true (hasKey $resource "enabled"))
  "networkRef" $networkName
  "groupRefs" (uniq (concat (list $resourceGroupName) (default (list) $resource.groupRefs)))
  "labels" $definition.labels
  "annotations" $definition.annotations
)) }}
  {{- end }}
{{ include "netbird.policy" (list $root (dict
  "name" $accessPolicyName
  "namespace" $namespace
  "instanceRef" $definition.instanceRef
  "instanceSelector" $definition.instanceSelector
  "nbName" (default $accessPolicyName $access.nbName)
  "description" (default (printf "Allow selected groups to reach %s resources" $name) $access.description)
  "enabled" (ternary $access.enabled true (hasKey $access "enabled"))
  "sourceGroupRefs" $sourceRefs
  "destinationGroupRefs" (list $resourceGroupName)
  "sourcePostureCheckRefs" $postureRefs
  "rules" $accessRules
  "labels" $definition.labels
  "annotations" $definition.annotations
)) }}
{{- end }}

{{- $routerInput := default (dict) $definition.routerInput -}}
{{- if $routerInput }}
  {{- if not $sourceRefs -}}{{- fail "netbird.networkLocation: source groups are required when routerInput is declared" -}}{{- end -}}
  {{- $routerInputRules := required "netbird.networkLocation: routerInput.rules is required" $routerInput.rules -}}
{{ include "netbird.policy" (list $root (dict
  "name" $routerInputPolicyName
  "namespace" $namespace
  "instanceRef" $definition.instanceRef
  "instanceSelector" $definition.instanceSelector
  "nbName" (default $routerInputPolicyName $routerInput.nbName)
  "description" (default (printf "Allow selected groups to reach routers for %s" $name) $routerInput.description)
  "enabled" (ternary $routerInput.enabled true (hasKey $routerInput "enabled"))
  "sourceGroupRefs" $sourceRefs
  "destinationGroupRefs" $routerGroupRefs
  "sourcePostureCheckRefs" $postureRefs
  "rules" $routerInputRules
  "labels" $definition.labels
  "annotations" $definition.annotations
)) }}
{{- end }}

{{- $dns := default (dict) $definition.dns -}}
{{- if not (kindIs "map" $dns) -}}{{- fail "netbird.networkLocation: dns must be an object" -}}{{- end -}}
{{- with $dns.nameserverGroup }}
  {{- if not $sourceRefs -}}{{- fail "netbird.networkLocation: source groups are required for dns.nameserverGroup" -}}{{- end -}}
{{ include "netbird.nameserverGroup" (list $root (dict
  "name" (default (printf "%s-dns" $name) .name)
  "namespace" $namespace
  "instanceRef" $definition.instanceRef
  "instanceSelector" $definition.instanceSelector
  "nbName" (default (printf "%s-dns" $name) .nbName)
  "description" .description
  "nameservers" .nameservers
  "domains" .domains
  "enabled" (ternary .enabled true (hasKey . "enabled"))
  "primary" (ternary .primary false (hasKey . "primary"))
  "searchDomainsEnabled" (ternary .searchDomainsEnabled false (hasKey . "searchDomainsEnabled"))
  "groupRefs" $sourceRefs
  "labels" $definition.labels
  "annotations" $definition.annotations
)) }}
{{- end }}

{{- $zones := default (dict) $dns.zones -}}
{{- if not (kindIs "map" $zones) -}}{{- fail "netbird.networkLocation: dns.zones must be a map" -}}{{- end -}}
{{- range $zoneKey, $zone := $zones }}
  {{- if not (kindIs "map" $zone) -}}{{- fail (printf "netbird.networkLocation: dns.zones.%s must be an object" $zoneKey) -}}{{- end -}}
  {{- $zoneName := printf "%s-%s" $name $zoneKey -}}
  {{- if gt (len $zoneName) 63 -}}{{- fail (printf "netbird.networkLocation: generated DNS zone name %q exceeds 63 characters" $zoneName) -}}{{- end -}}
{{ include "netbird.dnsZone" (list $root (dict
  "name" $zoneName
  "namespace" $namespace
  "instanceRef" $definition.instanceRef
  "instanceSelector" $definition.instanceSelector
  "nbName" (default $zoneKey $zone.nbName)
  "domain" $zone.domain
  "enabled" (ternary $zone.enabled true (hasKey $zone "enabled"))
  "enableSearchDomain" (ternary $zone.enableSearchDomain false (hasKey $zone "enableSearchDomain"))
  "distributionGroupRefs" (default $sourceRefs $zone.distributionGroupRefs)
  "labels" $definition.labels
  "annotations" $definition.annotations
)) }}
  {{- range $recordKey, $record := (default (dict) $zone.records) }}
    {{- if not (kindIs "map" $record) -}}{{- fail (printf "netbird.networkLocation: dns.zones.%s.records.%s must be an object" $zoneKey $recordKey) -}}{{- end -}}
    {{- $recordName := printf "%s-%s-%s" $name $zoneKey $recordKey -}}
    {{- if gt (len (printf "%s-%s" $recordName $zoneName)) 63 -}}{{- fail (printf "netbird.networkLocation: generated DNS record name for %s/%s exceeds 63 characters" $zoneKey $recordKey) -}}{{- end -}}
{{ include "netbird.dnsRecord" (list $root (dict
  "name" $recordName
  "namespace" $namespace
  "instanceRef" $definition.instanceRef
  "instanceSelector" $definition.instanceSelector
  "nbName" (default $recordKey $record.nbName)
  "recordType" $record.recordType
  "content" $record.content
  "ttl" $record.ttl
  "zoneRef" $zoneName
  "labels" $definition.labels
  "annotations" $definition.annotations
)) }}
  {{- end }}
{{- end }}
{{ end }}
