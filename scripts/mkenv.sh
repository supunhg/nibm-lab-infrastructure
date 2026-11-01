#!/usr/bin/env bash
# Creates /opt/homelab/.env once (never overwrites). Existing DB passwords are carried over from the old compose file.
set -euo pipefail
ENV=/opt/homelab/.env
[ -f "$ENV" ] && { echo ".env exists, not touching"; exit 0; }
hex() { openssl rand -hex "${1:-24}"; }
alnum() { python3 -c "import secrets,string,sys;print(''.join(secrets.choice(string.ascii_lowercase+string.digits) for _ in range(int(sys.argv[1]))))" "$1"; }

NTFY_ADMIN_PASSWORD=$(hex 12)
NTFY_HASH=$(printf '%s\n%s\n' "$NTFY_ADMIN_PASSWORD" "$NTFY_ADMIN_PASSWORD" | docker run --rm -i binwiederhier/ntfy:v2.35.0 user hash 2>&1 | grep -o '\$2[ab]\$[^ ]*' | tail -1)
case "$NTFY_HASH" in '$2'*) ;; *) echo "ntfy hash failed: $NTFY_HASH" >&2; exit 1;; esac
NTFY_TOKEN="tk_$(alnum 29)"
NTFY_AUTH_PARAM=$(printf 'Bearer %s' "$NTFY_TOKEN" | base64 -w0 | tr '+/' '-_' | tr -d '=')

umask 077
cat > "$ENV" <<EOF
# /opt/homelab/.env - secrets for docker-compose.yml. chmod 600. Never commit.
ADMIN_EMAIL=admin@example.com

# existing (data already initialised with these)
N8N_DB_PASSWORD=CHANGE_ME_from_existing_data
FLARUM_DB_PASSWORD=CHANGE_ME_from_existing_data
FLARUM_DB_ROOT_PASSWORD=CHANGE_ME_from_existing_data
SPEEDTEST_APP_KEY=CHANGE_ME_from_existing_data

# authentik
AUTHENTIK_SECRET_KEY=$(openssl rand -base64 60 | tr -d '\n=+/')
AUTHENTIK_DB_PASSWORD=$(hex)
AUTHENTIK_BOOTSTRAP_PASSWORD=$(hex 12)
AUTHENTIK_BOOTSTRAP_TOKEN=$(hex 32)

# qdrant master key (signs per-user JWTs too)
QDRANT_API_KEY=$(hex 32)

# forgejo
FORGEJO_DB_PASSWORD=$(hex)
FORGEJO_SECRET_KEY=$(hex 32)
FORGEJO_INTERNAL_TOKEN=$(hex 32)
FORGEJO_ADMIN_PASSWORD=$(hex 12)

# paperless
PAPERLESS_DB_PASSWORD=$(hex)
PAPERLESS_SECRET_KEY=$(hex 32)
PAPERLESS_ADMIN_PASSWORD=$(hex 12)

# beszel
BESZEL_ADMIN_PASSWORD=$(hex 12)
BESZEL_AGENT_KEY=

# ntfy (admin login for the web/phone app + one publish token for services)
NTFY_ADMIN_PASSWORD=$NTFY_ADMIN_PASSWORD
NTFY_AUTH_USERS='admin:$NTFY_HASH:admin'
NTFY_AUTH_TOKENS='admin:$NTFY_TOKEN:services'
NTFY_PUBLISH_TOKEN=$NTFY_TOKEN
NTFY_AUTH_PARAM=$NTFY_AUTH_PARAM
EOF
chmod 600 "$ENV"
echo ".env created"
