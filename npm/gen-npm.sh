#!/usr/bin/env bash
# Generates hand-managed NPM proxy hosts (NOT in NPM's DB - edit here, never in the NPM UI).
# usage: bash gen-npm.sh <outdir>      e.g.  bash npm/gen-npm.sh npm/data/nginx/proxy_host && docker exec nginx-proxy-manager nginx -s reload
set -euo pipefail
OUT=${1:?outdir}
AK='set $authentik http://authentik-server:9000;'

head() { # name
cat <<EOF
# ------------------------------------------------------------
# $1  (hand-managed - /opt/homelab/npm/gen-npm.sh)
# ------------------------------------------------------------
server {
  listen 80;
  listen [::]:80;
  server_name $1;
  location = /nibm-ca.crt { alias /data/custom_ssl/nibm-root-ca.crt; default_type application/x-x509-ca-cert; }
  location / { return 301 https://\$host\$request_uri; }
}

server {
  listen 443 ssl;
  listen [::]:443 ssl;
  http2 on;
  server_name $1;

  ssl_certificate /data/custom_ssl/lab_wildcard.crt;
  ssl_certificate_key /data/custom_ssl/lab_wildcard.key;
  add_header Strict-Transport-Security "max-age=31536000" always;
  add_header X-Content-Type-Options nosniff always;
  add_header Referrer-Policy same-origin always;

  resolver 127.0.0.11 valid=30s ipv6=off;
  access_log /data/logs/proxy-host-$1_access.log proxy;
  error_log /data/logs/proxy-host-$1_error.log warn;
  location = /nibm-ca.crt { alias /data/custom_ssl/nibm-root-ca.crt; default_type application/x-x509-ca-cert; }
EOF
}

proxy_headers='    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-Scheme $scheme;
    proxy_set_header X-Forwarded-Proto  $scheme;
    proxy_set_header X-Forwarded-For    $remote_addr;
    proxy_set_header X-Real-IP          $remote_addr;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $http_connection;
    proxy_http_version 1.1;
    proxy_read_timeout 300s;'

# Authentik forward-auth blocks (official nginx snippet, upstream resolved at runtime)
authblocks='
  location /outpost.goauthentik.io {
    '"$AK"'
    proxy_pass              $authentik;
    proxy_set_header        Host $host;
    proxy_set_header        X-Original-URL $scheme://$http_host$request_uri;
    add_header              Set-Cookie $auth_cookie;
    auth_request_set        $auth_cookie $upstream_http_set_cookie;
    proxy_pass_request_body off;
    proxy_set_header        Content-Length "";
  }

  location @goauthentik_proxy_signin {
    internal;
    add_header Set-Cookie $auth_cookie;
    return 302 /outpost.goauthentik.io/start?rd=$scheme://$http_host$request_uri;
  }'

authreq='    auth_request     /outpost.goauthentik.io/auth/nginx;
    error_page       401 = @goauthentik_proxy_signin;
    auth_request_set $auth_cookie $upstream_http_set_cookie;
    add_header       Set-Cookie $auth_cookie;
    auth_request_set $authentik_username $upstream_http_x_authentik_username;
    auth_request_set $authentik_email $upstream_http_x_authentik_email;
    auth_request_set $authentik_name $upstream_http_x_authentik_name;'

simple() { # name upstream [max_body]
  { head "$1"; cat <<EOF
  client_max_body_size ${3:-100M};

  location / {
    set \$upstream $2;
$proxy_headers
    proxy_pass \$upstream;
  }
}
EOF
  } > "$OUT/$1.conf"
}

gated() { # name upstream [extra directives]  - Authentik forward-auth (who may pass is set per app in Authentik)
  { head "$1"; cat <<EOF
  client_max_body_size 1024M;
$authblocks

  location / {
$authreq
    set \$upstream $2;
$proxy_headers
    ${3:-}
    proxy_pass \$upstream;
  }
}
EOF
  } > "$OUT/$1.conf"
}

# ---- open (app has its own login, or is a public tool) ----
simple auth.lab       http://authentik-server:9000
simple docs.lab       http://paperless:8000 200M
simple metrics.lab    http://beszel:8090
simple ntfy.lab       http://ntfy:80
simple qdrant-api.lab http://qdrant:6333 500M   # SDK/API: Qdrant validates the api-key (per-user JWT)
simple jellyfin.lab   http://jellyfin:8096 100M
simple status.lab     http://uptime-kuma:3001
simple pdf.lab        http://stirling-pdf:8080 1024M
simple tools.lab      http://it-tools:80
simple draw.lab       http://excalidraw:80
simple speed.lab      http://speedtest-tracker:80
simple n8n.lab        http://n8n:5678 64M
simple onlynas.lab    http://192.168.1.20:5000 4096M   # Synology DSM

# mesh.lab: MeshCentral (TLS upstream; agents also connect by IP, so 192.168.1.10 is an alias)
simple mesh.lab https://meshcentral:4430 100M
sed -i -e 's/server_name mesh.lab;/server_name mesh.lab 192.168.1.10;/' \
       -e 's/^    proxy_pass \$upstream;/    proxy_ssl_verify off;\n    proxy_pass $upstream;/' "$OUT/mesh.lab.conf"

