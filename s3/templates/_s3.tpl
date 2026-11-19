{{/*Runik Platform
Copyright (C) 2023 namenmalkv@gmail.com
SPDX-License-Identifier: AGPL-3.0-only

S3 Glyph - Seamless S3 integration with automatic credential management

Supports two types:
1. bucket: For apps consuming S3 storage
2. versity: For VersityGW infrastructure setup

Usage in app spell:
glyphs:
  s3:
    my-data:
      type: bucket
      # Optional overrides:
      # bucket: custom-bucket-name  # default: {book}-{chapter}-{name}
      # permissions: ["Read", "Write", "List"]  # default: ["Read", "Write"]
      # public: true  # anonymous GET (public-read ACL); default false = private. versity backend only.
      # pattern: true  # adds -* suffix: {bucket}-*
      # pattern: ["prefix-*", "*-suffix", "custom"]  # custom bucket patterns
      # selector: {provider: versity}  # default: {default: book}

App consumes via:
secrets:
  my-data:
    contentType: env

Usage in VersityGW spell:
glyphs:
  s3:
    gateway:
      type: versity
      # Automatically creates:
      # - EventSource (watching secrets)
      # - Sensor (triggering aggregator)
      # - ConfigMap (aggregator script)
      # - ServiceAccount + RBAC
      # - Prolicy (vault access)
*/}}

{{- define "s3.bucket" -}}
{{- $root := index . 0 -}}
{{- $glyphDefinition := index . 1 -}}
{{ include "s3.bucket.impl" (list $root $glyphDefinition) }}
{{ end -}}
