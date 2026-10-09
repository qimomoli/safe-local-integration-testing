# Publishing Checklist

Before publishing this skill to GitHub:

- Confirm `LICENSE` is present and matches the intended terms.
- Confirm the copyright holder is correct.
- Check that no private project names, repository paths, credentials, internal domains, screenshots, logs, or customer data are present.
- Keep project-specific service maps, ports, test accounts, business data, and environment-specific scripts in a separate private skill.
- Validate the skill frontmatter: `name` and `description` are required.
- Read `SKILL.md` and `references/safety-gate.md` as if you were a new user; remove anything that assumes one company's stack.
- Run `tests/validate-skill.ps1` and `tests/run-safety-gate-tests.ps1`; ensure the safety contract, static safety gate, and cleanup ownership checks pass.
- Review every example and fixture for production endpoints, credentials, private domains, customer data, and unbounded cleanup commands.
- Confirm the skill states that it is an operating procedure, not a Docker or network security sandbox.
- Optionally add examples for common stacks, but keep them generic.
- Do not include generated test workspaces, logs, reports, screenshots, local env files, or Docker runtime artifacts.

Suggested repository name:

```text
safe-local-docker-integration
```

Suggested description:

```text
Agent skill for safe, isolated local Docker integration testing without touching production config or shared infrastructure.
```

Suggested topics:

```text
agent-skills docker integration-testing docker-compose local-development test-automation safety
```

## Recommended Repository Checks

Run the repository validation script before publishing:

```powershell
pwsh -NoProfile -File tests/validate-skill.ps1
pwsh -NoProfile -File tests/run-safety-gate-tests.ps1
```

For a production deployment, pair this skill with CI checks, Docker daemon access controls, network policy, image provenance, and project-specific service knowledge.
