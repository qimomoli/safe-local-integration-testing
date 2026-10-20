---
name: safe-local-docker-integration
description: Use when preparing or running Docker or container-based integration tests that could reach production, remote services, shared infrastructure, or unrelated local resources, or could leave unsafe test state behind.
---

# Safe Local Docker Integration

## Overview

Use this skill for any project where local Docker integration testing must be isolated from production code, production configuration, remote infrastructure, and unrelated local containers. Production endpoints or credentials may legitimately exist in checked-in source config; treat them as evidence that must be overridden locally, not as a reason to abandon local testing. The core rule is evidence before startup: scan and prove the generated and effective test configuration is local-only before running containers or tests.

This skill is an operating procedure, not a security sandbox. Docker daemon permissions, network policy, credential management, and CI isolation remain required controls.

Runtime evidence budget: prefer machine-readable summaries on stdout and save full findings to the current generated workspace. Do not read or paste full compose output, environment dumps, scan JSON, or unbounded logs. Expand a saved artifact only when its summary reports a blocker or when a specific file/line is needed for the next decision.

- Logs: use `docker compose logs --no-color --tail 80 <service>` and inspect one service at a time.
- Inspect/HTTP: request selected fields or status plus a short body excerpt; never dump raw `docker inspect`, Swagger, HTML, or large JSON responses.
- Retries: allow at most two bounded retries per failing hop. Reuse saved artifacts and rerun a scan only after the generated config changes.

When `confirm-before-work` or an equivalent workspace-write confirmation rule is active, that rule is the authoritative confirmation protocol. If it is not available, use the built-in Side-Effect Confirmation section below. This skill decides what is safe to create or clean; it does not bypass required confirmation before side effects.

## Side-Effect Confirmation

Before any action that can create, edit, delete, start, stop, restart, publish, send, reset, clean, or otherwise change local or external state, pause and ask for explicit confirmation.

This includes:

- creating, editing, or deleting generated workspaces, compose files, env files, manifests, logs, screenshots, reports, or diagnostic bundles
- starting, stopping, restarting, rebuilding, or deleting containers, networks, images, volumes, services, or Docker contexts
- initializing, seeding, migrating, resetting, truncating, deleting, or cleaning databases, caches, queues, topics, buckets, service-discovery namespaces, or other runtime state
- pulling images or packages, using external registries, publishing reports or messages, creating commits, pushing code, tagging releases, or otherwise publishing state

Before the action, state:

- exact action
- target files, repositories, services, resources, endpoints, or bounded patterns
- intended change
- likely side effects
- cleanup or retention boundary
- assumptions and open questions

Wait for explicit confirmation before performing the action. Confirmation applies only to the listed scope. If the action, target, side effect, retention boundary, or external destination changes, ask again before continuing.

Read-only inspection does not require confirmation when it does not create files, change runtime state, transmit user data, or affect an external system. Treat uncertain commands as side-effect-capable and ask first.

## Core Boundaries

- Treat application repositories as read-only inputs unless the user explicitly approves a separate code/config change.
- Do not edit checked-in `.env*`, `application*.yml`, `application*.properties`, Dockerfiles, compose files, migrations, or production runtime config just to make local tests work.
- Generate compose files, env files, mock config, seed data, and temporary logs in a separate test workspace only for the duration of the run.
- Before creating or deleting generated files, present the Side-Effect Confirmation check with the workspace path, expected artifacts, retention policy, and cleanup boundary.
- Give every concurrent requirement or run a distinct test environment id. Create an environment manifest and apply `com.qimomoli.test-run=<run_id>` labels to every Docker resource that this run owns. See [references/environment-manifest.md](references/environment-manifest.md).
- Use the id in the workspace path, compose project name, Docker network, container/volume names, host ports, database/schema names, service-discovery namespace, object-storage bucket, topic prefix, test user/data ids, and frontend URL reporting. Prefer dynamically allocated host ports and record the actual mappings.
- Do not connect to production or shared remote databases, caches, brokers, service discovery, object storage, auth, payment, SMS, or API gateways.
- Do not reuse production credentials, real object-storage buckets, real topics, production namespaces, or live customer data.
- Before using Docker, prove that `DOCKER_HOST` and `docker context show` point to the intended local daemon. An unknown or remote context is a blocker.
- Use dummy credentials and local mocks. Do not copy production `.env` files, secrets, tokens, certificates, or customer data into the generated workspace.
- Do not delete Docker volumes, prune images, remove unrelated containers, or clean databases outside the current test project. Operations inside containers and current-environment resources may be automated after ownership is proven.
- After a successful report, clean generated workspace files by default. On failure or interruption, preserve a minimal diagnostic bundle until the user confirms it is no longer needed.
- A Docker integration run exists to validate the changed behavior across its real service boundaries, not merely to prove that containers start or that one service answers a request.

## Execution Phases

Run these phases in order. A blocker in one phase stops later phases.

