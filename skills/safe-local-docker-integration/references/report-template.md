# Integration Test Report

Use this compact structure in the final conversation response. Keep detailed evidence in the generated diagnostic bundle only when it must be retained.

```text
Verdict: passed | failed | blocked | partial
Scope: <behavior and services tested>
Coverage path: <real entry point -> changed service(s) -> real downstream boundary(ies) -> real exit>
Real service boundaries: <each changed cross-service boundary and real protocol exercised>
Per-hop evidence: <concise evidence from entry, each service boundary, downstream state, and final result>
Mock or stub: <none | dependency, boundary excluded, and why it is outside the changed path>
Environment: run_id=<id>, compose_project=<name>, docker_context=<local context>
Safety gate: passed | blocked | replaced values and rechecked
Tests: <functional assertions and concise results>
Frontend URL: <browser URL or not applicable>
Navigation: <route, login/role, permissions, and required data or not applicable>
Failures: <symptom, expected, actual, likely cause, recommended fix, next verification or none>
Cleanup: <resources removed and ownership proof, or blocked cleanup>
Preserved evidence: <diagnostic bundle path and retention reason, or none>
```

`passed` requires the complete `Coverage path` and a verified final result. A single-service check, health endpoint, direct database assertion, published-message assertion, or mock-only test cannot substitute for the changed cross-service path. Use `partial` or `blocked` when any required hop is missing.

Do not include secret values, production credentials, customer data, full environment dumps, or unredacted tokens.
