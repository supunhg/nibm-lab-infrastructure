#!/usr/bin/env bash
# Deploy Homepage theme files staged in /tmp/hp2 to /opt/homelab/homepage/config
set -euo pipefail
cd /opt/homelab/homepage/config
for f in settings.yaml widgets.yaml custom.css; do [ -f "$f.pre-redesign" ] || cp "$f" "$f.pre-redesign"; done
cp /tmp/hp2/settings.yaml /tmp/hp2/widgets.yaml /tmp/hp2/custom.css .
python3 - <<'EOF'
import yaml
p = "services.yaml"; s = open(p).read()
if "uptimekuma" not in s:
    s = s.replace("        container: uptime-kuma\n",
                  "        container: uptime-kuma\n        widget:\n          type: uptimekuma\n          url: http://uptime-kuma:3001\n          slug: services\n", 1)
    open(p, "w").write(s)
for f in ("services.yaml", "settings.yaml", "widgets.yaml", "bookmarks.yaml"):
    yaml.safe_load(open(f))
print("YAML_OK")
EOF
sleep 3
curl -s -o /dev/null -w "homepage %{http_code}\n" -H "Host: home.lab" http://127.0.0.1:3002/
curl -s -o /dev/null -w "custom.css %{http_code}\n" -H "Host: home.lab" http://127.0.0.1:3002/api/config/custom.css
docker logs homepage --since 1m 2>&1 | grep -iE "error|warn" | tail -4 | cut -c1-200 || true
# Homepage serves a cached page render; force it to rebuild with the new settings
curl -s -o /dev/null -w "revalidate %{http_code}\n" -H "Host: home.lab" http://127.0.0.1:3002/api/revalidate
