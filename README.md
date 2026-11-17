# Dhaba Orders (`dhaba-TEAM`)

Production microservices ordering system deployed on Kubernetes (k3s).

## Team Members
- Mujahid Zada (`orders-api`, CI/CD & Cluster Monitoring)
- Member 2 (`web`, `menu-api` & Ingress)
- Member 3 (`kitchen-worker`, `stats-api` & Stateful Storage)

## Links
- **Production:** http://TEAM.test
- **Staging:** http://staging.TEAM.test

## ECR Pull Credential Strategy (C9)
- **Mechanism:** GitHub Actions refreshes `ecr-pull-secret` via OIDC before every deployment, and an in-cluster `CronJob` (`ecr-token-refresh`) runs every 6 hours using a scoped IAM user (`AmazonEC2ContainerRegistryReadOnly`) stored in the `aws-ecr-refresher` Kubernetes Secret to mint fresh 12-hour ECR tokens without storing long-lived docker registry passwords.
- **Trade-offs & Risks:** Because the k3s cluster runs outside AWS, IAM Roles Anywhere or a least-privilege read-only IAM credential in a K8s Secret is required; risk is mitigated by scoping the IAM policy strictly to `ecr:GetAuthorizationToken` and `ecr:BatchGetImage` and restricting K8s RBAC to Secrets in the target namespace.
