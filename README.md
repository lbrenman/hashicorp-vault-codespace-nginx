# HashiCorp Vault in GitHub Codespaces (with OpenResty Proxy)

A ready-to-run HashiCorp Vault development environment using GitHub Codespaces, with persistent file storage, userpass authentication, and an OpenResty reverse proxy that translates iPaaS requests (e.g. Amplify Fusion) into native Vault API calls.

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/lbrenman/hashicorp-vault-codespace-nginx)

---

## What's Included

- HashiCorp Vault running as a **systemd service** on port `8200` — restarts automatically if it crashes
- **Persistent file storage** — secrets survive Codespace stop/start, stored in `/workspaces/vault-data/`
- Auto-unseal on every restart using the stored init file
- **Userpass auth** pre-configured with a demo user
- A sample **policy** scoped to `secret/data/demo/*`
- **OpenResty reverse proxy** on port `8100` — translates Amplify Fusion's request paths to native Vault API paths
- Vault UI accessible via forwarded port `8200`

---

## How the Proxy Works

Amplify Fusion constructs Vault API requests using non-standard path formats and GitHub Codespaces strips the `Authorization` header. The OpenResty proxy on port `8100` handles both issues transparently:

| Fusion sends | Vault expects | Rewrite |
|---|---|---|
| `POST /auth/<mount>/login/<user>` | `POST /v1/auth/userpass/login/<user>` | Auth path rewrite |
| `GET /root/<path>` | `GET /v1/secret/data/<path>` | Secret path rewrite |
| Everything else | Pass through as-is | No rewrite |

---

## Quick Start

1. Click **Open in GitHub Codespaces** above
2. Wait for the Codespace to build and startup script to finish (~3-5 min first run, ~30s after)
3. Open the **Ports** tab — ports `8200` (Vault UI) and `8100` (proxy) are forwarded and set to Public automatically

---

## Credentials

| Field | Value |
|-------|-------|
| Root Token | Dynamic — run `bash get-token.sh` to retrieve |
| Username | `demo` |
| Password | `demo1234` |
| Vault UI | `http://localhost:8200/ui` |
| Proxy URL | `https://<codespace-name>-8100.app.github.dev` |

```bash
# Retrieve credentials at any time
bash get-token.sh

# Or get root token directly
cat /workspaces/vault-data/.vault-init | jq -r '.root_token'
```

> **Tip:** Log into the Vault UI using the **Username** method with `demo` / `demo1234` — no token needed.

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

> Find your Base URL in the **Ports** tab — copy the forwarded address for port `8100`.

---

## Ports

| Port | Purpose | Required |
|------|---------|----------|
| `8200` | Vault API and UI | Yes |
| `8100` | OpenResty proxy for iPaaS tools | Yes — use this for Fusion |
| `8201` | Vault cluster port (HA/Raft) | No — single node, not needed |

---

## Service Management

Both Vault and OpenResty run as background processes. To check status and manage them:

```bash
# Check if running
ps aux | grep vault | grep -v grep
ps aux | grep nginx | grep -v grep

# Check health
curl -s http://127.0.0.1:8200/v1/sys/health | jq .
curl -s http://127.0.0.1:8100/v1/sys/health | jq .

# View logs
tail -f /tmp/vault.log
tail -f /tmp/nginx.log
cat /tmp/nginx-access.log

# Restart everything
bash .devcontainer/start-vault.sh
```

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
│   ├── devcontainer.json     # Codespace config — ports, env vars, startup
│   └── start-vault.sh        # Installs and starts Vault + OpenResty as systemd services
├── vault-config/
│   └── vault.hcl             # Vault file storage backend config
├── nginx/
│   └── nginx.conf            # OpenResty path-rewriting proxy config
├── policies/
│   └── demo-policy.hcl       # Vault policy for demo user
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
