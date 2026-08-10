# openclaw

A Helm chart for OpenClaw

Configure provider credentials and auth tokens with `openclaw.extraEnv` or `openclaw.envFrom` so secrets can come from Kubernetes Secrets.

Example secret-backed install:

```yaml
openclaw:
  env:
    AUTH_USERNAME: admin
    OPENCLAW_ALLOWED_ORIGINS: https://openclaw.example.com
  extraEnv:
    - name: AUTH_PASSWORD
      valueFrom:
        secretKeyRef:
          name: openclaw
          key: auth-password
    - name: OPENCLAW_GATEWAY_TOKEN
      valueFrom:
        secretKeyRef:
          name: openclaw
          key: gateway-token
    - name: ANTHROPIC_API_KEY
      valueFrom:
        secretKeyRef:
          name: openclaw
          key: anthropic-api-key
persistence:
  enabled: true
  size: 10Gi
```
