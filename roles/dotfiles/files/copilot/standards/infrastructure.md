# General Project & Infrastructure Standards

## Infrastructure Requirements (12-Factor Compliant)

1. **Infrastructure Isolation:** 
   All infrastructure scripts (Terraform, CloudFormation, Kubernetes manifests, etc.) MUST be contained within a dedicated `infrastructure/` directory.

2. **Environment Configuration:** 
   Environment-specific configurations (e.g., `dev.yaml`, `prod.yaml`) MUST be stored alongside the infrastructure scripts within the `infrastructure/` directory.

3. **Strict Secret Management:**
   * Storing unencrypted credentials, sensitive tokens, or private auth keys inside configuration files (such as `prod.yaml`) or version-controlled files is prohibited.
   * All sensitive secrets MUST be injected via the environment and locally stored in `.env` files.
   * All `.env` files MUST be strictly added to the `.gitignore` to prevent committing them to version control.
