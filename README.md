# HashiCorp Vault in GitHub Codespaces (with Nginx Basic Auth Proxy)

A ready-to-run HashiCorp Vault development environment using GitHub Codespaces, with persistent file storage, userpass authentication, and an Nginx reverse proxy that accepts HTTP Basic Auth for iPaaS tools like Amplify Fusion.

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/lbrenman/hashicorp-vault-codespace-nginx)

---

## What's Included

- HashiCorp Vault running with **persistent file storage** on port `8200`
- Secrets survive Codespace stop/start — stored in `/workspaces/vault-data/`
- Auto-unseal on every restart using the stored init file
- **Userpass auth** pre-configured with a demo user
- A sample **policy** scoped to `secret/data/demo/*`
- **Nginx reverse proxy** on port `8100` — accepts HTTP Basic Auth and converts it to a Vault token, enabling iPaaS tools that don't support native Vault token auth
- Vault UI accessible via forwarded port `8200`

---

## How the Nginx Proxy Works

Many iPaaS tools (including Amplify Fusion) only support HTTP Basic Auth. Vault natively uses token-based auth, so a direct connection doesn't work. The Nginx proxy bridges this gap:

1. Fusion sends a request to port `8100` with `Authorization: Basic <base64(username:password)>`
2. Nginx decodes the credentials and calls `POST /v1/auth/userpass/login/<username>` on Vault
3. Vault returns a client token
4. Nginx caches the token for 5 minutes, strips the `Authorization` header, adds `X-Vault-Token`, and proxies the request to Vault on port `8200`
5. Vault responds normally

---

## Quick Start

1. Click the **Open in GitHub Codespaces** button above
2. Wait for the Codespace to build and the startup script to finish (~2 min)
3. Open the **Ports** tab — both port `8200` (Vault UI) and port `8100` (proxy) will be forwarded and set to Public

---

## Credentials

| Field | Value |
|-------|-------|
| Root Token | Dynamic — run `bash get-token.sh` to retrieve |
| Username | `demo` |
| Password | `demo1234` |
| Vault UI | `http://localhost:8200/ui` |
| Proxy URL (for iPaaS) | `https://<codespace-name>-8100.app.github.dev` |

```bash
# Retrieve credentials at any time
bash get-token.sh

# Or get root token directly
cat /workspaces/vault-data/.vault-init | jq -r '.root_token'
```

---

## Amplify Fusion Connection Settings

| Field | Value |
|-------|-------|
| Base URL | `https://<codespace-name>-8100.app.github.dev` |
| Namespace | `root` |
| Authentication Type | `Basic` |
| Mount | `userpass` |
| Username | `demo` |
| Password | `demo1234` |

> Find your codespace name in the **Ports** tab — the forwarded address for port 8100 is your Base URL.

**How the proxy handles Fusion's requests:**

Fusion constructs auth requests as `POST /auth/<mount>/login/<username>` without the `/v1/` prefix. The Nginx proxy automatically rewrites these to the correct Vault path `POST /v1/auth/userpass/login/<username>` and adds the `/v1/` prefix to all other requests as needed. This happens transparently — no changes needed in Fusion.

---

## Ports

| Port | Purpose | Required |
|------|---------|----------|
| `8200` | Vault API and UI | Yes |
| `8100` | Nginx Basic Auth proxy (for iPaaS) | Yes — use this for external connections |
| `8201` | Vault cluster communication (HA/Raft) | No — single node setup, not needed |

---

## Using the CLI

```bash
# Check Vault status
vault status

# Log in as demo user
vault login -method=userpass username=demo password=demo1234

# Store a secret
vault kv put secret/demo/myapp api_key="abc123"

# Read it back
vault kv get secret/demo/myapp
```

---

## Project Structure

```
.
├── .devcontainer/
│   ├── devcontainer.json     # Codespace config — forwards ports 8200 and 8100
│   └── start-vault.sh        # Installs Vault + Nginx, bootstraps auth
├── vault-config/
│   └── vault.hcl             # File storage backend config
├── nginx/
│   └── nginx.conf            # Basic Auth → Vault token proxy config
├── policies/
│   └── demo-policy.hcl       # Sample Vault policy
├── get-token.sh              # Helper to print credentials
├── .gitignore
└── README.md
```

---

## Persistence

Vault data is stored in `/workspaces/vault-data/`, persisted by Codespaces across stop/start cycles. The `.vault-init` file contains the unseal key and root token — it is excluded from git and must never be committed.

> ⚠️ If you delete the Codespace entirely, `vault-data/` is lost and Vault will reinitialize from scratch on the next run.

---

## Adding More Users

```bash
vault write auth/userpass/users/newuser \
  password="newpassword" \
  policies="demo-policy"
```

## Adding More Policies

```bash
vault policy write my-policy policies/my-policy.hcl
```
