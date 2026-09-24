# Safety Gate

Use this gate before starting local integration services and again before functional tests.

## Evidence Phases

Use different decisions for source evidence and generated runtime config:

- **Source evidence:** checked-in env files, application config, compose files, Dockerfiles, docs, release config, and deployment examples may contain production or remote values. Record those findings as `override-required`. Do not block solely because source contains production information.
- **Generated or effective runtime config:** generated compose/env/config files, rendered compose output, process environment, service-discovery data, seeded runtime config, and live container/application config must be local-only or explicitly test-only. Any remaining production or remote endpoint is a blocker.
- **Direct source use:** if a source config file is selected as an active runtime input without a local override, treat it as generated/effective runtime config.

## Blockers

Block the run when generated or effective runtime config contains:

- Public IPs, cloud domains, managed database hosts, managed cache hosts, managed brokers, production service discovery, production object storage, payment/SMS/auth gateways, or other shared remote services.
- Production credentials, real access keys, tokens, certificates, namespaces, bucket names, customer data, or real topic prefixes.
- `network_mode: host`, `privileged: true`, Docker socket mounts, broad host path mounts, root filesystem mounts, or production host paths.
- Production image tags for services that must validate current local code.
- Any fallback path that reaches remote infrastructure when local mocks or local service discovery are unavailable.
- Names, ports, databases, schemas, namespaces, buckets, topics, or seeded test ids shared with another concurrent requirement without explicit intent.
- Destructive SQL or cleanup scripts when the target cannot be proven to be the current isolated test resource.

## Usually Allowed

Allowed by default when the report records the choice:

- `127.0.0.1`, `localhost`, Docker service names, and generated test-only hostnames.
- `host.docker.internal` for container-to-host callbacks when appropriate.
- Newly created Docker networks, containers, databases, schemas, buckets, topics, and namespaces for the current environment.
- Dummy credentials confined to the current local stack.
- Initialization, reset, seed, `DROP`, `TRUNCATE`, scoped `DELETE`, cache flush, topic cleanup, and test-bucket cleanup scoped to the current environment id.

Private LAN addresses such as `10.*`, `172.16.*-172.31.*`, and `192.168.*` are not automatically safe. Allow them only when deliberately chosen for this test, documented, and not shared production infrastructure.

## Evidence To Record

For every blocker, override requirement, or important endpoint, record the relevant subset:

```text
component:
file or source:
setting:
target summary:
credential status: none | test | production | unknown
runtime role: database | cache | broker | discovery | object storage | api | callback | browser url
decision: blocked | override-required | allowed local | replaced
reason:
required follow-up:
environment id:
compose project or equivalent:
port mappings:
data namespace:
frontend entry url:
target page url or path:
navigation steps:
login account or role:
required permissions:
required test data:
expected visible result:
actual visible result:
failure symptom:
expected result:
actual result:
likely cause:
recommended fix:
next verification step:
cleanup result:
```

Redact secrets. Do not paste full tokens, passwords, or keys into chat or reports.

## Frontend And Browser URLs

When a run includes a web UI, frontend dev server, browser-based admin console, API docs page, video player, WebRTC page, or any page a human must inspect:

- Include the browser-accessible URL in the report.
- Include the steps from the entry URL to the target page.
- Include login, role, menu path, route path, and any direct URL that is safe to use.
- Prepare or identify required config and test data before asking the user to inspect the page.
- State what the user should manually confirm and what visible result is expected.
- If the target page cannot be reached or viewed, report the exact failing step and whether it is blocked by missing config, data, permission, route, or backend/API behavior.
- Do not provide container-only hostnames or Docker service names as the primary human-facing URL.

## Destructive Operations

Allowed without extra approval:

- Stop containers in the current generated compose project or equivalent environment.
- Remove containers and networks for the current environment.
- Initialize, reset, seed, `DROP`, `TRUNCATE`, scoped `DELETE`, or otherwise replace data in a database proven to belong to the current environment.
- Clear cache, broker topic data, object buckets, discovery namespace data, or other state proven to belong to the current environment.
- Restart or recreate services in the current environment.
- Delete generated workspace files for the current environment after the final conversation report.

Require explicit approval:

- Removing Docker volumes when ownership by the current environment is not proven.
- Preserving generated workspaces, generated configs, or logs after the run completes.
- Deleting generated workspaces that do not belong to the current environment id.
- Rebuilding images over an existing tag.
- Running destructive operations against shared, remote, production, or otherwise unscoped resources.

Forbidden unless the user approves the exact target:

- `docker system prune`, `docker volume prune`, or `docker image prune`.
- Cleanup against any endpoint not proven to belong to this local test run.
