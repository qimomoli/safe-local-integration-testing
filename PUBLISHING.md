# Publishing Checklist

Before publishing this skill to GitHub:

- Confirm `LICENSE` is present and matches the intended terms.
- Confirm the copyright holder is correct.
- Check that no private project names, repository paths, credentials, internal domains, screenshots, logs, or customer data are present.
- Keep project-specific service maps, ports, test accounts, business data, and environment-specific scripts in a separate private skill.
- Validate the skill frontmatter: `name` and `description` are required.
- Read `SKILL.md` and `references/safety-gate.md` as if you were a new user; remove anything that assumes one company's stack.
- Optionally add examples for common stacks, but keep them generic.
- Do not include generated test workspaces, logs, reports, screenshots, local env files, or Docker runtime artifacts.

Suggested repository name:

```text
safe-local-integration-testing
```

Suggested description:

```text
Agent skill for safe, isolated local Docker integration testing without touching production config or shared infrastructure.
```

Suggested topics:

```text
agent-skills docker integration-testing docker-compose local-development test-automation safety
```
