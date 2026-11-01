# Operations — dell-node01

## Access model
| Who | Path | Reaches |
|---|---|---|
| Campus LAN | `https://<svc>.lab` via NPM (443), DNS 53/853, Minecraft 25565, git SSH 2222 | Web apps (each with own login or Authentik) |
| ZeroTier `10.147.17.0/24` | everything, incl. direct ports | Admin path |
| Admin workstation `192.168.1.50` | everything | Change in `/etc/iptables/rules.v4` if its IP changes, then reboot or `sudo netfilter-persistent reload && sudo systemctl restart docker` |
| SSH | `ssh -i ~/.ssh/claude_ubuntu_server admin@192.168.1.10` | keys only |

## Services added 2026-10-31
| Service | URL | ZeroTier | Purpose |
|---|---|---|---|
| Authentik 2026.8.5 | https://auth.lab | :9100 | SSO, self-registration with admin approval, forward-auth for qdrant.lab + logs.lab |
| Forgejo 17.0.1 | https://git.lab (SSH :2222) | :3003 | Git for staff/students. Self-registration, admin must activate (`REGISTER_MANUAL_CONFIRM`), sign-in required to view, repos private by default |
| Paperless-ngx 3.4.1 | https://docs.lab | :8010 | Document archive + OCR. Drop files into `/opt/homelab/paperless/consume` (subfolders become tags) |
| Beszel 0.21.1 | https://metrics.lab | :8092 | Host/container metrics history (agent over unix socket) |
| Dozzle 10.7.4 | https://logs.lab | — | Live container logs, `homelab-admins` only (no direct port by design) |
| ntfy 2.35.0 | https://ntfy.lab | :8093 | Push alerts. Topics: `homelab-alerts` (Kuma + backup), `homelab-updates` (Diun), `homelab-auth` (registrations) |
| Diun 4.33.1 | — | — | Daily 06:00 check for newer image tags |
| Qdrant API gateway | https://qdrant-api.lab | :6333 | SDK/API access with master key or `qdrant-token` JWT |

## Dashboard (home.lab) — role-based
One URL, two Homepage instances, chosen after Authentik login by the `X-authentik-groups` header (nginx `map` in `npm/gen-npm.sh`):
| Group | Sees | Instance |
|---|---|---|
| `homelab-admins` | everything (Workspace + Operations tabs, server stats) | `homepage` (also direct :3002 for ZeroTier/admin IP) |
| `students` | Forum, Forgejo, Excalidraw, Paperless, Vaultwarden, IT-Tools, Stirling PDF, n8n, Jellyfin, Speedtest | `homepage-student` (no port, no Docker socket) |
| no group | denied | — |

- Self-registrations land in `students` (inactive until an admin activates them).
- Make someone an admin: add them to `homelab-admins` in Authentik.
- After editing any dashboard settings: `curl -H "Host: home.lab" http://127.0.0.1:3002/api/revalidate` (admin) and `docker exec homepage-student wget -qO- --header "Host: home.lab" http://127.0.0.1:3000/api/revalidate` (student). Homepage caches renders.
- E2E check: `scripts/test-dashboard-gate.sh` (real logins as test student / no-group / admin).
- The dashboard only controls what is *shown*; each app still has its own login. Paperless and n8n accounts are created per user by the admin inside those apps.

## Qdrant access
Tiered and self-service — full procedure in [ADMIN-GUIDE.md §4](ADMIN-GUIDE.md#4-qdrant-access).
- Students request at https://qdrant.lab/request → `qdrant-pending` + ntfy alert. Admin grants `qdrant-readers` / `qdrant-users` + `qdrant_collections` attribute / `qdrant-managers`.
- At login Authentik mints a per-user JWT (`homelab-qdrant-jwt` mapping) → NPM sends it as `api-key`. Users copy their key from https://qdrant.lab/my-token.
- Manual key for a service account (server): `qdrant-token <name> r|m [days] [collections...]`.
  ```python
  QdrantClient(url="https://qdrant-api.lab", api_key="<token>", https=True, port=443, verify=False)  # verify=False until the *.lab CA is installed
  ```

## Config changes to existing services
- Stirling-PDF: `mem_limit 1536m` (JVM was sizing to 70 % of 16 GB host RAM).
- Speedtest: every 6 h instead of hourly; prune results older than 180 days.
- n8n: execution pruning (14 days / 20k), telemetry off, HTTPS editor/webhook URLs.
- Flarum DB: InnoDB buffer pool 256 MB, `skip-name-resolve`; Flarum real-IP from NPM.
- Qdrant: on-disk payloads, telemetry off, 4 search threads.
- All containers: `no-new-privileges`, log rotation via daemon default.
- Host: BBR + fq, larger TCP buffers, swappiness 10, kernel pointer/dmesg restriction, redirects off.

## Files
`/opt/homelab/docker-compose.yml` · `.env` (600) · `authentik/blueprints/homelab.yaml` · `npm/gen-npm.sh` · `/usr/local/sbin/homelab-backup` · `/usr/local/bin/qdrant-token` · `/etc/iptables/rules.v4` · pre-change copies: `*.pre-claude`, full snapshot `/var/backups/homelab/20261031-*`.