# ---- admin consoles: Authentik (homelab-admins) in front of the app's own login ----
gated portainer.lab http://portainer:9000
gated proxy.lab     http://127.0.0.1:81
gated dns.lab       http://adguardhome:80
gated crafty.lab    https://crafty_controller:8443 'proxy_ssl_verify off;'

# ---- member apps with their own accounts: identity-bound sign-up (username/email = NIBM lab account) ----
# forum.lab: whole forum is members-only (students + admins in Authentik); /register guarded.
{ head forum.lab; cat <<EOF
  client_max_body_size 64M;
$authblocks

  location = /register {
$authreq
    access_by_lua_file /data/nginx/custom/identity-guard.lua;
    set \$upstream http://flarum:8000;
$proxy_headers
    proxy_pass \$upstream;
  }

  location / {
$authreq
    set \$upstream http://flarum:8000;
$proxy_headers
    proxy_pass \$upstream;
  }
}
EOF
} > "$OUT/forum.lab.conf"

# git.lab: browsing/git-over-HTTPS use Forgejo's own login (git clients can't do SSO); only sign-up is gated + guarded.
{ head git.lab; cat <<EOF
  client_max_body_size 512M;
$authblocks

  location = /user/sign_up {
$authreq
    access_by_lua_file /data/nginx/custom/identity-guard.lua;
    set \$upstream http://forgejo:3000;
$proxy_headers
    proxy_pass \$upstream;
  }

  location / {
    set \$upstream http://forgejo:3000;
$proxy_headers
    proxy_pass \$upstream;
  }
}
EOF
} > "$OUT/git.lab.conf"

# ---- vault.lab: open app; /admin behind Authentik (homelab-admins) - Vaultwarden runs with DISABLE_ADMIN_TOKEN ----
{ head vault.lab; cat <<EOF
  client_max_body_size 525M;
$authblocks

  location /admin {
$authreq
    set \$upstream http://vaultwarden:80;
$proxy_headers
    proxy_pass \$upstream;
  }

  location / {
    set \$upstream http://vaultwarden:80;
$proxy_headers
    proxy_pass \$upstream;
  }
}
EOF
} > "$OUT/vault.lab.conf"

# ---- logs.lab: Dozzle in forward-proxy mode (homelab-admins only) ----
{ head logs.lab; cat <<EOF
$authblocks

  location / {
$authreq
    set \$upstream http://dozzle:8080;
$proxy_headers
    proxy_set_header Remote-User  \$authentik_username;
    proxy_set_header Remote-Email \$authentik_email;
    proxy_set_header Remote-Name  \$authentik_name;
    proxy_buffering off;
    proxy_pass \$upstream;
  }
}
EOF
} > "$OUT/logs.lab.conf"

# ---- qdrant.lab: dashboard + self-service token page ----
# Authentik mints a per-user JWT at login (mapping homelab-qdrant-jwt) and returns it as X-Qdrant-Key.
# access_by_lua runs after auth_request, so users without a grant get a friendly page instead of a 401.
qauth="$authreq
    auth_request_set \$qdrant_key     \$upstream_http_x_qdrant_key;
    auth_request_set \$qdrant_access  \$upstream_http_x_qdrant_access;
    auth_request_set \$qdrant_expires \$upstream_http_x_qdrant_expires;"
{ head qdrant.lab; cat <<EOF
  client_max_body_size 500M;
$authblocks

  location = /request { return 302 https://auth.lab/if/flow/qdrant-request/; }

  location = /my-token {
$qauth
    default_type text/html;
    content_by_lua_file /data/nginx/custom/qdrant-token-page.lua;
  }

  location / {
$qauth
    access_by_lua_block {
      if ngx.var.qdrant_key == nil or ngx.var.qdrant_key == "" then
        return ngx.redirect("/my-token")
      end
    }
    set \$upstream http://qdrant:6333;
$proxy_headers
    proxy_set_header api-key \$qdrant_key;
    proxy_set_header X-authentik-username \$authentik_username;
    proxy_pass \$upstream;
  }
}
EOF
} > "$OUT/qdrant.lab.conf"

# ---- home.lab: one URL, two dashboards; the Authentik groups header picks the instance ----
# map (not if/set) because rewrite-phase directives run before auth_request fills $authentik_groups.
{ cat <<'EOF'
map $authentik_groups $homepage_upstream {
  "~(^|\|)homelab-admins(\||$)" http://homepage:3000;
  default                       http://homepage-student:3000;
}

EOF
head home.lab; cat <<EOF
$authblocks

  # guides rendered by scripts/render-guides.py (any member / admins only)
  location = /guide {
$authreq
    default_type text/html;
    alias /data/nginx/custom/guides/student.html;
  }
  location = /admin-guide {
$authreq
    auth_request_set \$authentik_groups \$upstream_http_x_authentik_groups;
    access_by_lua_block {
      local g = ngx.var.authentik_groups or ""
      if not ("|" .. g .. "|"):find("|homelab-admins|", 1, true) then return ngx.exit(403) end
    }
    default_type text/html;
    alias /data/nginx/custom/guides/admin.html;
  }

  location / {
$authreq
    auth_request_set \$authentik_groups \$upstream_http_x_authentik_groups;
$proxy_headers
    proxy_pass \$homepage_upstream;
  }
}
EOF
} > "$OUT/home.lab.conf"
echo "generated: $(ls "$OUT" | tr '\n' ' ')"
