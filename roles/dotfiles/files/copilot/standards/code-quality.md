# Code Quality Standards

## Scope

- Applies when designing, implementing, or refactoring application, service, or client code across any language.

## Rules

### Dependency Injection over Environment Branching

- **No Environment Flags:** Never use boolean flags (e.g., `USE_SANDBOX`, `IS_DEV`) to branch application logic for different environments or mock services.
- **Externalized Configuration:** Inject service endpoints, base URLs, and credentials via external configuration or environment variables (e.g., `API_BASE_URL`) so code remains environment-agnostic.

## Examples

**Bad:**

```python
# Hardcoding environment branching inside application code
if settings.use_sandbox:
    base_url = "https://sandbox.api.com"
    headers["x-simulated-trading"] = "1"
else:
    base_url = "https://live.api.com"
```

**Good:**

```python
# Base URL is injected via external configuration
self.client = httpx.AsyncClient(base_url=settings.api_base_url)
```