1. **PREFLIGHT**: identify the smallest complete integration scope, define the real entry point and real exit for the changed behavior, map every changed service boundary, inspect project docs and source runtime config, verify required tools, and prove the Docker context is local and intended.
2. **PREPARE**: create a unique run id, workspace, environment manifest, local-only overrides, mock configuration, and test data namespace outside the application repository.
3. **RENDER**: render effective configuration, such as `docker compose config`, and collect image, endpoint, mount, port, secret, network, and namespace evidence.
4. **SAFETY_GATE**: apply [references/safety-gate.md](references/safety-gate.md) and run `scripts/safety-gate.ps1 -Compact -OutFile <workspace>\safety-gate.json` against rendered JSON when available. Continue only with `ALLOW` or after every `REPLACE` is applied and rechecked; inspect full findings only for a reported blocker or required replacement.
5. **START**: start only the selected compose project and only after the gate has no blockers. Do not use global prune or cleanup commands.
6. **HEALTH_CHECK**: verify infrastructure readiness and record the actual container, network, volume, and port identities.
7. **FUNCTIONAL_TEST**: run the complete entry-to-exit business path for the changed behavior. Use the real entry point, real containers, real protocols, real downstream dependencies inside the changed path, and verify the real exit. Health checks, single-service checks, and mock-only checks are supplementary evidence and cannot produce a passing integration-test verdict for a cross-service change.
8. **REPORT**: use [references/report-template.md](references/report-template.md). Include browser URL and navigation steps when a human must inspect a UI.
9. **CLEANUP**: run `scripts/cleanup-guard.ps1 -Compact -OutFile <workspace>\cleanup-guard.json` when a manifest and resource inventory are available, then remove only resources proven by the manifest, project name, and labels to belong to this run. After failure or interruption, preserve the diagnostic bundle and perform only ownership-proven cleanup.

If generated or effective runtime config cannot prove that runtime endpoints are local and test-only, stop and report the blocker instead of starting containers. Do not stop merely because a checked-in source file contains production values that will be overridden in the generated test workspace.

Once the current environment is proven isolated through the manifest, compose project, and `com.qimomoli.test-run=<run_id>` label, do not ask the user to approve every test-internal operation. Automatically initialize, reset, seed, restart, and clean the current test containers and their scoped data as needed. Stop only when the operation could affect a resource outside the current environment.

## End-To-End Coverage Contract

Every integration run must declare an `END_TO_END` coverage path before starting functional tests:

```text
real entry point -> changed service(s) -> real downstream boundary(ies) -> real exit
```

- The **real entry point** is the user-visible action, public HTTP/RPC endpoint, published message, CLI command, or other boundary that the changed behavior actually receives. Do not start at an internal method when a real boundary is available.
- The **real exit** is the final observable business result: the response consumed by the caller, the visible UI state, the persisted state later read by the caller, or the event consumed by the next real service.
- If the change crosses services, start the required local services and exercise every changed boundary with the real protocol: HTTP, RPC, database, cache, broker, object storage, or service discovery as applicable. A mock cannot replace a changed service boundary.
- Mocks or stubs may cover only dependencies outside the changed path, such as an intentionally unavailable third-party payment or SMS provider. Record each one and explain why it is outside the changed behavior.
- A single-service test, direct database assertion, health endpoint, or mock-only test may supplement the run, but cannot be the primary integration evidence when the changed behavior crosses services.
- For asynchronous flows, wait for and verify the final business result after the message is consumed and downstream state is updated. “Message published” or “worker is healthy” is not an end-to-end pass.
- If the complete path cannot be exercised safely or the final result cannot be observed, classify the run as `partial` or `blocked`, identify the exact missing hop, and do not report `passed`.

## Current-Environment Operations

Once a resource is proven to belong to the current environment id through the manifest, compose project, and `com.qimomoli.test-run=<run_id>` label, the agent may automatically:

- initialize, reset, seed, or replace test database contents
- run `DROP`, `TRUNCATE`, scoped `DELETE`, migration, or init SQL against the current test database
- flush or clear current-environment caches
- clean test-only queue, broker, or topic data
- reset test-only object-storage buckets
- restart or recreate current-environment containers
- remove current-environment containers, networks, and temporary workspace files

Ask the user only when the target cannot be proven to belong to the current environment, or when the action could affect shared infrastructure, production, another local run, host-wide Docker state, or unrelated local files.

Do not infer ownership from a name alone. If labels, manifest entries, or compose project identity disagree, stop and report the ambiguity.

## Defaults

Prefer:

- Docker service names for container-to-container traffic.
- `host.docker.internal` only when the target is a known service on the local host, its test port is recorded, and the callback cannot reach VPN, company, production, or shared infrastructure.
- `127.0.0.1`, localhost, or an explicit test-only LAN hostname for browser-facing URLs.
- Test image tags with `local`, `test`, or a run id, not release/prod tags.
- Compose project names, Docker networks, volume names, database names, topic prefixes, buckets, and test ids that include the environment id and clearly identify the run.
- Dynamically allocated per-environment host ports. Check for collisions before startup and record the actual mappings.

