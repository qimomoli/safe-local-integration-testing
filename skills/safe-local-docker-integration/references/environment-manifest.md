# Environment Manifest

Create one manifest for every integration-test run before starting Docker services. Store it in the generated workspace, outside the application repository.

The manifest is the ownership record for setup and cleanup. A resource may be reset or removed only when its identity is present here and its runtime label/project identity agrees.

## Required Fields

```yaml
run_id: <unique-run-id>
created_at: <iso-8601>
workspace: <absolute-generated-workspace>
compose_project: <project-name>
docker_context: <context-name>
docker_host: <redacted-local-endpoint-summary>
resource_label: com.qimomoli.test-run=<run_id>
source_revision: <commit-or-working-tree-summary>
host_ports:
  web: <actual-host-port>
  api: <actual-host-port>
resources:
  containers: []
  networks: []
  volumes: []
data_namespaces:
  database: <name>
  cache: <prefix>
  broker: <topic-prefix>
  object_storage: <bucket-prefix>
cleanup_owner: <agent-or-run-id>
diagnostic_bundle: <path-or-empty>
status: prepared | running | passed | failed | interrupted | cleaned
```

## Rules

- Generate `run_id` before creating any resource. It must be unique across concurrent runs and safe for Docker names.
- Apply `com.qimomoli.test-run=<run_id>` to every container, network, and volume owned by the run.
- Use the same run id in compose project names, workspace paths, data namespaces, test users, and test data identifiers where the backing system supports it.
- Record actual host ports after allocation; do not assume a port derived from the run id is available.
- Redact credentials and tokens. Record their status and source, not their values.
- Record resource IDs returned by Docker or the backing service, not only intended names.
- Mark the manifest `cleaned` only after cleanup has been verified and the diagnostic retention decision has been recorded.

## Cleanup Proof

Before removing a resource, verify:

1. It is listed in `resources`.
2. Its runtime label matches the current `run_id`.
3. Its compose project matches `compose_project`, when applicable.
4. Its endpoint or data namespace matches the manifest.
5. No other active run owns it.

If any check fails, stop and report the ambiguity.
