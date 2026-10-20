# Safety Gate

Use this gate before starting local Docker integration services and again before functional tests.

For rendered Docker Compose JSON, run `scripts/safety-gate.ps1` when available. The script is a static gate: it does not start Docker or clean resources; it writes a diagnostic artifact only when `-OutFile` is provided. It returns machine-readable JSON and exits with `0` for `ALLOW`, `10` for `REPLACE`, `20` for `ASK`, and `30` for `BLOCK`.

## Decision Protocol

Every checked item must produce one decision:

```text
decision: ALLOW | REPLACE | BLOCK | ASK
severity: INFO | WARN | HIGH | CRITICAL
source:
field:
observed:
reason:
required_action:
evidence:
```

- `ALLOW`: the target is local or explicitly test-only and ownership is proven.
- `REPLACE`: source evidence is acceptable, but generated runtime configuration must replace it before execution.
- `BLOCK`: do not start or continue; the target is unsafe or cannot be proven safe.
- `ASK`: pause for explicit user approval because the target is intentionally outside the default local-only boundary.

Unknown ownership, unknown Docker context, unknown credentials, and ambiguous fallback behavior default to `BLOCK`, not `ALLOW`.

## Docker Preflight

Before rendering or starting services:

- Check `DOCKER_HOST`. It must be unset or point to the intended local daemon.
- Run `docker context show` and inspect the selected context endpoint.
- Block remote Docker contexts, SSH endpoints, cloud contexts, and unknown endpoints unless the user explicitly approves the exact target and the test policy allows it.
- Record the Docker context, daemon endpoint summary, and run id in the environment manifest.
- Check that the required Docker and Compose commands are available.

## Evidence Phases

Use different decisions for source evidence and generated runtime config:

- **Source evidence:** checked-in `.env*`, `application*.yml`, compose files, Dockerfiles, docs, and release configs may contain production or remote values. Record those findings as `REPLACE` and generate local Docker overrides for them. Do not block solely because the source repository contains production information.
- **Generated or effective runtime config:** generated compose/env/config files, `docker compose config` output, process environment, service-discovery data, seeded runtime config, and live container/application config must be local-only. Any remaining production or remote endpoint here is a blocker.
- **Direct source use:** if a source repository config file is selected as an active runtime input without a generated local override, treat it as generated/effective runtime config for this gate.

## Cross-Service Integration Gate

The safety gate protects the environment; it does not make a single-service check equivalent to integration testing. Before functional testing, record an `END_TO_END` path:

```text
real entry point -> changed service(s) -> real protocol -> real downstream service(s) -> real exit
```

- For a cross-service change, the changed boundaries must be exercised with real protocols and real local containers or test-only dependencies. A mock cannot replace a changed service boundary.
- A health endpoint, direct internal API call, single-service smoke test, published-message assertion, or mock-only test is supplementary evidence. It is not sufficient for a `passed` integration verdict.
- For asynchronous paths, verify message consumption, downstream state transition, and the final caller-visible or business-visible result.
- Mocks or stubs are allowed only for dependencies outside the changed path, and the report must name them and explain the boundary they do not cover.
- If the real entry-to-exit path cannot be completed safely, return `partial` or `blocked`, identify the exact missing service boundary, and do not upgrade the result to `passed`.

## Blockers

Block the run when generated or effective runtime config contains:

- Public IPs, cloud domains, managed database or cache hosts, managed brokers, production service discovery, object storage endpoints, payment/SMS/auth gateways, or other shared remote services.
- Production credentials, access keys, tokens, certificates, namespaces, bucket names, customer data, or real topic prefixes.
- `network_mode: host`, `pid: host`, `ipc: host`, `privileged: true`, Docker socket mounts, broad workspace mounts, root filesystem mounts, sensitive `/proc` or `/sys` mounts, or production host paths.
- `cap_add`, `devices`, permissive `security_opt`, host user/group mappings, or other privilege escalation that is not required and explicitly scoped to the test.
- Release/prod image tags for locally built test services when the test is supposed to validate current local code.
- Unpinned or untrusted images when the test policy requires reproducibility, or a test service that silently falls back to a production image.
- External registries, image pulls, package mirrors, or proxy settings that are not explicitly approved for this run.
- SQL or scripts that can drop, truncate, delete, flush, or overwrite data when the target cannot be proven to be the current isolated test resource. These operations are allowed inside the current environment after ownership is proven.
- Any fallback path that uses remote infrastructure when local mocks or local service discovery are unavailable.
- Compose project names, Docker networks, container names, volume names, host ports, database/schema names, service-discovery namespaces, object-storage buckets, topic prefixes, or seeded test ids that are shared with another concurrent requirement or existing local integration run without explicit intent.
- Fixed host ports that are already occupied or could overwrite another run's service.
- Production `.env` files, secrets, certificates, tokens, or customer data copied into the generated workspace, process environment, mounts, arguments, or logs.

## Usually Allowed

Allowed by default when the report records the choice:

- `127.0.0.1`, `localhost`, Docker service names, and generated test-only hostnames.
- `host.docker.internal` only when the target is a known service on the local host, its test port is recorded, and the callback cannot reach VPN, company, production, or shared infrastructure.
- Newly created Docker networks, containers, and databases for the current test project.
- Dummy credentials confined to the current local stack.
- Initialization, reset, seed, `DROP`, `TRUNCATE`, scoped `DELETE`, cache flush, topic cleanup, and test-bucket cleanup scoped to the current environment id.

Private LAN addresses such as `10.*`, `172.16.*-172.31.*`, and `192.168.*` are not local by default. `BLOCK` or `ASK` unless the user explicitly approves the exact target and the report records the owner, purpose, credentials, data boundary, and why a local mock cannot be used.