Require explicit user approval before:

- Removing Docker volumes that are not proven to belong to the current environment.
- Preserving a successful-run workspace, generated config, or logs beyond the normal report and cleanup.
- Using private LAN callbacks, host networking, `privileged`, Docker socket mounts, broad host path mounts, or other host namespace/privilege escalation.
- Binding to ports already used by existing local services.
- Reusing an existing environment id, compose project, database/schema, topic prefix, bucket, or fixed port set for a different requirement.

## Verification

At minimum:

- Generated compose renders with `docker compose config`.
- Safety gate reports no blockers on generated and effective runtime config using the decision protocol in the reference.
- Automated safety gate checks pass when a rendered compose JSON or equivalent machine-readable config is available.
- Environment identity is clear: run id, workspace, manifest, compose project, resource labels, actual port mappings, data namespace, and cleanup behavior.
- Docker context is local and intended; `DOCKER_HOST` is absent or explicitly approved as local.
- Infrastructure health checks pass before application tests.
- Application tests start at the real entry point and verify the complete changed behavior through the real exit, not just process liveness or one service's response.
- Every changed cross-service boundary is exercised with a real protocol and a real local dependency, unless it is explicitly outside the changed path and documented as a mock or stub.
- The report includes the `END_TO_END` coverage path, per-hop evidence, real service boundaries, final observable result, and any missing hop.
- Single-service, unit, contract, or mock tests are reported as supplementary checks and never substituted for required cross-service integration coverage.
- Browser-facing URLs use `127.0.0.1`, localhost, an explicitly chosen LAN host, or a test-only hostname that a human can open. Do not present Docker-only service names as frontend URLs for manual confirmation.
- Frontend smoke tests verify the user can reach the target page and see the target effect. If the page cannot be viewed, report the exact step where it fails and whether the cause is missing config, missing data, missing permission, bad route, or backend/API failure.
- The final response includes a concise test report directly in the conversation. Do not require a separate report file unless the user asks for one.
- The test report is concise and human-readable. Lead with conclusion, URLs, navigation steps, results, blockers, cleanup result, and next actions. Do not paste long logs; include short relevant excerpts before cleanup, and include log paths only when logs were explicitly preserved.
- The test report records selected mode, run id, test time, workspace path while active, compose project, port mappings, data namespace, started services, frontend URLs when applicable, backend/API URLs, health checks, smoke tests, failed or blocked checks, skipped checks, manual verification items, preserved evidence, and cleanup result. Keep it roughly one to two screens unless there are many real failures.
- File creation, file deletion, diagnostic preservation, Docker lifecycle operations, runtime data changes, and publication actions honor `confirm-before-work` when that skill is active, or the built-in Side-Effect Confirmation protocol otherwise.
- When behavior does not match expectations, include failure symptom, expected result, actual result, likely cause, recommended fix, and the next verification step in the conversation.

## Common Mistakes

| Mistake | Correct action |
|---|---|
| Editing production config for a local test | Generate a test-only override outside the app repository |
| Treating source production values as an automatic blocker | Record them as override requirements and prove generated runtime config replaces them |
| Running a release compose file directly | Treat it as evidence and generate a local test compose |
| Reusing one local environment for multiple requirements | Generate a distinct environment id and isolated ports/names/data |
| Asking for approval for every isolated test reset | Prove the target belongs to the current environment, then run it |
| Trusting a health endpoint as full proof | Also test the cross-service behavior under review |
| Starting from an internal API or asserting only a database row | Begin at the real entry point and verify the real exit |
| Replacing a changed downstream service with a mock | Start the real local dependency and use its real protocol |
| Treating a published message or healthy worker as the final result | Wait for consumption and verify the final business-visible result |
| Calling a single-service smoke test an integration pass | Mark it supplementary; use `partial` or `blocked` when the complete path is not covered |
| Giving only a frontend URL | Include navigation steps, auth context, permissions, and test data |
| Producing a huge report | Summarize high-signal results and short log excerpts |
| Reporting a failure without guidance | Include likely cause, fix recommendation, and next verification step |
| Leaving generated files after a successful run | Report in conversation, then delete only the current environment workspace |
| Cleaning up aggressively after a failed run | Stop only the current compose project; ask before preserving or deleting evidence needed for debugging |
| Asking for approval for every isolated test reset | Verify the target belongs to the current environment and execute it automatically |
| Assuming Docker is local because the command works | Check `DOCKER_HOST`, `docker context show`, and the inspected endpoint before starting |
| Cleaning by resource name alone | Match the manifest, compose project, and `com.qimomoli.test-run` label |
| Deleting failure logs immediately | Preserve a minimal diagnostic bundle until the user confirms disposal |
