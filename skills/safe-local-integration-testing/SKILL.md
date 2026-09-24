---
name: safe-local-integration-testing
description: Use when preparing or running local Docker or container-based integration tests where production code/config, remote services, shared infrastructure, or unrelated local resources must not be modified.
---

# Safe Local Integration Testing

## Overview

Use this skill when an agent needs to run local integration tests with containers while keeping production code, production config, shared infrastructure, and unrelated local resources untouched. The core rule is: source config is evidence, generated runtime config is the gate.

Checked-in config may contain production endpoints or credentials. Record those values as local override requirements. Do not stop merely because they exist in source. Stop only when generated or effective runtime config still points at production, shared, remote, or unscoped resources.

## Core Boundaries

- Treat application repositories as read-only unless the user explicitly requests a code or config change.
- Do not edit checked-in env files, application config, Dockerfiles, compose files, migrations, or production runtime config just to make a local test work.
- Generate compose, env, mock config, seed data, and temporary logs in a separate workspace outside application repositories.
- Use a distinct environment id or run id for every concurrent requirement.
- Include that id in workspace paths, compose project names, container/network/volume names, host ports, database or schema names, service-discovery namespaces, object-storage buckets, queue or topic prefixes, test users, and test data ids.
- Do not connect to production or shared remote databases, caches, brokers, service discovery, object storage, auth, payment, SMS, API gateways, or customer data.
- Do not delete Docker volumes, prune images, remove unrelated containers, or clean data outside the current environment.
- After the conversation report is delivered, clean generated workspace files by default. Preserve logs or generated files only when the user asks, or when failure evidence must be kept and the user approves.

## Workflow

1. Identify the smallest integration scope that proves the change.
2. Read project docs and source runtime config as evidence.
3. Record production or remote defaults as override requirements.
4. Create an isolated test workspace with a unique environment id.
5. Generate local-only compose, env, seed, and mock config in that workspace.
6. Render effective config, such as `docker compose config`.
7. Apply [references/safety-gate.md](references/safety-gate.md) to generated files and effective runtime config.
8. Start only the selected environment's services after the gate has no blockers.
9. Run health checks before functional smoke tests.
10. If a browser UI is involved, provide the human-facing entry URL and steps to reach the target page.
11. Run current-environment initialization, reset, seed, restart, and cleanup automatically after ownership is proven.
12. Report concise results in the conversation, then clean temporary generated files unless preservation was approved.

## Current-Environment Operations

Once a resource is proven to belong to the current environment id, the agent may automatically:

- initialize, reset, seed, or replace test database contents
- run `DROP`, `TRUNCATE`, scoped `DELETE`, migration, or init SQL against the current test database
- flush or clear current-environment caches
- clean test-only queue, broker, or topic data
- reset test-only object-storage buckets
- restart or recreate current-environment containers
- remove current-environment containers, networks, and temporary workspace files

Ask the user only when the target cannot be proven to belong to the current environment, or when the action could affect shared infrastructure, production, another local run, host-wide Docker state, or unrelated local files.

## Verification

At minimum:

- Generated compose or equivalent runtime config renders successfully.
- Safety gate reports no blockers on generated and effective runtime config.
- Environment identity is clear: environment id, workspace while active, compose project, port mappings, data namespace, and cleanup behavior.
- Infrastructure health checks pass before application tests.
- Functional smoke tests exercise the behavior under test, not just process liveness.
- Browser-facing URLs are reachable by a human from the host machine.
- Frontend checks include entry URL, target page path, navigation steps, login or role, required permissions, required test data, expected visible result, and actual result.
- Failed or unexpected behavior includes symptom, expected result, actual result, likely cause, recommended fix, and next verification step.
- The final report is concise and delivered in the conversation. Do not create a report file unless the user asks.
- Cleanup result is reported.

## Common Mistakes

| Mistake | Correct action |
|---|---|
| Editing production config for a local test | Generate a test-only override outside the app repository |
| Treating source production values as an automatic blocker | Record them as override requirements and prove generated runtime config replaces them |
| Running a release compose file directly | Treat it as evidence and generate a local test compose |
| Reusing one local environment for multiple requirements | Generate a distinct environment id and isolated ports/names/data |
| Asking for approval for every isolated test reset | Prove the target belongs to the current environment, then run it |
| Trusting a health endpoint as full proof | Also test the cross-service behavior under review |
| Giving only a frontend URL | Include navigation steps, auth context, permissions, and test data |
| Producing a huge report | Summarize high-signal results and short log excerpts |
| Leaving generated files after a successful run | Report in conversation, then delete the current environment workspace |
