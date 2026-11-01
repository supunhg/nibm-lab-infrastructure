# Setup Guide — building the lab from scratch

How to reproduce this campus lab on your own hardware. Example addresses are placeholders: replace `192.168.1.10` (server), `10.147.17.10` (ZeroTier), `192.168.1.20` (NAS) with yours.

**Time:** about a day. **Skill:** comfortable with Linux, Docker and a browser admin UI.

---

## 0. What you get

- ~30 self-hosted services on one VM, all at `https://<name>.lab` behind one reverse proxy.
- **One identity** (Authentik): self-registration with admin approval, index-number usernames, groups that drive every access decision.
- Role-based dashboards (admin vs student), admin consoles behind SSO, per-user scoped API keys for the vector DB, identity-bound sign-up for apps with their own accounts, automatic offboarding.
- Firewall, fail2ban, pinned images, update alerts, push notifications, monitoring, nightly encrypted backups.

## 1. Hardware & hypervisor

- Any x86 server; this build: Dell PowerEdge, Xeon E5-2630 v4, VMware ESXi.
- VM: Ubuntu Server 24.04 LTS, 8 vCPU, 16 GB RAM, 100 GB disk (LVM), static IP.
- Optional: NAS with an SMB share for media and backups.

## 2. Base OS

```bash
sudo apt update && sudo apt full-upgrade -y
sudo apt install -y docker.io docker-compose-v2 fail2ban restic jq sqlite3 python3-markdown iptables-persistent
sudo usermod -aG docker $USER
```
Copy from this repo:
- `host/ssh/00-hardening.conf` → `/etc/ssh/sshd_config.d/` (keys only — **add your key first**), `sudo systemctl reload ssh`
- `host/fail2ban/jail.local` → `/etc/fail2ban/`
- `host/60-homelab.conf` → `/etc/sysctl.d/` (BBR, buffers, hardening), `sudo sysctl --system`
- `host/daemon.json` → `/etc/docker/daemon.json` (log rotation)
- `host/iptables/rules.v4|v6` → `/etc/iptables/` (edit the admin IP), then **reboot** — Docker rebuilds its own chains on top.

## 3. Remote access (optional)

ZeroTier: `curl -s https://install.zerotier.com | sudo bash && sudo zerotier-cli join <network>`; authorise the node in ZeroTier Central and give it a fixed IP. The firewall trusts the `zt+` interface.

## 4. The stack

```bash
sudo mkdir -p /opt/homelab && sudo chown $USER /opt/homelab && cd /opt/homelab
cp -r <repo>/* .
bash scripts/mkenv.sh            # generates .env with random secrets (chmod 600)
docker compose pull && docker compose up -d
```
Services and ports are documented inside `docker-compose.yml`. Every image is pinned.

## 5. DNS (*.lab)

AdGuard Home first-run: `http://<server>:3000`. Then *Filters → DNS rewrites*: add `<name>.lab → 192.168.1.10` for every host in `npm/gen-npm.sh`. Point lab PCs (or DHCP) at the server for DNS.

## 6. TLS + reverse proxy

- Certificates: `scripts/pki-issue.sh` creates a name-constrained root CA (only `.lab` + your private ranges) and a per-host certificate; install `ca.crt` on client devices. (A bare `*.lab` wildcard is never trusted by browsers because `.lab` is a public TLD.)
- Proxy hosts are **generated**, not clicked: `bash npm/gen-npm.sh npm/data/nginx/proxy_host && docker exec nginx-proxy-manager nginx -s reload`. Copy `npm/*.lua` to `npm/data/nginx/custom/`.

## 7. Identity (Authentik)

- `authentik/blueprints/homelab.yaml` is mounted into Authentik and applied automatically: groups, the approval-gated registration flow (index-number usernames, unique email), the Qdrant tiers and request flow, forward-auth apps for the dashboard, consoles, forum, Forgejo sign-up and Qdrant.
- After the first apply: `docker restart authentik-server` (the embedded outpost loads the providers).
- Create your admin: `docker exec authentik-worker ak create_recovery_key 60 <your-admin>` → open the link → set password + TOTP.

## 8. Dashboards

`homepage/` (admin) and `homepage-student/` (student) configs + shared `custom.css`/`custom.js`. One URL serves both: nginx maps the Authentik groups header to the right instance. After editing settings: `curl -H "Host: home.lab" http://127.0.0.1:3002/api/revalidate`.

## 9. Automation

```bash
sudo install -m 750 scripts/homelab-backup /usr/local/sbin/   # + host/systemd/homelab-backup.{service,timer}
sudo install -m 750 scripts/lab-account-sync.py /usr/local/sbin/lab-account-sync   # + lab-account-sync.{service,timer}
sudo install -m 755 scripts/qdrant-token /usr/local/bin/
sudo systemctl daemon-reload && sudo systemctl enable --now homelab-backup.timer lab-account-sync.timer
```
Initialise the restic repo once (`restic init`), keep `/root/.restic-password` in a password manager.

## 10. Monitoring & alerts

Uptime Kuma (probes + ntfy notification), Beszel (metrics), Dozzle (logs), Diun (new versions → ntfy). Subscribe your phone to the ntfy topics `homelab-alerts`, `homelab-auth`, `homelab-updates`.

## 11. Verify

```bash
bash scripts/test-dashboard-gate.sh      # admin vs student vs no-group routing
bash scripts/test-qdrant-tiers.sh        # reader / per-collection / manager keys enforced by Qdrant
bash scripts/test-identity-binding.sh    # registration rules, bound sign-ups, sync & offboarding
```

Then read the [Admin Guide](docs/ADMIN-GUIDE.md) for day-to-day operation.

---
*Supun Hewagamage · [@supunhg](https://github.com/supunhg)*
