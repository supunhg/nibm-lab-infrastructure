#!/usr/bin/env bash
# E2E: index-number usernames at registration, identity-bound forum/Forgejo sign-up, sync activation + offboarding.
set -uo pipefail
cd /opt/homelab; set -a; . ./.env; set +a
R="--resolve auth.lab:443:127.0.0.1 --resolve forum.lab:443:127.0.0.1 --resolve git.lab:443:127.0.0.1"
API="http://127.0.0.1:9100/api/v3"; AH="Authorization: Bearer $AUTHENTIK_BOOTSTRAP_TOKEN"
IDX="cotest261f-$(printf '%03d' $((RANDOM % 900 + 100)))"; EMAIL="$IDX@student.nibm.lab"; PW="Bind-Test-$(openssl rand -hex 4)x9"
HD=(-H "Content-Type: application/json" -H "Referer: https://auth.lab/")

enroll() { # username email -> component + message
  local J; J=$(mktemp); local F="https://auth.lab/api/v3/flows/executor/homelab-enrollment/?query="
  curl -sk $R -c $J -b $J "$F" >/dev/null
  curl -sk -L $R -c $J -b $J "${HD[@]}" "$F" -d "{\"component\":\"ak-stage-prompt\",\"username\":\"$1\",\"name\":\"Bind Test\",\"email\":\"$2\",\"password\":\"$PW\",\"password_repeat\":\"$PW\"}" \
    | jq -r '.component + " | " + ((.response_errors // {} | tostring)[0:150]) + (.error_message // "")'
  rm -f $J
}
echo "== registration rules"
echo -n "  'Bob123'              -> "; enroll "Bob123" "bob@x.lab"
echo -n "  'COTEST261F-001' (UC) -> "; enroll "COTEST261F-001" "uc@x.lab"
echo -n "  'cotest261f-01'       -> "; enroll "cotest261f-01" "short@x.lab"
echo -n "  '$IDX'      -> "; enroll "$IDX" "$EMAIL"
UPK=$(curl -s -H "$AH" "$API/core/users/?username=$IDX" | jq -r '.results[0].pk')
curl -s -H "$AH" "$API/core/users/$UPK/" | jq -c '{username, is_active, groups: [.groups_obj[].name]}'
echo -n "  same email again     -> "; enroll "cotest261f-998" "$EMAIL"
curl -s -o /dev/null -H "$AH" -H "Content-Type: application/json" -X PATCH "$API/core/users/$UPK/" -d '{"is_active":true}'
echo "  (admin approved $IDX)"

login() { # jar
  local F="https://auth.lab/api/v3/flows/executor/default-authentication-flow/?query="
  curl -sk $R -c $1 -b $1 "$F" >/dev/null
  curl -sk -L $R -c $1 -b $1 "${HD[@]}" "$F" -d "{\"component\":\"ak-stage-identification\",\"uid_field\":\"$IDX\"}" >/dev/null
  curl -sk -L $R -c $1 -b $1 "${HD[@]}" "$F" -d "{\"component\":\"ak-stage-password\",\"password\":\"$PW\"}" | jq -r .component
}

echo "== forum.lab"
echo -n "  anonymous            -> "; curl -sk $R -o /dev/null -w "%{http_code} %{redirect_url}\n" https://forum.lab/ | cut -c1-80
J=$(mktemp); echo -n "  lab login            -> "; login $J
page=$(curl -sk $R -c $J -b $J -L https://forum.lab/); echo -n "  forum page           -> "; echo "$page" | grep -oE "<title>[^<]*" | head -1
CSRF=$(echo "$page" | grep -oE '"csrfToken":"[^"]+"' | head -1 | cut -d'"' -f4)
reg() { curl -sk $R -c $J -b $J -o /tmp/reg.out -w "%{http_code}" -H "Content-Type: application/json" -H "X-CSRF-Token: $CSRF" \
        https://forum.lab/register -d "{\"username\":\"$1\",\"email\":\"$2\",\"password\":\"$PW\"}"; echo -n " $(jq -r '.errors[0].detail // .data.attributes.username // empty' /tmp/reg.out 2>/dev/null | head -c 90)"; }
echo -n "  register 'someoneelse' -> "; reg someoneelse "$EMAIL"; echo
echo -n "  register other email   -> "; reg "$IDX" "other@x.lab"; echo
echo -n "  register matching      -> "; reg "$IDX" "$EMAIL"; echo
rm -f $J

echo "== git.lab"
echo -n "  sign_up anonymous    -> "; curl -sk $R -o /dev/null -w "%{http_code}\n" https://git.lab/user/sign_up
echo -n "  repo browsing (git)  -> "; curl -sk $R -o /dev/null -w "%{http_code}\n" https://git.lab/explore/repos
J=$(mktemp); login $J >/dev/null
form=$(curl -sk $R -c $J -b $J -L https://git.lab/user/sign_up); GC=$(echo "$form" | grep -oE 'name="_csrf" value="[^"]+"' | head -1 | cut -d'"' -f4)
gsu() { curl -sk $R -c $J -b $J -o /tmp/gsu.out -w "%{http_code}" --data-urlencode "_csrf=$GC" --data-urlencode "user_name=$1" \
        --data-urlencode "email=$2" --data-urlencode "password=$PW" --data-urlencode "retype=$PW" https://git.lab/user/sign_up; }
echo "  sign_up form loaded   -> $([ -n "$GC" ] && echo yes || echo NO)"
echo -n "  sign_up 'someoneelse' -> "; gsu someoneelse "$EMAIL"; echo " $(grep -oE 'Username must[^<]*' /tmp/gsu.out | head -1)"
echo -n "  sign_up matching      -> "; gsu "$IDX" "$EMAIL"; echo
rm -f $J

echo "== sync"
sudo /usr/bin/python3 /usr/local/sbin/lab-account-sync | sed 's/^/  /'
F_STATE=$(docker exec -i flarum-db sh -c 'mariadb -uroot -p"$MYSQL_ROOT_PASSWORD" flarum -N -B' <<<"select is_email_confirmed from flarum_users where username='$IDX';")
G_STATE=$(docker exec forgejo-db psql -U forgejo -tAc "select is_active || '/' || prohibit_login from \"user\" where lower_name='$IDX'")
echo "  forum confirmed=$F_STATE  git active/prohibited=$G_STATE"
echo "  -- admin disables lab account"
curl -s -o /dev/null -H "$AH" -H "Content-Type: application/json" -X PATCH "$API/core/users/$UPK/" -d '{"is_active":false}'
sudo /usr/bin/python3 /usr/local/sbin/lab-account-sync | sed 's/^/  /'
echo "  git active/prohibited=$(docker exec forgejo-db psql -U forgejo -tAc "select is_active || '/' || prohibit_login from \"user\" where lower_name='$IDX'")"
echo -n "  forum for disabled user -> "; J=$(mktemp); login $J; rm -f $J

echo "== cleanup"
curl -s -o /dev/null -H "$AH" -X DELETE "$API/core/users/$UPK/"
docker exec -u git forgejo forgejo admin user delete --username "$IDX" --purge >/dev/null 2>&1 && echo "  git user removed"
docker exec -i flarum-db sh -c 'mariadb -uroot -p"$MYSQL_ROOT_PASSWORD" flarum' <<<"delete from flarum_users where username='$IDX';" && echo "  forum user removed"