## Ownership And Isolation

Cleanup and destructive setup are allowed only when all of these match:

- the current environment manifest
- the current compose project or equivalent
- the `com.qimomoli.test-run=<run_id>` label
- the actual resource identity returned by Docker or the backing service

Names alone are insufficient. A missing or conflicting label, manifest entry, or project identity is a blocker. Use dynamically allocated host ports where possible and record the actual mapping before starting functional tests.

## Secrets And Runtime Configuration

- Do not copy production `.env` files or secret stores into the generated workspace.
- Replace production values with dummy credentials or local mocks before the gate.
- Redact values in rendered configuration, logs, process-environment snapshots, and reports.
- Record the variable name, source, credential status, and decision, never the secret value.
- Treat secrets in `env_file`, Docker secrets, mounted configuration files, command-line arguments, and image build arguments as runtime inputs.

## Evidence To Record

For every blocker, override requirement, or important endpoint:

```text
component:
file or source:
setting:
target summary:
credential status: none | test | production | unknown
runtime role: database | cache | broker | discovery | object storage | api | callback | browser url
decision: ALLOW | REPLACE | BLOCK | ASK
reason:
required follow-up:
frontend entry url:
target page url or path:
navigation steps:
login account or role:
required permissions:
required test data:
expected visible result:
actual visible result:
missing config/data/permission, if blocked:
manual verification required: yes | no
report delivery: conversation | file requested
failure symptom:
expected result:
actual result:
likely cause:
recommended fix:
next verification step:
environment id:
compose project:
port mappings:
data namespace:
stop command:
cleanup result:
```

Redact secrets. Do not paste full tokens, passwords, or keys into chat or reports.
Record the Docker context and resource ownership evidence for every run.
Record the `END_TO_END` path, changed service boundaries, real protocol used at each boundary, per-hop evidence, final observable result, and any mock or stub used outside the changed path.

## Frontend And Browser URLs

When a run includes a web UI, frontend dev server, browser-based admin console, API docs page, video player, WebRTC/WHEP page, or any page a human must inspect:

- Include the browser-accessible URL in the report and final response.
- Include the steps from the entry URL to the target page, including login, role, menu path, route path, and any direct URL that is safe to use.
- Prepare or identify the required config and test data before asking the user to inspect the page.
- State what the user should manually confirm on that page and what visible result is expected.
- If the target page cannot be reached or viewed, report the exact failing step and whether it is blocked by missing config, missing data, missing permission, broken route, or backend/API failure.
- Do not provide container-only hostnames, Docker service names, or `host.docker.internal` as the primary human-facing URL unless that exact browser can resolve it.
- Prefer `http://127.0.0.1:<port>`, `http://localhost:<port>`, or a documented LAN/test hostname.

## Required Test Report

Every completed integration run produces a concise report in the conversation by default. Do not create a separate report file unless the user asks for one. Keep it readable for a human reviewer: one to two screens by default, with short excerpts instead of long log dumps. Include log paths only when logs were explicitly preserved. At minimum include:

- test mode and timestamp
- workspace path, while the workspace is still active
- compose/env/config files used
- started services and image tags
- frontend entry URL(s), target page path(s), and navigation steps, when applicable
- login account or role, permissions, and required test data, when applicable
- backend/API URL(s)
- health check results
- functional smoke test results
- blockers, failures, and skipped checks
- preserved diagnostic evidence and retention reason, when applicable
- cleanup result
- log file locations only when logs were explicitly preserved
- manual verification items and whether they remain pending

When a test does not match expectations, also include:

- failure symptom
- expected result
- actual result
- likely cause
- recommended fix
- next verification step

## Destructive Operations

When `confirm-before-work` is active, any diagnostic bundle, manifest, rendered config, log, screenshot, report, generated workspace, or cleanup deletion requires the confirmation flow before writing or deleting files. The permissions below define safety, not user confirmation.

Allowed without extra approval:

- Stop containers in the current generated compose project.
- Remove containers and networks for the current environment.
- Initialize, reset, seed, `DROP`, `TRUNCATE`, scoped `DELETE`, or otherwise replace data in a database proven to belong to the current environment.
- Clear cache, broker topic data, object buckets, discovery namespace data, or other state proven to belong to the current environment.
- Restart or recreate services in the current generated compose project.
- Delete generated workspace files for the current environment after the final conversation report, when the run succeeded or the user did not ask to preserve failure evidence.

Require explicit approval:

- Removing Docker volumes when ownership by the current environment is not proven.
- Preserving a successful-run workspace, generated config, or logs beyond the normal report and cleanup.
- Deleting generated workspaces that do not belong to the current environment id.
- Rebuilding images over an existing tag.
- Pulling from an external registry or using a remote package/image mirror when it is not already approved by the test policy.
- Running destructive operations against a shared, remote, or otherwise unscoped database, cache, broker, object-storage, or discovery resource.

Forbidden unless the user approves the exact target:

- `docker system prune`, `docker volume prune`, `docker image prune`.
- Cleanup against any endpoint not proven to belong to this local test run.

## Interruption And Failure

If startup, health checks, or functional tests fail, or the process is interrupted:

- stop only the current compose project when its ownership is proven
- preserve the minimal diagnostic bundle before deleting generated files, after completing any required file-write confirmation
- include rendered config, manifest, container status, relevant logs, test output, and the exact safety-gate decision
- do not retry destructive setup against an ambiguous target
- report what was cleaned and what was intentionally retained

## Cleanup Guard

Use `scripts/cleanup-guard.ps1` when a manifest and resource inventory are available. It verifies that every cleanup target appears in the manifest and carries matching `com.qimomoli.test-run` and compose-project labels. It does not delete resources; it only returns `ALLOW` or `BLOCK`.
