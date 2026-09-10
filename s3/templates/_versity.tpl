{{/*Runik Platform
Copyright (C) 2023 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

s3.versity - VersityGW (posix backend, Vault IAM) S3 infrastructure.

Consumer-agnostic: a spell asks for storage with `s3.type: bucket` exactly as it
would for any other backend; the s3-provider lexicon entry routes it here. This
glyph wires the shared identity aggregator (see _identity-aggregator.tpl) with a
versity-specific reconcile script:

  for each k8s Secret labelled runik.ing/s3-identity=true (emitted by s3.bucket):
    versitygw admin create-user --access <AWS_ACCESS_KEY_ID> --secret <...> --role <user|admin>
    for each declared bucket: a posix dir under the gateway root, owned by the user
  prune any gateway user no longer declared

NON-ROOT by design (fs safety with a hostPath to the array): the aggregator runs
as the gateway uid (default 1042:1069), so buckets it creates are owned correctly
with no chown, and it needs no root for package installs — it reads the k8s API
with busybox wget trusting the cluster CA via SSL_CERT_FILE (busybox wget has no
--ca-certificate), and parses with grep/sed (no jq). Pre-existing bucket data must
be chowned to the gateway uid once, out of band (a migration step).

Unlike seaweed there is NO restart: versity reads its IAM from Vault on demand;
create-user writes the record straight into the Vault iam/ tree.

Usage (infra spell — e.g. bookrack/the-yaml-life/intro/s3.yaml):
  glyphs:
    s3:
      gateway:
        type: versity
        # adminEndpoint: http://s3.s3.svc:7071   # default from Release.Namespace
        # bucketsHostPath: /var/mnt/cargo-hold    # the RAID; gateway root is /buckets under it
        # rootSecret: s3-root                     # ROOT_ACCESS_KEY/ROOT_SECRET_KEY
        # runAsUser/runAsGroup: 1042/1069         # the gateway uid
*/}}

{{- define "s3.versity" -}}
{{- $root := index . 0 -}}
{{- $glyphDefinition := index . 1 -}}
{{ include "s3.versity.impl" (list $root $glyphDefinition) }}
{{- end -}}

{{- define "s3.versity.impl" -}}
{{- $root := index . 0 -}}
{{- $g := index . 1 -}}
{{- $name := $g.name -}}
{{- $s3Endpoint := default (printf "http://s3.%s.svc:7070" $root.Release.Namespace) $g.s3Endpoint -}}
{{- $aclImage := default "public.ecr.aws/aws-cli/aws-cli:2.27.41" $g.aclImage -}}
{{- /* Second container ("acl"): applies public-read ACLs. versitygw has no admin
   ACL command and its posix backend stores the ACL in an xattr (unwritable from the
   busybox aggregator), so the only portable way to set public-read is the S3 API
   (PutBucketAcl, canned public-read = the all-users:READ grantee VerifyPublicAccess
   checks). aws-cli lives in a stock image; versitygw stays the aggregator image.
   The handshake file (/shared/admin-done) makes the acl container run AFTER
   change-bucket-owner, which resets the ACL, so the public-read write is never
   clobbered. */}}
{{ include "s3.identityAggregator" (list $root (dict
  "name" $name
  "backend" "versity"
  "script" (include "s3.versity.aggregatorScript" (list $root $g))
  "extraScripts" (dict "acl.sh" (include "s3.versity.aclScript" (list $root $g)))
  "image" (default "ghcr.io/versity/versitygw:v1.7.0" $g.image)
  "command" (list "sh" "/scripts/aggregator.sh")
  "envFrom" (list (dict "secretRef" (dict "name" (default "s3-root" $g.rootSecret))))
  "env" (list
    (dict "name" "ADMIN_ENDPOINT" "value" (default (printf "http://s3.%s.svc:7071" $root.Release.Namespace) $g.adminEndpoint))
    (dict "name" "BUCKETS_ROOT" "value" (default "/storage/cargo-hold/buckets" $g.bucketsRoot))
  )
  "volumes" (list
    (dict "name" "buckets" "hostPath" (dict "path" (default "/var/mnt/cargo-hold" $g.bucketsHostPath)))
    (dict "name" "shared" "emptyDir" (dict))
  )
  "volumeMounts" (list
    (dict "name" "buckets" "mountPath" "/storage/cargo-hold")
    (dict "name" "shared" "mountPath" "/shared")
  )
  "extraContainers" (list (dict
    "name" "acl"
    "image" $aclImage
    "command" (list "sh" "/scripts/acl.sh")
    "envFrom" (list (dict "secretRef" (dict "name" (default "s3-root" $g.rootSecret))))
    "env" (list
      (dict "name" "S3_ENDPOINT" "value" $s3Endpoint)
      (dict "name" "AWS_EC2_METADATA_DISABLED" "value" "true")
      (dict "name" "AWS_REQUEST_CHECKSUM_CALCULATION" "value" "when_required")
      (dict "name" "AWS_RESPONSE_CHECKSUM_VALIDATION" "value" "when_required")
    )
    "volumeMounts" (list
      (dict "name" "script" "mountPath" "/scripts")
      (dict "name" "shared" "mountPath" "/shared")
    )
  ))
  "nodeSelector" (default dict $g.nodeSelector)
  "tolerations" (default (list (dict "key" "role" "operator" "Equal" "value" "system" "effect" "NoSchedule")) $g.tolerations)
  "securityContext" (dict "runAsUser" (default 1042 $g.runAsUser) "runAsGroup" (default 1069 $g.runAsGroup))
  "podRbacRules" (list (dict "apiGroups" (list "") "resources" (list "secrets") "verbs" (list "get" "list")))
  "trigger" (default dict $g.trigger)
)) }}
{{- end -}}

