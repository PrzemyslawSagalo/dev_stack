# Code Quality Standards

### 📐 Rule: Dependency Injection over Environment Branching

Never use boolean flags (e.g., `USE_SANDBOX`, `IS_DEV`) to branch logic for different environments or mock services.

Code should remain entirely agnostic to the environment it is running in. If an external service needs to be mocked, sandboxed, or rerouted, do not embed if/else logic inside the client or application code. Instead, control the connection dynamically by externalizing the Base URLs or endpoints via Environment Variables (e.g., `API_BASE_URL`).

❌ **Anti-Pattern (Do not do this):**

```python
# Bad: Hardcoding environment logic and branching behavior
if settings.use_sandbox:
    base_url = "https://sandbox.api.com"
    headers["x-simulated-trading"] = "1"
else:
    base_url = "https://live.api.com"
```

✅ **Standard (Do this):**

```python
# Good: Application is completely ignorant of its environment
# The Base URL is injected via configuration (Docker Compose, Terraform, etc.)
self.client = httpx.AsyncClient(base_url=settings.api_base_url)
```
