RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

check_vault_json() {
  if [ ! -f .vault.json ]; then
    echo -e "${RED}Error: .vault.json not found. Copy .vault.json.example and fill in your values.${NC}" >&2
    exit 1
  fi
}

read_vault_addr() {
  VAULT_ADDR=$(jq -r '.addr // empty' .vault.json)
  if [ -z "$VAULT_ADDR" ]; then
    echo -e "${RED}[up.sh] Vault address is required. Set \"addr\" in .vault.json.${NC}" >&2
    exit 1
  fi
  export VAULT_ADDR
}

vault_login() {
  if [ -n "${VAULT_TOKEN:-}" ]; then
    echo -e "${GREEN}✔ Using VAULT_TOKEN from environment${NC}"
    return
  fi

  echo ""
  echo "? Which login method?"
  PS3="> "
  select METHOD in "Token" "Userpass" "LDAP"; do
    [ -n "$METHOD" ] && break
  done

  case $METHOD in
    Token)
      read -rsp "? Vault token: " VAULT_TOKEN; echo
      ;;
    Userpass)
      read -rp  "? Username: "   USERNAME
      read -rsp "? Password: "   PASSWORD; echo
      VAULT_TOKEN=$(curl -sf "${VAULT_ADDR}/v1/auth/userpass/login/${USERNAME}" \
        -d "{\"password\":\"${PASSWORD}\"}" | jq -r '.auth.client_token')
      ;;
    LDAP)
      read -rp  "? LDAP username: " USERNAME
      read -rsp "? LDAP password: " PASSWORD; echo
      VAULT_TOKEN=$(curl -sf "${VAULT_ADDR}/v1/auth/ldap/login/${USERNAME}" \
        -d "{\"password\":\"${PASSWORD}\"}" | jq -r '.auth.client_token')
      ;;
  esac
  export VAULT_TOKEN
}

# fetch_secrets <secret_path> [kv_version=2]
# Sets globals: RESPONSE, DATA
fetch_secrets() {
  local secret_path="$1"
  local kv="${2:-2}"
  local mount rest api_path

  mount=$(echo "$secret_path" | cut -d/ -f1)
  rest=$(echo "$secret_path"  | cut -d/ -f2-)

  if [ "$kv" -eq 2 ]; then
    api_path="${mount}/data/${rest}"
  else
    api_path="${secret_path}"
  fi

  RESPONSE=$(curl -sf "${VAULT_ADDR}/v1/${api_path}" \
    -H "X-Vault-Token: ${VAULT_TOKEN}") || {
    echo -e "${RED}[up.sh] Failed to fetch secrets from Vault at ${VAULT_ADDR}/v1/${api_path}${NC}" >&2
    echo -e "${RED}[up.sh] Check: Vault token valid? Secret path correct? Vault reachable?${NC}" >&2
    exit 1
  }

  if [ "$kv" -eq 2 ]; then
    DATA=$(echo "$RESPONSE" | jq -r '.data.data')
  else
    DATA=$(echo "$RESPONSE" | jq -r '.data')
  fi

  if [ -z "$DATA" ] || [ "$DATA" = "null" ]; then
    echo -e "${RED}[up.sh] Secret not found at path: ${api_path}${NC}" >&2
    exit 1
  fi
}

# Export every key=value from DATA into the current shell environment
export_secrets_to_shell() {
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    key="${line%%=*}"
    value="${line#*=}"
    export "$key=$value"
  done < <(echo "$DATA" | jq -r 'to_entries[] | "\(.key)=\(.value)"')
}

# write_env [KEY=value ...]
# Writes DATA key=values (if DATA is set) then any extra KEY=value args to .env
write_env() {
  rm -f .env
  {
    [ -n "${DATA:-}" ] && echo "$DATA" | jq -r 'to_entries[] | "\(.key)=\(.value)"'
    for var in "$@"; do
      printf "%s\n" "$var"
    done
  } > .env
}

deploy() {
  docker compose pull
  docker compose up -d --force-recreate
}
