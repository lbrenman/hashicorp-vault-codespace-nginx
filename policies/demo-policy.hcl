# demo-policy.hcl
# Policy for the demo user — read/write access to secret/demo/*

path "secret/*" {
  capabilities = ["list"]
}

path "secret/data/demo/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/metadata/demo/*" {
  capabilities = ["list", "delete"]
}
