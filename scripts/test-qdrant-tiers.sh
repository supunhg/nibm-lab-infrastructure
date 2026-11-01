#!/usr/bin/env bash
# E2E: Authentik login -> qdrant.lab per-user key -> permissions enforced by Qdrant; request flow; admin gates.
set -uo pipefail
cd /opt/homelab; set -a; . ./.env; set +a
R="--resolve auth.lab:443:127.0.0.1 --resolve qdrant.lab:443:127.0.0.1 --resolve qdrant-api.lab:443:127.0.0.1 --resolve portainer.lab:443:127.0.0.1"
API="http://127.0.0.1:9100/api/v3"; AH="Authorization: Bearer $AUTHENTIK_BOOTSTRAP_TOKEN"; PW="Tier-Test-$(openssl rand -hex 4)"
gid() { curl -s -H "$AH" "$API/core/groups/?name=$1" | jq -r '.results[0].pk'; }
mkuser() { # username groups-json attributes-json
  local pk; pk=$(curl -s -H "$AH" -H "Content-Type: application/json" -X POST "$API/core/users/" \
    -d "{\"username\":\"$1\",\"name\":\"$1\",\"email\":\"$1@test.nibm.lab\",\"is_active\":true,\"groups\":$2,\"attributes\":$3}" | jq -r .pk)
  curl -s -o /dev/null -H "$AH" -H "Content-Type: application/json" -X POST "$API/core/users/$pk/set_password/" -d "{\"password\":\"$PW\"}"
  echo "$pk"
}
login() { # user jar
  local F="https://auth.lab/api/v3/flows/executor/default-authentication-flow/?query="
  local HD=(-H "Content-Type: application/json" -H "Referer: https://auth.lab/")
  curl -sk $R -c $2 -b $2 "$F" >/dev/null
  curl -sk -L $R -c $2 -b $2 "${HD[@]}" "$F" -d "{\"component\":\"ak-stage-identification\",\"uid_field\":\"$1\"}" >/dev/null
  curl -sk -L $R -c $2 -b $2 "${HD[@]}" "$F" -d "{\"component\":\"ak-stage-password\",\"password\":\"$PW\"}" | jq -r .component
}
code() { curl -sk $R -o /dev/null -w "%{http_code}" "$@"; }
mytoken() { curl -sk $R -c $1 -b $1 -L https://qdrant.lab/my-token | tr -d '\n' | grep -oE '<textarea[^>]*>[^<]+' | sed 's/.*>//'; }

# fixtures
curl -sk $R -X PUT -H "api-key: $QDRANT_API_KEY" -H "Content-Type: application/json" https://qdrant-api.lab/collections/e2e_proj -d '{"vectors":{"size":4,"distance":"Cosine"}}' -o /dev/null
curl -sk $R -X PUT -H "api-key: $QDRANT_API_KEY" -H "Content-Type: application/json" https://qdrant-api.lab/collections/e2e_other -d '{"vectors":{"size":4,"distance":"Cosine"}}' -o /dev/null
S=$(gid students); RD=$(gid qdrant-readers); QU=$(gid qdrant-users); MG=$(gid qdrant-managers)
U1=$(mkuser e2e-none "[\"$S\"]" '{}')
U2=$(mkuser e2e-reader "[\"$S\",\"$RD\"]" '{}')
U3=$(mkuser e2e-proj "[\"$S\",\"$QU\"]" '{"qdrant_collections":{"e2e_proj":"rw"}}')
U4=$(mkuser e2e-manager "[\"$S\",\"$MG\"]" '{}')
PT='{"points":[{"id":1,"vector":[1,0,0,0]}]}'
for u in e2e-none e2e-reader e2e-proj e2e-manager; do
  J=$(mktemp); l=$(login $u $J); K=$(mytoken $J)
  if [ -z "$K" ]; then
    page=$(curl -sk $R -c $J -b $J -L https://qdrant.lab/my-token | grep -oE "<h1>[^<]+")
    dash=$(curl -sk $R -c $J -b $J -L -o /dev/null -w "%{http_code} @ %{url_effective}" https://qdrant.lab/dashboard)
    printf "%-12s login=%s | page: %s | dashboard: %s\n" $u "$l" "${page#<h1>}" "$dash"
  else
    printf "%-12s login=%s | key ok | list=%s read_proj=%s write_proj=%s write_other=%s create_coll=%s | dashboard=%s\n" $u "$l" \
      "$(code -H "api-key: $K" https://qdrant-api.lab/collections)" \
      "$(code -H "api-key: $K" https://qdrant-api.lab/collections/e2e_proj)" \
      "$(code -X PUT -H "api-key: $K" -H 'Content-Type: application/json' https://qdrant-api.lab/collections/e2e_proj/points -d "$PT")" \
      "$(code -X PUT -H "api-key: $K" -H 'Content-Type: application/json' https://qdrant-api.lab/collections/e2e_other/points -d "$PT")" \
      "$(code -X PUT -H "api-key: $K" -H 'Content-Type: application/json' https://qdrant-api.lab/collections/e2e_new -d '{"vectors":{"size":4,"distance":"Cosine"}}')" \
      "$(curl -sk $R -c $J -b $J -o /dev/null -w "%{http_code}" https://qdrant.lab/collections)"
  fi
  [ $u = e2e-none ] && { echo -n "             student on portainer.lab gate: "; curl -sk $R -c $J -b $J -o /dev/null -w "%{http_code}\n" -L https://portainer.lab/; }
  rm -f $J
done

# self-service request flow (as e2e-none)
J=$(mktemp); login e2e-none $J >/dev/null
F="https://auth.lab/api/v3/flows/executor/qdrant-request/?query="; HD=(-H "Content-Type: application/json" -H "Referer: https://auth.lab/")
curl -sk $R -c $J -b $J "$F" >/dev/null
CS=$(awk '$6=="authentik_csrf"{print $7}' $J); HD+=(-H "X-authentik-CSRF: $CS" -H "Cookie: authentik_csrf=$CS")
c=$(curl -sk -L $R -c $J -b $J "${HD[@]}" "$F" -d '{"component":"ak-stage-prompt","qdrant_purpose":"E2E test: RAG demo","qdrant_collections":"e2e_proj","qdrant_write":true}' | jq -r '.component + " " + ((.fields // [])|map(.label)|join(","))')
echo "request flow -> $c"
sleep 2
curl -s -H "$AH" "$API/core/users/$U1/" | jq -c '{groups: [.groups_obj[].name], request: .attributes.qdrant_request}'
echo -n "ntfy alert: "; curl -s -H "Authorization: Bearer $NTFY_PUBLISH_TOKEN" "http://127.0.0.1:8093/homelab-auth/json?poll=1&since=2m" | jq -r 'select(.title=="Qdrant access request") | .message' | head -1
rm -f $J

# cleanup
for p in $U1 $U2 $U3 $U4; do curl -s -o /dev/null -H "$AH" -X DELETE "$API/core/users/$p/"; done
for c in e2e_proj e2e_other e2e_new; do curl -sk $R -o /dev/null -X DELETE -H "api-key: $QDRANT_API_KEY" https://qdrant-api.lab/collections/$c; done
echo "cleaned up"
