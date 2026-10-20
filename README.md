# Safe Local Docker Integration Skill

An agent skill for safe, isolated local Docker and container-based integration testing.

This skill helps an AI coding agent stand up disposable local test environments, override production defaults safely, verify backend and frontend behavior, and clean up generated files afterwards. It is designed for real integration testing where multiple services, databases, caches, brokers, object storage, service discovery, or frontend pages may be involved.

It is not a Docker Compose tutorial. The goal is operational discipline: prove the test runtime is local and isolated before starting containers or running destructive test setup.

This is an operating procedure, not a security sandbox. It cannot replace Docker daemon permissions, network isolation, secret management, image policy, or project-specific test controls.

## Why This Exists

Many applications keep production or remote endpoints in checked-in config. That is normal. For local integration tests, an agent should not stop just because source config contains production values. It should:

- treat source config as evidence
- record remote or production defaults as override requirements
- generate isolated local test config outside the application repository
- verify the generated and effective runtime config before starting services
- run test setup only against the isolated environment
- report concise results in the conversation
- clean up temporary files afterwards

## What It Covers

- Local Docker or container-based integration tests.
- Generated compose/env/runtime configuration.
- Isolation by environment id or run id.
- Safety gates for production endpoints, credentials, mounts, ports, and shared resources.
- Automatic test setup inside the current isolated environment.
- Frontend entry URLs and navigation steps for manual visual confirmation.
- Short test reports with failure symptoms and repair suggestions.
- Default cleanup of generated workspaces and temporary logs.
- Docker context and `DOCKER_HOST` preflight.
- Resource ownership through an environment manifest, compose project, and `com.qimomoli.test-run=<run_id>` labels.
- Failure and interruption handling with a minimal diagnostic bundle.
- Optional machine-readable safety checks for rendered Compose JSON.
- Compact runtime summaries with full safety findings saved as local diagnostic artifacts.

## What It Does Not Do

- It does not replace project-specific service knowledge.
- It does not provide a full Docker Compose framework.
- It does not permit editing production code or checked-in production config just to run tests.
- It does not allow production, remote, shared, or unscoped resources to be touched.
- It does not preserve generated reports or logs unless explicitly requested.

For a real project, pair this generic skill with a private project-specific skill that knows repository paths, service names, ports, test users, database schemas, seed data, and business workflows.

## Skill Layout

```text
skills/
  safe-local-docker-integration/
    SKILL.md
    agents/
      openai.yaml
    references/
      safety-gate.md
      environment-manifest.md
      report-template.md
    scripts/
      safety-gate.ps1
      cleanup-guard.ps1
examples/
  request.md
LICENSE
PUBLISHING.md
README.md
```

## Installation

Copy the skill directory into your agent skills directory:

```text
skills/safe-local-docker-integration
```

For Codex-style local skills, that is typically:

```text
~/.codex/skills/
```

For cross-runtime personal skills, many agents also recognize:

```text
~/.agents/skills/
```

## Example Use

Ask your agent something like:

```text
Use safe-local-docker-integration to run a local Docker integration test for this feature.
Do not modify production code or checked-in production config.
Create an isolated local environment, verify the generated runtime config is local-only,
give me the frontend URL and page steps if a UI is involved, keep the report short,
and clean temporary files after the test.
```

See [examples/request.md](examples/request.md) for a reusable prompt. The repository validation script is [tests/validate-skill.ps1](tests/validate-skill.ps1).

## Safety Model

The skill separates evidence from execution:

- **Source evidence:** checked-in config may contain production values. Record them as override requirements.
- **Generated runtime config:** generated compose/env/config and rendered runtime output must be local-only or explicitly test-only.
- **Current environment:** once a database, cache, broker topic, bucket, namespace, container, or network is proven to belong to the current environment id, test setup and cleanup can run automatically.
- **Blockers:** if a resource is remote, shared, production, ambiguous, or belongs to another environment, the agent stops and reports the risk.

## Runtime Contract

Every run must pass the following sequence:

```text
PREFLIGHT -> PREPARE -> RENDER -> SAFETY_GATE -> START
-> HEALTH_CHECK -> FUNCTIONAL_TEST -> REPORT -> CLEANUP
```

The safety gate defaults unknown Docker contexts, ownership, credentials, and fallback endpoints to `BLOCK`. A successful health check without a business-level assertion is not a passing integration test.

## Automated Checks

The repository includes static checks that do not start Docker or delete resources:

```powershell
pwsh -NoProfile -File skills/safe-local-docker-integration/scripts/safety-gate.ps1 -InputPath rendered-compose.json -RunId run-001 -RequireRunLabels -Compact -OutFile safety-gate.json
pwsh -NoProfile -File skills/safe-local-docker-integration/scripts/cleanup-guard.ps1 -ManifestPath manifest.json -ResourcesPath resources.json -Compact -OutFile cleanup-guard.json
```

Exit codes:

```text
0  ALLOW
10 REPLACE
20 ASK
30 BLOCK
```

`confirm-before-work` or equivalent local confirmation rules still apply before creating generated workspaces, manifests, rendered configs, logs, diagnostic bundles, reports, or before deleting any generated files.

## License

MIT License. See [LICENSE](LICENSE).
