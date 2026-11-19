# Argo Events glyph

`argo-events.sensor` renders a Sensor selected onto an EventBus from the
lexicon. EventSource references, filters and dependency transformations use
the native Argo Events shape.

When `serviceAccount.enabled` creates the spell's ServiceAccount, an omitted
`template.serviceAccountName` uses its generated name (or the explicit
`serviceAccount.name` override). An explicit Sensor ServiceAccount reference
always wins. Without a created spell ServiceAccount or an explicit reference,
the glyph leaves Argo Events' native ServiceAccount default unchanged.
When the selected EventBus places the Sensor in another namespace, place that
ServiceAccount there explicitly with `serviceAccount.namespace`.

## Inline Workflow triggers

The two native parameterization phases have different targets:

```yaml
triggers:
  - name: repository-workflow
    type: argoWorkflow
    argoWorkflow:
      operation: submit
      source:
        git:
          url: ssh://git@example.com/owner/repo.git
          filePath: .argo/workflow.yaml
          ref: HEAD
      args:
        - --parameter=ci-sha=
      parameters:
        - src:
            dependencyName: push
            value: repository-workflows
          dest: metadata.namespace
    templateParameters:
      - src:
          dependencyName: push
          dataKey: body.after
        dest: argoWorkflow.source.git.ref
```

- `templateParameters` renders as native `Trigger.parameters` and modifies the
  trigger template before loading the external resource. Use it for Git URL,
  ref, clone directory or CLI arguments.
- `argoWorkflow.parameters` renders unchanged as native
  `ArgoWorkflowTrigger.parameters`, applied to the fetched Workflow.
- `argoWorkflow.args` is passed unchanged to the native Argo CLI operation.
- Existing inline `parameters` on `type: argoWorkflow` remain the legacy
  resource-parameter spelling; explicit `argoWorkflow.parameters` takes
  precedence. Other trigger types retain their existing `parameters` behavior.

See `examples/native-git-workflow.yaml` for a complete renderable example.
