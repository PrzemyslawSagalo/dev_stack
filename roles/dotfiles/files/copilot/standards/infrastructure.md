# Infrastructure Standards

## Scope

- Applies when organizing infrastructure-as-code, environment configuration, and secrets (unless a project mandates a framework-native layout such as Ansible `roles/` and `group_vars/`).

## Rules

### Infrastructure Isolation

- **Dedicated Directory:** Store infrastructure-as-code definitions (Terraform, CloudFormation, Kubernetes manifests) inside a dedicated `infrastructure/` directory.

### Environment Configuration

- **Environment Files:** Keep non-secret, environment-specific configurations (e.g., `dev.yaml`, `prod.yaml`) alongside infrastructure definitions in `infrastructure/`.

### Strict Secret Management

- **No Committed Secrets:** Never store unencrypted credentials, sensitive tokens, or private keys in `dev.yaml`, `prod.yaml`, or any version-controlled file.
- **Environment Injection:** Inject all secrets via environment variables, stored locally in `.env` files during development.
- **Gitignore Coverage:** Ensure `.env` and `.env.*` secret overrides (excluding `.env.example` and `.env.template`) are ignored in `.gitignore`.
