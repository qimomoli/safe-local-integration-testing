# Example Request

```text
Use safe-local-docker-integration to run a local Docker integration test for this feature.

Please:
- verify the Docker context and `DOCKER_HOST` target are local and intended
- create an isolated local test environment
- create an environment manifest and label owned resources with the run id
- do not modify checked-in production code or config
- override any production or remote defaults with local test endpoints
- do not copy production secrets or `.env` files into the test workspace
- run the smallest integration scope that proves the change
- if a frontend page is involved, give me the entry URL and steps to reach the target page
- keep the final test report short
- include failure symptoms, likely cause, recommended fix, and next verification step if anything fails
- clean successful runs after the report, but preserve a minimal diagnostic bundle for failed or interrupted runs
```
