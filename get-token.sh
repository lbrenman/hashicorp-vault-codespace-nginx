#!/bin/bash
# Prints Vault credentials from the init file.
# Run this any time you need the root token.

INIT_FILE="/workspaces/vault-data/.vault-init"

if [ ! -f "$INIT_FILE" ]; then
  echo "Error: init file not found at $INIT_FILE"
  echo "Has Vault been started yet? Run: bash .devcontainer/start-vault.sh"
  exit 1
fi

ROOT_TOKEN=$(jq -r '.root_token' "$INIT_FILE")
UNSEAL_KEY=$(jq -r '.unseal_keys_b64[0]' "$INIT_FILE")

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║              VAULT CREDENTIALS                       ║"
echo "╠══════════════════════════════════════════════════════╣"
echo "║  Root Token   : $ROOT_TOKEN"
echo "║  Unseal Key   : $UNSEAL_KEY"
echo "║  Userpass     : demo / demo1234                      ║"
echo "║  Vault UI     : http://localhost:8200/ui              ║"
echo "║  Proxy (iPaaS): http://localhost:8100                 ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