{{- /* Reconcile script. Runs once per Sensor trigger (pod, restartPolicy Never);
       the EventSource replays existing secrets afterStart, so it also runs on
       bring-up. Idempotent, non-root, never logs secret values. */}}
{{- define "s3.versity.aggregatorScript" -}}
#!/bin/sh
set -u
ADMIN="${ADMIN_ENDPOINT}"
BUCKETS_ROOT="${BUCKETS_ROOT}"
SA=/var/run/secrets/kubernetes.io/serviceaccount
# busybox wget has no --ca-certificate; SSL_CERT_FILE makes its TLS trust the
# in-cluster CA, so we can read the k8s API non-root without curl/apk.
export SSL_CERT_FILE="$SA/ca.crt"
K8S=https://kubernetes.default.svc
TOKEN=$(cat "$SA/token")

# v1.7 installs the CLI in /usr/local/bin; retain the fallback for callers that
# explicitly override the aggregator image to a pre-v1.7 release.
VERSITYGW_BIN="$(command -v versitygw 2>/dev/null || true)"
[ -n "$VERSITYGW_BIN" ] || VERSITYGW_BIN=/app/versitygw
[ -x "$VERSITYGW_BIN" ] || { echo "iam-aggregator: versitygw CLI not found" >&2; exit 1; }
admin() { "$VERSITYGW_BIN" admin --access "$ROOT_ACCESS_KEY" --secret "$ROOT_SECRET_KEY" --endpoint-url "$ADMIN" "$@"; }
kget()  { wget -qO- --header "Authorization: Bearer $TOKEN" "$K8S$1" 2>/dev/null; }
# value of a k8s Secret data field (pretty-printed JSON: "KEY": "b64"); base64 d by caller
val()   { grep -oE "\"$1\": *\"[^\"]*\"" | head -1 | sed 's/^[^:]*: *"//;s/"$//'; }

# Public-bucket handshake with the `acl` sidecar: we publish the concrete buckets
# that must be public-read to /shared/public-buckets.txt, then touch /shared/admin-done
# (always, even on early exit) so the acl container runs strictly AFTER our reconcile —
# i.e. after change-bucket-owner, which would otherwise reset the ACL.
: > /shared/public-buckets.txt
done_signal() { touch /shared/admin-done 2>/dev/null || true; }

echo "iam-aggregator: waiting for gateway admin API at $ADMIN ..."
until admin list-users >/dev/null 2>&1; do sleep 3; done

LIST=$(kget "/api/v1/namespaces/$NAMESPACE/secrets?labelSelector=runik.ing%2Fs3-identity%3Dtrue")
# Never prune on a failed read: a transient k8s API hiccup must not be read as
# "no users declared" and wipe every account.
printf %s "$LIST" | grep -q '"kind": *"SecretList"' || { echo "iam-aggregator: identity read failed — skipping (no prune)"; done_signal; exit 0; }

# metadata.name of every item (plus harmless ownerReference names, deduped by
# empty access key below) = the declared identity secrets
NAMES=$(printf %s "$LIST" | grep -oE '"name": *"[^"]*"' | sed 's/^[^:]*: *"//;s/"$//' | sort -u)

