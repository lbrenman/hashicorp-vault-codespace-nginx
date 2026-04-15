#!/bin/bash

REPO_DIR="/workspaces/$(basename $PWD)"
DATA_DIR="/workspaces/vault-data"
INIT_FILE="$DATA_DIR/.vault-init"
CONFIG="$REPO_DIR/vault-config/vault.hcl"

export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_DISABLE_MLOCK=true

# ── Install Vault ────────────────────────────────────────────────────────────
if ! command -v vault &>/dev/null; then
  echo "Installing HashiCorp Vault..."
  wget -q -O- https://apt.releases.hashicorp.com/gpg \
    | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
    https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
    | sudo tee /etc/apt/sources.list.d/hashicorp.list > /dev/null
  sudo apt-get update -qq && sudo apt-get install -y vault > /dev/null
  echo "Vault installed."
fi

# Remove IPC_LOCK capability — Codespaces blocks it
sudo setcap cap_ipc_lock=-ep $(which vault) 2>/dev/null || true

# ── Start Vault ───────────────────────────────────────────────────────────────
mkdir -p "$DATA_DIR"
echo "Starting Vault..."
nohup vault server -config="$CONFIG" > /tmp/vault.log 2>&1 &
echo $! > /tmp/vault.pid
sleep 5

# Verify Vault started
if ! curl -s http://127.0.0.1:8200/v1/sys/health > /dev/null 2>&1; then
  echo "⚠️  Vault failed to start. Check /tmp/vault.log"
  cat /tmp/vault.log
  exit 1
fi

# ── Initialize (first run only) ─────────────────────────────────────────────
if [ ! -f "$INIT_FILE" ]; then
  echo "First run — initializing Vault..."
  vault operator init \
    -key-shares=1 \
    -key-threshold=1 \
    -format=json > "$INIT_FILE" || { echo "Init failed"; cat /tmp/vault.log; exit 1; }
  chmod 600 "$INIT_FILE"
  echo "Vault initialized."
fi

# ── Unseal ───────────────────────────────────────────────────────────────────
UNSEAL_KEY=$(jq -r '.unseal_keys_b64[0]' "$INIT_FILE")
ROOT_TOKEN=$(jq -r '.root_token' "$INIT_FILE")

echo "Unsealing Vault..."
vault operator unseal "$UNSEAL_KEY" > /dev/null || { echo "Unseal failed"; exit 1; }

export VAULT_TOKEN="$ROOT_TOKEN"

# ── Bootstrap auth (first run only) ─────────────────────────────────────────
if ! vault auth list 2>/dev/null | grep -q "userpass"; then
  echo "Enabling userpass auth and creating demo user..."
  vault auth enable userpass
  vault policy write demo-policy "$REPO_DIR/policies/demo-policy.hcl"
  vault secrets enable -path=secret kv-v2
  vault write auth/userpass/users/demo \
    password="demo1234" \
    policies="demo-policy"
  echo "Bootstrap complete."
fi

# ── Install OpenResty ────────────────────────────────────────────────────────
if ! command -v /usr/local/openresty/nginx/sbin/nginx &>/dev/null; then
  echo "Installing OpenResty..."
  sudo apt-get install -y curl gnupg > /dev/null
  curl -fsSL https://openresty.org/package/pubkey.gpg \
    | sudo gpg --dearmor -o /usr/share/keyrings/openresty.gpg
  echo "deb [signed-by=/usr/share/keyrings/openresty.gpg] http://openresty.org/package/ubuntu $(lsb_release -cs) main" \
    | sudo tee /etc/apt/sources.list.d/openresty.list > /dev/null
  sudo apt-get update -qq
  sudo apt-get install -y openresty > /dev/null
  echo "OpenResty installed."
fi

# ── Start OpenResty ───────────────────────────────────────────────────────────
echo "Starting OpenResty proxy on port 8100..."
sudo pkill -f "openresty" 2>/dev/null || true
sudo pkill -f "nginx.*8100" 2>/dev/null || true
sudo rm -f /run/nginx-vault.pid /tmp/nginx.pid
sleep 1
sudo nohup /usr/local/openresty/nginx/sbin/nginx \
  -c "$REPO_DIR/nginx/nginx.conf" \
  -g 'daemon off;' > /tmp/nginx.log 2>&1 &
echo $! > /tmp/nginx.pid
sleep 2

# Verify OpenResty started
if ! curl -s http://127.0.0.1:8100/v1/sys/health > /dev/null 2>&1; then
  echo "⚠️  OpenResty failed to start. Check /tmp/nginx.log"
  cat /tmp/nginx.log
else
  echo "OpenResty started."
fi

# ── Write env vars to shell profile ─────────────────────────────────────────
grep -q "VAULT_ADDR" "$HOME/.bashrc" 2>/dev/null || \
  echo "export VAULT_ADDR='http://127.0.0.1:8200'" >> "$HOME/.bashrc"
grep -q "VAULT_DISABLE_MLOCK" "$HOME/.bashrc" 2>/dev/null || \
  echo "export VAULT_DISABLE_MLOCK=true" >> "$HOME/.bashrc"
grep -q "VAULT_TOKEN" "$HOME/.bashrc" 2>/dev/null && \
  sed -i "s|^export VAULT_TOKEN=.*|export VAULT_TOKEN='$ROOT_TOKEN'|" "$HOME/.bashrc" || \
  echo "export VAULT_TOKEN='$ROOT_TOKEN'" >> "$HOME/.bashrc"

# ── Print credentials ────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║              VAULT CREDENTIALS                       ║"
echo "╠══════════════════════════════════════════════════════╣"
echo "║  Root Token   : $ROOT_TOKEN"
echo "║  Userpass     : demo / demo1234                      ║"
echo "║  Vault UI     : http://localhost:8200/ui              ║"
echo "║  Proxy (iPaaS): http://localhost:8100                 ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "  To retrieve credentials later, run: bash get-token.sh"
echo ""
echo "✅ Vault + OpenResty are running!"
echo ""
echo "⚠️  The init file (unseal key + root token) is stored at:"
echo "   $INIT_FILE"
echo "   It is excluded from git via .gitignore."
