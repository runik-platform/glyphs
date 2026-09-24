# Argo CD Image Updater glyph

This glyph renders native
`argocd-image-updater.argoproj.io/v1alpha1` `ImageUpdater` resources through
Kaster.

```yaml
glyphs:
  argocd-image-updater:
    application-images:
      type: imageUpdater
      namespace: argocd
      spec:
        commonUpdateSettings:
          updateStrategy: digest
        applicationRefs:
          - namePattern: my-application
            writeBackConfig:
              gitConfig:
                writeBackTarget: helmvalues:/applications/my-application.yaml
            images:
              - alias: app
                imageName: registry.example.com/example/app:latest
                manifestTargets:
                  helm:
                    spec: image
```

By default, the glyph selects exactly one Lexicon entry with
`type: argocd-image-writeback` and `labels.default: book`:

```yaml
lexicon:
  default-image-writeback:
    type: argocd-image-writeback
    writeBackConfig:
      method: git
      gitConfig:
        repository: ssh://git@git.example.com:2222/example/config.git
        branch: 'main:image-updater-{{.SHA256}}'
    labels:
      default: book
```

Use `writeBackProfile.selector` to select a different profile. Fields declared
under the glyph's native `spec.writeBackConfig` override the selected profile
recursively. Per-application `writeBackConfig` remains available for settings
such as `gitConfig.writeBackTarget`, which normally differs for every spell.

To bypass Lexicon and provide the complete native configuration manually:

```yaml
writeBackProfile:
  enabled: false
spec:
  writeBackConfig:
    method: argocd
```

Apart from resolving the write-back profile, the `spec` object is passed
through unchanged and validated by the upstream CRD. The glyph requires
`spec.applicationRefs` and adds the standard Runik labels. `metadata.name`
comes from the glyph entry key; `namespace` defaults to the Kaster release
namespace.