# Build the declared access-key set, then prune gateway users not in it
# (the env ROOT account is not in list-users, so it is never pruned).
DECLARED=""
for n in $NAMES; do
  ak=$(kget "/api/v1/namespaces/$NAMESPACE/secrets/$n" | val AWS_ACCESS_KEY_ID | base64 -d 2>/dev/null)
  [ -n "$ak" ] && DECLARED="$DECLARED $ak"
done
for acct in $(admin list-users 2>/dev/null | awk 'NR>2 && NF {print $1}'); do
  case " $DECLARED " in
    *" $acct "*) ;;
    *) echo "iam-aggregator: pruning undeclared user"; admin delete-user --access "$acct" >/dev/null 2>&1 ;;
  esac
done

# Ensure each declared identity + its owned buckets
for n in $NAMES; do
  s=$(kget "/api/v1/namespaces/$NAMESPACE/secrets/$n")
  ak=$(printf %s "$s" | val AWS_ACCESS_KEY_ID | base64 -d 2>/dev/null)
  sk=$(printf %s "$s" | val AWS_SECRET_ACCESS_KEY | base64 -d 2>/dev/null)
  bks=$(printf %s "$s" | val BUCKETS | base64 -d 2>/dev/null)
  perms=$(printf %s "$s" | val PERMISSIONS | base64 -d 2>/dev/null)
  # public is a label on the secret (metadata, not data), present only when true
  pub=; printf %s "$s" | grep -q '"runik.ing/s3-public" *: *"true"' && pub=true
  [ -n "$ak" ] && [ -n "$sk" ] || continue
  role=user
  printf %s "$perms" | grep -qiw Admin && role=admin
  if ! admin list-users 2>/dev/null | awk 'NR>2 {print $1}' | grep -qx "$ak"; then
    admin create-user --access "$ak" --secret "$sk" --role "$role" >/dev/null 2>&1 \
      && echo "iam-aggregator: created user (role $role)" \
      || echo "iam-aggregator: create-user FAILED for an identity"
  fi
  # buckets: comma-separated; a posix bucket can't be a glob, skip wildcards.
  # Created as the run uid (1042) -> no chown needed.
  for b in $(printf %s "$bks" | tr ',' ' '); do
    case "$b" in *"*"*) continue ;; "") continue ;; esac
    [ -d "$BUCKETS_ROOT/$b" ] || mkdir -p "$BUCKETS_ROOT/$b"
    admin change-bucket-owner --bucket "$b" --owner "$ak" >/dev/null 2>&1
    # hand the concrete public buckets to the acl sidecar (wildcards already skipped)
    [ "$pub" = "true" ] && echo "$b" >> /shared/public-buckets.txt
  done
done
done_signal
echo "iam-aggregator: reconcile done"
{{- end -}}

{{- /* ACL sidecar script. Runs in a stock aws-cli image alongside the versitygw
       aggregator. Waits (bounded) for the aggregator's /shared/admin-done so it
       always runs after change-bucket-owner, then applies the public-read canned
       ACL to each bucket the aggregator listed. ROOT creds (admin role) come from
       the s3-root envFrom as ROOT_ACCESS_KEY/ROOT_SECRET_KEY. Idempotent. */}}
{{- define "s3.versity.aclScript" -}}
#!/bin/sh
set -u
export AWS_ACCESS_KEY_ID="$ROOT_ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="$ROOT_SECRET_KEY"
# Force path-style addressing: aws-cli v2 defaults to virtual-host style
# (bucket.s3.s3.svc) which has no DNS here. botocore reads this only from a config
# file, so we write a throwaway one. Matches the gateway's VGW_FORCE_PATH_STYLE.
export AWS_CONFIG_FILE=/tmp/aws-config
printf '[default]\ns3 =\n    addressing_style = path\n' > "$AWS_CONFIG_FILE"

# Wait for the aggregator pass, with a timeout so a stuck/crashed admin container
# can never hang this pod (restartPolicy Never -> it would block forever).
i=0
while [ ! -f /shared/admin-done ]; do
  i=$((i + 1))
  [ "$i" -gt 60 ] && { echo "acl: timed out waiting for the aggregator pass"; exit 0; }
  sleep 2
done

[ -s /shared/public-buckets.txt ] || { echo "acl: no public buckets"; exit 0; }
while IFS= read -r b; do
  [ -n "$b" ] || continue
  if aws --endpoint-url "$S3_ENDPOINT" --region us-east-1 \
       s3api put-bucket-acl --bucket "$b" --acl public-read >/dev/null 2>&1; then
    echo "acl: $b -> public-read"
  else
    echo "acl: put-bucket-acl FAILED for $b"
  fi
done < /shared/public-buckets.txt
echo "acl: done"
{{- end -}}
