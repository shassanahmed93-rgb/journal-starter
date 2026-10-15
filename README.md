# Learn to Cloud Phase 3 Capstone: Journal API

[![CI](https://github.com/shassanahmed93-rgb/journal-starter/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/shassanahmed93-rgb/journal-starter/actions/workflows/ci.yml)

Welcome to [Learn to Cloud's](https://learntocloud.com) Phase 3 capstone. You will build a journal API with **FastAPI**, **PostgreSQL**, structured logging, input validation, and AI-powered entry analysis.

## Capstone

These chapters are designed to be completed in order. Each chapter builds on the previous one, so do not skip ahead.

1. [Check the prerequisites](docs/01-prerequisites.md)
2. [Set up the project](docs/02-project-setup.md)
3. [Run the API](docs/03-run-the-api.md)
4. [Build GET for one entry](docs/04-get-entry.md)
5. [Build DELETE for one entry](docs/05-delete-entry.md)
6. [Add input validation and debug a partial update](docs/06-input-validation.md)
7. [Use logs to understand the API](docs/07-logging.md)
8. [Set up an AI provider](docs/08-ai-setup.md)
9. [Build AI-powered analysis](docs/09-ai-analysis.md)
10. [Finish the capstone](docs/10-finish.md)

**[Start the capstone →](docs/01-prerequisites.md)**

## Reference

This additional reference material is available if you want to explore further or need help:

- [Testing and CI](docs/reference/testing-and-ci.md)
- [Troubleshooting](docs/reference/troubleshooting.md)
- [Sync your fork with upstream](docs/reference/upstream-sync.md)
- [Explore your database](docs/reference/explore-database.md)

> **Learning environment only:** Authentication uses shared bearer tokens and
> has no per-user data isolation. Do not store personal or sensitive journal
> content in it. Use the separate administrator token only for destructive
> operations.

## Build a local container image

Build the image with the current full commit SHA embedded as image metadata and
available to the API's `/version` endpoint:

```bash
docker build --pull \
  --build-arg GIT_SHA="$(git rev-parse HEAD)" \
  -t journal-api:local .
```

The image installs the locked runtime dependencies. `.env` is excluded from the
build context; provide application settings to the container at runtime rather
than baking credentials into the image.

The Python and uv base images are pinned by digest. To update them safely,
select supported releases, resolve architecture-appropriate digests from the
trusted upstream registries, review release and security notes, update each
version and digest together, then rebuild with `--pull`, run the complete test
suite, and verify the image's `/version` response and metadata before merging.
Do not replace digest pins with floating tags.

Set distinct random URL-safe values of at least 32 characters for
`API_ACCESS_TOKEN` and `API_ADMIN_TOKEN` in the ignored local `.env` file.
Send them only over HTTPS using `Authorization: Bearer <token>`. The access
token authorizes ordinary journal operations; the administrator token is
required for either DELETE endpoint. These shared tokens do not provide
per-user data isolation.

## AWS deployment

The AWS configuration is deliberately parameterized. It creates a dedicated
VPC, private EKS worker subnets, ECR, EKS, encrypted private RDS PostgreSQL,
Secrets Manager database credentials, GitHub OIDC roles, CloudWatch
observability, an ACM certificate, and the Route 53 DNS validation records.
It does **not** create your public Route 53 hosted zone, publish an API DNS
alias, install the AWS Load Balancer Controller, or run Terraform on your
behalf. Do not put credentials, state, or real values in tracked files.

### Local checks and configuration

Use the devcontainer prerequisites in [Chapter 1](docs/01-prerequisites.md)
and the existing [testing reference](docs/reference/testing-and-ci.md). The
API needs PostgreSQL and the required settings shown in `.env-sample`; keep
actual values only in the ignored `.env` file or a secret manager. Run tests
with `uv run pytest`, code checks with `uv run ruff check .`,
`uv run ruff format --check .`, and `uv run pyright`.
`DATABASE_SSL=false` is suitable for the local compose database; production
sets it to `true`, and the RDS parameter group requires TLS for PostgreSQL
connections.

Install Terraform 1.10 or newer, AWS CLI, kubectl, and Helm locally. Authenticate
to the intended AWS account using a short-lived IAM Identity Center or assumed
role session. Before provisioning, choose:

- An AWS region with the selected EKS and PostgreSQL versions available.
- A globally unique S3 state-bucket name.
- A public DNS name in a Route 53 public hosted zone you control, delegated
  from your registrar.
- Egress CIDRs allowed to reach the EKS API. GitHub-hosted runner address
  ranges change; keep the allow-list current, or run deployment from a
  self-hosted runner with controlled egress. Do not use `0.0.0.0/0`.
- An OpenAI-compatible API base URL and model/deployment name.
- A notification email address for the CloudWatch 5xx alarm. Terraform creates
  an SNS email subscription; the recipient must confirm it before alerts are
  delivered.

Copy `terraform/state-bootstrap/terraform.tfvars.example` and
`terraform/terraform.tfvars.example` to local `terraform.tfvars` files in their
respective directories, replace every `REPLACE_...` value, and review them.
Those files and Terraform state are ignored by Git. Never put an AWS access key,
database password, or API key in either file.

### Protected Terraform state and infrastructure

The bootstrap module creates a private S3 bucket with versioning, server-side
encryption, public-access blocking, TLS-only bucket policy, and S3 lock files.
Use a unique name that you choose; no bucket or account identifier is embedded
in this repository.

```bash
cd terraform/state-bootstrap
umask 077
terraform init -backend=false
terraform plan -out=bootstrap.tfplan
terraform apply bootstrap.tfplan
```

After the bucket exists, copy `backend.s3.hcl.example` to
`backend.s3.hcl` in both `terraform/` and `terraform/state-bootstrap/`, then set
the bucket and region in those ignored files. Migrate the non-sensitive
bootstrap state into its separate S3 key:

```bash
terraform init -migrate-state -backend-config=backend.s3.hcl
cd ..
terraform init -backend-config=backend.s3.hcl
terraform fmt -check -recursive
terraform validate
terraform plan -out=production.tfplan
```

Review the plan locally before provisioning. Only when ready and authorized,
run `terraform apply production.tfplan`; this preflight and implementation
session do not execute that command. The RDS master password is generated by
Terraform and written to Secrets Manager; as with all Terraform-managed secret
resources, the value is present in Terraform state. Protect state-bucket IAM
access accordingly. EKS Kubernetes Secrets are encrypted using the cluster KMS
key.

The API certificate is an ACM DNS-validated certificate. Terraform adds the
ACM validation records to the existing Route 53 hosted zone. The domain must
be registered and delegated to that public zone. Once the Ingress provisions
an Application Load Balancer, create a Route 53 A/AAAA alias for the API name
to the ALB DNS name and hosted-zone ID reported by
`kubectl get ingress journal-api -n journal-api`. HTTPS should only be
considered ready after the alias resolves and the certificate validates.

### One-time cluster setup

The Terraform identity that creates EKS receives initial administrator access.
Use that administrative identity for the one-time namespace and controller
setup. The GitHub deploy role is restricted to edit access in the
`journal-api` and `observability` namespaces.

```bash
cd terraform
aws eks update-kubeconfig --region "$(terraform output -raw aws_region)" \
  --name "$(terraform output -raw cluster_name)"
kubectl apply -f ../k8s/namespace.yaml
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm upgrade --install aws-load-balancer-controller \
  eks/aws-load-balancer-controller \
  --version 1.13.3 \
  --namespace kube-system \
  --set clusterName="$(terraform output -raw cluster_name)" \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="$(terraform output -raw alb_controller_role_arn)"
```

Confirm the controller deployment is ready before enabling automated deploys.
It uses the Terraform-created IAM role through EKS OIDC; do not add static AWS
keys to Kubernetes or GitHub. Chart `1.13.3` pairs with controller `v2.13.3`;
the IAM action set in Terraform is aligned to the upstream policy for that
release's configured ALB ingress features. Review upstream policy changes
before upgrading the chart:
<https://github.com/kubernetes-sigs/aws-load-balancer-controller/blob/v2.13.3/docs/install/iam_policy.json>.

### GitHub configuration and deployment

In GitHub repository settings, configure these repository variables from
Terraform outputs and your selected settings:

| Variable | Value |
| --- | --- |
| `AWS_REGION` | Terraform `aws_region` output |
| `AWS_BUILD_ROLE_ARN` | Terraform `github_build_role_arn` output |
| `ECR_REPOSITORY` | Terraform `ecr_repository_name` output |

Configure these variables in the GitHub `production` environment:

| Variable | Value |
| --- | --- |
| `AWS_DEPLOY_ROLE_ARN` | Terraform `github_deploy_role_arn` output |
| `EKS_CLUSTER_NAME` | Terraform `cluster_name` output |
| `DATABASE_ADMIN_SECRET_ARN` | Terraform `database_admin_secret_arn` output |
| `DATABASE_APP_SECRET_ARN` | Terraform `database_app_secret_arn` output |
| `API_DOMAIN` | The domain supplied to Terraform |
| `ACM_CERTIFICATE_ARN` | Terraform `acm_certificate_arn` output |
| `OTEL_COLLECTOR_ROLE_ARN` | Terraform `otel_collector_role_arn` output |
| `OPENAI_BASE_URL` | Your provider's OpenAI-compatible API base URL |
| `OPENAI_MODEL` | Your provider's model/deployment name |
| `PRODUCTION_API_URL` | Real HTTPS API origin after it is provisioned and verified |

Create the GitHub `production` environment and require reviewer approval before
deployment, and restrict its allowed deployment branches to `main`. Add
`OPENAI_API_KEY`, `API_ACCESS_TOKEN`, and `API_ADMIN_TOKEN` as environment
secrets. Generate distinct URL-safe tokens at least 32 characters long and
rotate them by changing the environment secrets and rerunning deployment. The
environment's
`PRODUCTION_API_URL` variable must be the real public HTTPS URL, for example
`https://<your-owned-hostname>` only after DNS and HTTPS have been provisioned
and verified; do not set a guessed or placeholder production URL.

The workflow trusts only the configured repository's `main` branch for image
publishing through `AWS_BUILD_ROLE_ARN`; that role can only push to this ECR
repository and cannot read Secrets Manager or access EKS. The separate
`AWS_DEPLOY_ROLE_ARN` is configured in the protected `production` environment;
its OIDC trust requires the `production` environment identity and it can read
only the two database credential secrets and describe this cluster. GitHub
exchanges OIDC tokens for short-lived AWS credentials. On `main`, it builds and publishes
the image tagged with the full commit SHA, reads the database connection from
Secrets Manager without printing it, bootstraps a least-privilege PostgreSQL
role with a short-lived Kubernetes Job, removes the temporary admin Secret,
updates the runtime Secret, applies the collector, API, and Ingress resources,
and waits for rollout and Ingress reconciliation. The bootstrap Job and its
temporary Secret are deleted after the database role is provisioned. Pull
requests run tests and a local image build but do not receive AWS credentials.

The Ingress expects the AWS Load Balancer Controller installed above, an
ACM certificate in the same region, and a DNS alias configured after the ALB
appears. For the initial deployment, set `PRODUCTION_API_URL` to the HTTPS
origin using your owned `api_domain`; the workflow rejects a missing value or
anything other than an HTTPS origin. The first run creates the ALB, but the
Route 53 alias remains a manual step, so its post-rollout `/version` check will
fail until you create that alias and DNS/TLS are working. Get the ALB hostname
from the Ingress, create the Route 53 alias, wait for DNS propagation, then
rerun the same commit. Only a successful HTTPS `/version` check reporting the
full deployed commit SHA verifies the endpoint. Later deployments perform the
same check automatically.

### OpenTelemetry and operations

The application has a stable `service.name`/version resource, FastAPI HTTP
instrumentation, a custom version-lookup span, a request counter, request
duration histogram, and a 5xx counter. Application logs are structured JSON
on stdout. The EKS CloudWatch Observability add-on forwards those container
logs to CloudWatch Logs, so a second OpenTelemetry logs pipeline is not
required for this capstone and is intentionally not configured. It exports
OTLP traces and metrics to the in-cluster AWS
Distro for OpenTelemetry Collector. The collector sends traces to AWS X-Ray
and metrics through CloudWatch Embedded Metric Format. The EKS
CloudWatch Observability add-on collects container logs; application records
contain no configured secrets or journal text.

After deployment and normal traffic:

1. In X-Ray, open the service map and filter for `journal-api`; inspect a
   `journal.version.lookup` span and its `journal.version.configured` attribute.
2. In CloudWatch Metrics, open the `JournalAPI` namespace and inspect
   `journal_api_http_requests_total`,
   `journal_api_http_request_duration_seconds`, and
   `journal_api_http_5xx_total`.
3. In CloudWatch Logs, open the EKS Container Insights application log group
   `/aws/containerinsights/<cluster-name>/application` and find Journal API
   stdout records. Do not paste credentials or journal content into logs.
4. Open the `${name}-${environment}-operations` CloudWatch dashboard to view
   request counts per minute, p95 latency, and 5xx errors.
5. Terraform creates a `JournalAPI` HTTP 5xx CloudWatch alarm connected to the
   `${name}-${environment}-alarms` SNS topic and the email subscription from
   `alarm_notification_email`. Confirm the AWS SNS subscription email; until
   confirmed, delivery is not active. The email endpoint and confirmation
   require manual configuration.

Allow several minutes for metric export and CloudWatch metric discovery. An
alarm can initially show `INSUFFICIENT_DATA` until the metric is emitted.

### Cost and cleanup

This design incurs AWS charges even when idle: EKS cluster-hours, EC2 worker
nodes, an RDS instance (and a standby when Multi-AZ is enabled), one NAT
Gateway plus data processing, an internet-facing ALB, EBS, CloudWatch/X-Ray
ingestion, ECR storage, and Secrets Manager. The single NAT Gateway is a
cost-saving tradeoff, not an AZ-resilient egress design. Review AWS pricing and
create an AWS Budget before applying Terraform. Scale only after reviewing
availability and capacity implications.

No AWS resources have been provisioned by these instructions. For cleanup,
first take and verify any required database snapshot and export anything that
must be retained. The database and state bucket have Terraform deletion
protection and `prevent_destroy`; they are intentionally not removed by a
routine destroy. To retire the environment, first remove the GitHub production
environment and OIDC permissions, preserve/export state, then follow a
reviewed, resource-by-resource decommission plan. Only an authorized operator
should disable database/bucket protections and remove the Terraform lifecycle
guards before any destroy. Do not delete the state bucket until all dependent
Terraform resources are gone and the state backup is verified.

For local startup, test failures, and database setup, see
[Troubleshooting](docs/reference/troubleshooting.md).

## License

MIT License. See [LICENSE](LICENSE).
<!-- deployment retrigger -->

<!-- deployment retrigger -->
