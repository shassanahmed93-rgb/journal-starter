---
name: preflight-check
description: Validate that the Journal API DevOps capstone is ready for submission. Check required files, Docker build, Terraform configuration, Kubernetes YAML, and CI/CD workflow. Fix issues when requested.
---

# Capstone Preflight Check

You are validating a Journal API DevOps capstone before submission.
Inspect the existing project, run the checks below using Bash, fix
problems you can safely fix, and rerun the checks.

Do not claim a check passed unless you ran it and observed success.
Do not expose, print, or commit secrets. Do not deploy cloud resources
or destroy infrastructure during this preflight check.

## 1. Inspect the project

Run:

```bash
pwd
find . -maxdepth 4 -type f \
  -not -path './.git/*' \
  -not -path './.venv/*' \
  -not -path './node_modules/*' | sort
```

Identify the actual application, infrastructure, and manifest paths.
Do not assume that the API entry point is `app/main.py`.

## 2. Check required files

Check for these capstone deliverables:

- Dockerfile
- .dockerignore
- requirements.txt or an equivalent dependency manifest
- .github/workflows/ci.yml
- terraform/*.tf
- Kubernetes YAML manifests under k8s/ or another documented directory
- README.md

Also inspect the application and tests for:

- GET /version returning {"commit": "<full commit SHA>"}
- A test suite and linting configuration
- OpenTelemetry instrumentation and exporter configuration
- Kubernetes Deployment, Service, HTTPS Ingress, TLS, and health probes
- Secure application configuration without committed credentials

Use Bash to report missing deliverables. If a file is missing, create
it only when its contents can be determined safely from the project.
Never invent cloud IDs, credentials, domains, or production endpoints.

## 3. Verify the Docker build

If Docker is installed and the Docker daemon is available, run:

```bash
docker build --pull -t journal-api:preflight .
```

Report the actual exit status. If Docker is unavailable, explain
what is missing and do not claim the build passed.

Inspect the Dockerfile for:

- A suitable Python base image
- Reproducible dependency installation
- Application listening on 0.0.0.0:8000
- Port 8000 exposure
- A GIT_SHA build argument and commit label or environment variable
- A startup command that launches the API
- No embedded credentials or unnecessary build context

Do not use real secrets as build arguments.

## 4. Validate Terraform

Locate the Terraform root module. Run:

```bash
terraform fmt -check -recursive terraform
terraform -chdir=terraform init -backend=false -input=false
terraform -chdir=terraform validate
```

If the Terraform root directory differs, adapt the commands accordingly.

The validation-only initialization must not create cloud infrastructure.
Do not run terraform apply or terraform destroy.

If formatting or validation fails, inspect and fix the configuration,
then rerun the failed checks. Explain any provider download or network
limitations separately from configuration errors.

## 5. Validate Kubernetes YAML

Locate all Kubernetes YAML files in the project. Use Python and PyYAML
if available to parse every manifest. For example:

```bash
python - <<'PY'
from pathlib import Path
import sys
import yaml

roots = [Path("k8s")]
files = []
for root in roots:
    if root.exists():
        files.extend(
            p for p in root.rglob("*")
            if p.is_file() and p.suffix.lower() in {".yaml", ".yml"}
        )

if not files:
    print("FAIL: No Kubernetes YAML manifests found.")
    sys.exit(1)

failed = False
for path in sorted(files):
    try:
        with path.open(encoding="utf-8") as stream:
            docs = list(yaml.safe_load_all(stream))
        if not docs or all(doc is None for doc in docs):
            raise ValueError("No YAML documents found")
        print(f"PASS: {path}")
    except Exception as exc:
        failed = True
        print(f"FAIL: {path}: {exc}")

sys.exit(1 if failed else 0)
PY
```

If PyYAML is missing, install it only in an appropriate isolated
environment or use an available YAML validator. Do not modify the
project's production dependencies just for this check.

Adapt the manifest directory if necessary. Validate Kubernetes
resource structure as well as YAML syntax when kubectl and a suitable
schema validator are available. YAML parsing alone does not prove that
Kubernetes will accept the resources.

## 6. Inspect the CI/CD workflow

Read .github/workflows/ci.yml and verify:

- Exactly one job has ID and display name `test`.
- Exactly one job has ID and display name `build`.
- Exactly one job has ID and display name `deploy`.
- build depends on test using needs: test.
- deploy depends on build using needs: build.
- The image is tagged with the full commit SHA.
- Deployment uses secure cloud authentication.
- deploy targets the production GitHub environment with the public
  HTTPS API URL.
- The deployment waits for Kubernetes rollout success.
- No long-lived credentials or real secrets are committed.

Do not claim that CI/CD or a production deployment works unless it
has actually been run and verified.

## 7. Fix and rerun

Fix issues that can be resolved safely from the existing project.
Preserve the application's intended behavior and avoid unrelated
refactoring.

Do not create cloud resources, change production infrastructure,
commit files, or push to GitHub without explicit authorization.

Rerun every available check after making fixes.

## 8. Final report

Provide a concise table with each check marked PASS, FAIL, or BLOCKED:

- Required files
- Docker build
- Terraform formatting
- Terraform validation
- Kubernetes YAML and schema validation
- CI/CD workflow requirements
- Version endpoint and commit SHA support
- Observability configuration

List every change made, every remaining issue, and any check blocked
by missing tools, credentials, network access, or infrastructure.

Distinguish local preflight success from actual GitHub Actions success
and production deployment verification.


## 9. Distinguish Local Checks from Production Verification

Report results in three separate categories.

### A. Local preflight checks
Run and report:
- Required files exist.
- Docker image builds successfully.
- Terraform formatting and validation pass.
- Kubernetes YAML parses successfully.
- Application tests pass.
- GET /version works locally, where practical.

These results prove only what was tested in the local environment.

### B. GitHub Actions verification
Do not mark this category PASS based on local tests.

Verify that:
- `.github/workflows/ci.yml` runs on the current `main` commit.
- Exactly one successful job exists for each required job ID:
  `test`, `build`, and `deploy`.
- The build publishes an image tagged with the full commit SHA.
- The deploy job records a successful deployment to the
  GitHub `production` environment.
- The deployment URL is the intended public HTTPS API address.

If GitHub access or workflow execution is unavailable, report BLOCKED.

### C. Production deployment verification
Send an HTTP request to the configured production URL:

```bash
curl --fail --silent --show-error \
  --max-time 15 \
  "$PRODUCTION_URL/version"
```

Confirm that the response contains the full commit SHA of the
current `main` commit.

Compare the returned SHA with:

```bash
git rev-parse HEAD
git rev-parse origin/main
```

Only report PASS if the deployed commit matches the current
`main` commit and HTTPS verification succeeds.

If the URL is unavailable, the service is not deployed, or the
commit does not match, report FAIL or BLOCKED as appropriate.

Never fabricate GitHub workflow results, deployment records,
HTTP responses, or commit SHAs.

### Final reporting rule

Provide separate statuses for:
1. Local preflight
2. GitHub Actions
3. Production deployment

A PASS in one category must never imply a PASS in another.

## 9. Distinguish Local Checks from Production Verification

Report three separate statuses.

### A. Local preflight
Run the available file checks, Docker build, Terraform formatting and validation, Kubernetes YAML validation, and application tests. Report only checks that actually ran.

### B. GitHub Actions verification
Verify the latest workflow run on the current main commit. Confirm exactly one successful job each with ID and display name `test`, `build`, and `deploy`. Confirm the image uses the full commit SHA and the deploy job records a successful deployment to the production environment.

If GitHub access or workflow execution is unavailable, report BLOCKED.

### C. Production deployment verification
Request the configured public HTTPS API URL's `/version` endpoint:

```bash
curl --fail --silent --show-error --max-time 15 \
  "$PRODUCTION_URL/version"
```

Compare the returned commit SHA with the current main commit. Use `git rev-parse HEAD` and `git rev-parse origin/main` when available. Fetch the latest main branch first if needed and safe to do so.

Report PASS only when the endpoint responds successfully over HTTPS and the returned full SHA matches the current main commit. Otherwise report FAIL or BLOCKED, explaining why.

### Final report
Show separate PASS, FAIL, or BLOCKED statuses for local preflight, GitHub Actions, and production deployment. Never claim that a check passed unless it was actually verified.
