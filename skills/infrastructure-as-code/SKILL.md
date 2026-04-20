---
name: infrastructure-as-code
description: Implement infrastructure as code CDK for cloud resource provisioning, module design, state management, and CI/CD integration
metadata:
  version: 1.4
  argument-hint: "cloud provider (AWS/GCP/Azure), tool (Terraform/CDK/Pulumi), infrastructure type (networking/database/compute/storage)"
---

Implement infrastructure as code for $ARGUMENTS.


## Tool Selection

| Tool | Language | Best for |
|------|----------|----------|
| Terraform | HCL | Multi-cloud, industry standard, large ecosystem |
| Pulumi | TS, Python, Go, C# | Developers preferring real languages |
| AWS CDK | TS, Python, Java, C# | AWS-native, construct ecosystem |
| CDKTF | TS, Python, Go, C# | Terraform + real language |

Decision: multi-cloud -> Terraform. AWS-only -> CDK. Prefer TS/C# over HCL -> Pulumi/CDKTF.

## Project Structure

```
infrastructure/
  modules/
    networking/       # main.tf, variables.tf, outputs.tf
    database/
    app-service/
  environments/
    dev/              # main.tf (calls modules), terraform.tfvars, backend.tf
    staging/
    production/
```

## Terraform

### Remote State

```hcl
terraform {
  backend "s3" {
    bucket         = "company-terraform-state"
    key            = "environments/production/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

### Module Design

```hcl
# modules/database/variables.tf
variable "name" {
  description = "Database instance name"
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,28}[a-z0-9]$", var.name))
    error_message = "4-30 lowercase alphanumeric or hyphens."
  }
}
variable "environment" { type = string }
variable "vpc_id"      { type = string }
variable "subnet_ids"  { type = list(string) }

# modules/database/main.tf
resource "aws_db_instance" "this" {
  identifier              = var.name
  engine                  = "postgres"
  engine_version          = "17"
  instance_class          = "db.t3.medium"
  storage_encrypted       = true
  backup_retention_period = var.environment == "production" ? 30 : 7
  deletion_protection     = var.environment == "production"
  tags                    = local.tags
}
```

Module rules: every module has `variables.tf`, `main.tf`, `outputs.tf`. Validation blocks on variables. Descriptions on all variables/outputs. Sensible defaults. Never hardcode AMI IDs or regions. Pin module versions.

### Environment Composition

```hcl
module "database" {
  source            = "../../modules/database"
  name              = "myapp-production"
  environment       = "production"
  vpc_id            = module.networking.vpc_id
  subnet_ids        = module.networking.private_subnet_ids
}
```

Separate directories per env (2-5 envs), Terragrunt for larger orgs.

### Import and Drift

- Import: `terraform import aws_db_instance.this myapp-production`, then match HCL, plan should show zero changes
- Drift: `terraform plan -detailed-exitcode` (exit 2 = drift). Run daily in CI, alert on drift.

## Pulumi (TypeScript)

```typescript
import * as aws from '@pulumi/aws';
import * as pulumi from '@pulumi/pulumi';

const environment = pulumi.getStack();

export function createDatabase(args: { name: string; subnetIds: pulumi.Input<string>[] }) {
  return new aws.rds.Instance(args.name, {
    engine: 'postgres', engineVersion: '17',
    instanceClass: environment === 'production' ? 'db.r6g.large' : 'db.t3.medium',
    storageEncrypted: true,
    deletionProtection: environment === 'production',
  });
}
```

Pulumi secrets: `pulumi config set --secret dbPassword value`. Encrypted in state.

## AWS CDK (TypeScript)

```typescript
export class DatabaseStack extends cdk.Stack {
  constructor(scope: cdk.App, id: string, props: DatabaseStackProps) {
    super(scope, id, props);
    new rds.DatabaseInstance(this, 'Database', {
      engine: rds.DatabaseInstanceEngine.postgres({ version: rds.PostgresEngineVersion.VER_17 }),
      vpc: props.vpc,
      storageEncrypted: true,
      deletionProtection: props.environment === 'production',
      removalPolicy: props.environment === 'production' ? cdk.RemovalPolicy.RETAIN : cdk.RemovalPolicy.DESTROY,
    });
  }
}
```

Use CDK Aspects for cross-cutting policies (enforce encryption, mandatory tags).

## Secret Management

- Never in `.tf`/`.ts`/`.yaml` files
- Use provider-native stores (Secrets Manager, Key Vault)
- Reference by ARN/ID, never by value
- Rotate on schedule, separate scopes per environment

## CI/CD (GitHub Actions)

```yaml
jobs:
  plan:
    steps:
      - uses: hashicorp/setup-terraform@v3
      - uses: aws-actions/configure-aws-credentials@v4
        with: { role-to-assume: ..., aws-region: us-east-1 }  # OIDC
      - run: terraform init && terraform plan -out=tfplan
      - name: Comment plan on PR  # post plan as PR comment
  apply:
    needs: plan
    if: github.ref == 'refs/heads/main'
    environment: production  # requires approval
    steps:
      - run: terraform init && terraform apply -auto-approve
```

Rules: plan on every PR, apply only on merge. OIDC auth. Require approval for production. Post plan as PR comment. Separate IAM roles for plan (read-only) and apply (write).

## Testing

- `terraform validate` + `terraform fmt -check` in CI on every PR
- Terratest for integration tests of critical modules (in isolated test account)
- Clean up with `defer terraform.Destroy`
- Test module outputs and optional variable defaults

## Anti-Patterns

- Secrets in IaC files or state -- readable by anyone with state access
- Single monolithic state file -- one broken resource blocks all others
- No drift detection -- manual changes accumulate silently until next apply fails

## Output Format

```
Tool:              [Terraform / Pulumi / CDK]
Cloud:             [AWS / Azure / GCP / multi-cloud]
State:             [backend and locking]
Modules:           [list with inputs/outputs]
Environments:      [list with promotion strategy]
Secrets:           [management approach]
CI/CD:             [plan/apply workflow and approvals]
Testing:           [validation, integration, drift]
```

## Done Criteria

- All infrastructure in code -- no manual creation
- Remote state with locking and encryption
- Modules reusable with clear interfaces and validation
- CI/CD: plan on PR, apply on merge with approval gates
- Secrets via provider-native stores, never in files
- Drift detection on schedule with alerting
- `terraform plan` shows zero changes after clean apply
- IAM least privilege for CI/CD roles
