#!/usr/bin/env bash
# E2E: real Authentik login -> forward-auth -> home.lab; checks which dashboard each role receives.
set -uo pipefail
cd /opt/homelab; set -a; . ./.env; set +a
R="--resolve auth.lab:443:127.0.0.1 --resolve home.lab:443:127.0.0.1"
API="http://127.0.0.1:9100/api/v3"; AH="Authorization: Bearer $AUTHENTIK_BOOTSTRAP_TOKEN"

login_and_fetch() { # user pass -> prints dashboard title seen at home.lab
  local J; J=$(mktemp); local F="https://auth.lab/api/v3/flows/executor/default-authentication-flow/?query="
  curl -sk $R -c $J -b $J "$F" >/dev/null
  local C; C=$(awk '$6=="authentik_csrf"{print $7}' $J)
  local HD=(-H "Content-Type: application/json" -H "Referer: https://auth.lab/if/flow/default-authentication-flow/" -H "X-authentik-CSRF: $C")
  curl -sk -L $R -c $J -b $J "${HD[@]}" "$F" -d "{\"component\":\"ak-stage-identification\",\"uid_field\":\"$1\"}" >/dev/null
  local last; last=$(curl -sk -L $R -c $J -b $J "${HD[@]}" "$F" -d "{\"component\":\"ak-stage-password\",\"password\":\"$2\"}" | jq -r .component)
  local html; html=$(curl -sk $R -c $J -b $J -L --max-redirs 10 https://home.lab/)
  local title; title=$(echo "$html" | grep -oE "<title>[^<]*" | head -1 | sed 's/<title>//')
  local svc; svc=$(curl -sk $R -c $J -b $J https://home.lab/api/services | jq -r '[.[].name] | join(", ")' 2>/dev/null)
  echo "login=$last | title='$title' | groups: $svc"
  rm -f $J
}

echo -n "anonymous     -> "; curl -sk $R -o /dev/null -w "%{http_code} %{redirect_url}\n" https://home.lab/

# temporary student
PW="Stud3nt-Test-$(openssl rand -hex 4)"
SG=$(curl -s -H "$AH" "$API/core/groups/?name=students" | jq -r '.results[0].pk')
UPK=$(curl -s -H "$AH" -H "Content-Type: application/json" -X POST "$API/core/users/" \
  -d "{\"username\":\"gate-test-student\",\"name\":\"Gate Test\",\"is_active\":true,\"groups\":[\"$SG\"]}" | jq -r .pk)
curl -s -o /dev/null -H "$AH" -H "Content-Type: application/json" -X POST "$API/core/users/$UPK/set_password/" -d "{\"password\":\"$PW\"}"
echo -n "student       -> "; login_and_fetch gate-test-student "$PW"
curl -s -o /dev/null -H "$AH" -X DELETE "$API/core/users/$UPK/"

# no-group user must be denied
UPK=$(curl -s -H "$AH" -H "Content-Type: application/json" -X POST "$API/core/users/" -d '{"username":"gate-test-nogroup","name":"No Group","is_active":true}' | jq -r .pk)
curl -s -o /dev/null -H "$AH" -H "Content-Type: application/json" -X POST "$API/core/users/$UPK/set_password/" -d "{\"password\":\"$PW\"}"
echo; echo -n "no group      -> "; login_and_fetch gate-test-nogroup "$PW"
curl -s -o /dev/null -H "$AH" -X DELETE "$API/core/users/$UPK/"

echo -n "admin         -> "; login_and_fetch akadmin "$AUTHENTIK_BOOTSTRAP_PASSWORD"
echo -n "new signups land in: "; curl -s -H "$AH" "$API/stages/user_write/?name=homelab-enroll-write" | jq -r '.results[0].create_users_group_obj.name // .results[0].create_users_group'
