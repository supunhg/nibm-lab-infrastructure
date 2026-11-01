# NIBM Lab — Administrator Guide

**Audience:** the lab administrator (technical assistant / IT staff).
**Scope:** everything needed to run the lab day to day and to hand it over. Browser tasks need no special tools. Steps marked **(server)** need SSH to the Ubuntu VM — see §15.

*Designed and built by Supun Hewagamage ([@supunhg](https://github.com/supunhg)), Technical Assistant, NIBM — 2026.*

---

## 1. The lab at a glance

```
Campus LAN ──► Sophos ──► Dell PowerEdge (ESXi 192.168.1.5)
                             └─ Ubuntu 24.04 VM "dell-node01"  192.168.1.10  (ZeroTier 10.147.17.10)
                                 ├─ Nginx Proxy Manager  :443  ── every https://<name>.lab address
                                 ├─ Authentik            ── one NIBM lab account per person, groups, approvals
                                 ├─ AdGuard Home :53      ── resolves *.lab for campus devices
                                 └─ 30+ apps in Docker    ── data in /opt/homelab/<app>
Synology NAS 192.168.1.20  ◄── nightly encrypted backups, Jellyfin media
```

Three ideas run everything:
1. **One identity.** Every person has one NIBM lab account in **Authentik** (https://auth.lab). Students' usernames are their **index numbers** (e.g. `cohndne251f-019`). The same username must be used in the forum and Forgejo — the proxy enforces it.
2. **Groups decide access.** Approve a person and put them in a group; dashboards, consoles and Qdrant follow automatically.
3. **Nothing changes silently.** Registrations, access requests, outages, failed backups and new versions all push to your phone (ntfy).

---

## 2. Every address

| Address | What | Who can open it | Sign-in |
|---|---|---|---|
| https://home.lab | Dashboard (admin view / student view) | lab members | NIBM lab account |
| https://auth.lab | Accounts, groups, approvals (Authentik) | everyone (admin UI: admins) | NIBM lab account |
| https://forum.lab | Student forum (Flarum) | lab members only | lab account, then forum account (same username) |
| https://git.lab | Git hosting (Forgejo) | anyone on campus can reach it; sign-up needs a lab account | Forgejo account (same username) |
| https://docs.lab | Document archive with OCR (Paperless-ngx) | users you create | Paperless account |
| https://vault.lab | Password manager (Vaultwarden, Bitwarden-compatible) | invited users | own vault |
| https://n8n.lab | Workflow automation | invited users | n8n account |
| https://jellyfin.lab | Media streaming | users you create | Jellyfin account |
| https://pdf.lab · https://tools.lab · https://draw.lab | Stirling PDF · IT-Tools · Excalidraw | anyone on campus | none (stateless) |
| https://speed.lab | Internet speed history | anyone (view); admin for settings | admin login |
| https://qdrant.lab | Vector DB dashboard + personal API key page | members (access per grant, §6) | lab account |
| https://qdrant-api.lab | Vector DB API for code | holders of a key | API key |
| https://portainer.lab | Containers (start/stop/logs/shell) | **admins** | lab admin, then Portainer |
| https://proxy.lab | Nginx Proxy Manager (certificates, legacy) | **admins** | lab admin, then NPM |
| https://dns.lab | AdGuard Home (DNS, `.lab` names, blocking) | **admins** | lab admin, then AdGuard |
| https://crafty.lab | Minecraft server manager | **admins** | lab admin, then Crafty |
| https://vault.lab/admin | Vaultwarden admin (invites) | **admins** | lab admin only |
| https://logs.lab | Live container logs (Dozzle) | **admins** | lab admin |
| https://status.lab | Uptime monitoring (public page: `/status/services`) | anyone (admin login for settings) | Kuma login |
| https://metrics.lab | CPU/RAM/disk history (Beszel) | admins | Beszel login |
| https://ntfy.lab | Push notifications server | admins | ntfy login |
| https://mesh.lab | Remote desktop / device management (MeshCentral) | admins | MeshCentral login |
| https://onlynas.lab | Synology DSM | NAS users | DSM login |
| https://home.lab/guide · /admin-guide | These guides | members · admins | lab account |

Direct ports (`http://10.147.17.10:<port>`) work **only** over ZeroTier or from the admin PC (192.168.1.50). The admin dashboard's *Operations → ZeroTier Remote Access* lists them all.

---

## 3. Finding your way around

### The admin dashboard (https://home.lab, signed in as an admin)
- **Header:** server CPU/RAM/disk/uptime, weather, web search, clock.
- **Workspace tab:** every user-facing app, quick links, and **Account**: *Approve users* · *Qdrant requests* · *Vault invites* · *Admin Guide* · *Sign out*.
- **Operations tab:** infrastructure (ESXi, Portainer, Uptime Kuma with live up/down counts, NPM, AdGuard, MeshCentral), identity & ops tools (Authentik, Beszel, Dozzle, ntfy), and ZeroTier direct links.
- Green dot = container running. ↻ (bottom-right) = refresh after configuration changes.

### The student dashboard (what students see)
Study & Create (Forum, Forgejo, Excalidraw, Paperless) · Tools (Vaultwarden, IT-Tools, Stirling PDF, n8n) · Research & AI (Qdrant, *Qdrant API key*) · Media & Network (Jellyfin, Speedtest) · Account (Student Guide, My account, Sign out). Use *Sign out* then sign in as a test student to preview it.

### Authentik admin (https://auth.lab/if/admin/)
- **Directory → Users:** people; filter *Inactive* for pending registrations.
- **Directory → Groups:** membership = access (§4).
- **Applications:** each protected site and who may open it (*Policy / Group bindings*).
- **Events → Logs:** every login, failed login, change, with IP and time. **Events → Notifications:** your inbox.
- **System → Brands / Settings:** login-page title and footer.

---

## 4. Groups (Authentik)

| Group | Gives |
|---|---|
| `homelab-admins` | admin dashboard, every admin console, logs, guides, full Qdrant |
| `authentik Admins` | the Authentik admin interface (account management) |
| `students` | student dashboard, forum, Forgejo sign-up, Qdrant request page. **New registrations land here automatically** |
| `qdrant-readers` | read every Qdrant collection |
| `qdrant-users` | Qdrant only for the collections in the person's (or their group's) `qdrant_collections` attribute |
| `qdrant-managers` | full Qdrant (create/delete collections) |
| `qdrant-pending` | requested Qdrant access; waiting for you |

Accounts that must exist: **`supun`** (current admin), **`akadmin`** (break-glass; only if every admin is locked out).

---

## 5. People: the full lifecycle

### 5.1 Students register themselves
1. Student opens https://auth.lab → **Sign up**.
2. Username **must be their index number in lowercase** (`co…-NNN`, e.g. `cohndne251f-019`). Wrong format, uppercase, a used username or a used email are refused with a clear message.
3. The account is created **inactive** in `students`; your phone shows *"Account awaiting approval"*.

### 5.2 Approve (or reject)
*Directory → Users →* filter **Inactive** → open the person → check the index number and name match a real student → **Edit → Is active ✔ → Update**. Reject: **Delete**.

### 5.3 What happens next, automatically
- They sign in at https://home.lab → student dashboard.
- **Forum:** they open forum.lab (lab login first), click *Sign up*, and must use **the same username and email** — anything else is blocked. Their forum account is confirmed automatically within 2 minutes.
- **Forgejo:** same rule at git.lab → *Register* (lab login required for the sign-up page); activated automatically within 2 minutes.
- **Qdrant:** they request access when needed (§6).

### 5.4 Apps where you create the account
Use **the index number as username** everywhere so people are traceable.

| App | Steps |
|---|---|
| Vaultwarden | https://vault.lab/admin → *Users → Invite user* → their email. Tell them: vault.lab → *Create account* with that email. Master passwords cannot be recovered — by anyone |
| Paperless | docs.lab (admin) → *Settings → Users & Groups → Add user* → username = index number → group **students** (own documents only) |
| n8n | n8n.lab → *Settings → Users → Invite* → copy the invite link to them |
| Jellyfin | jellyfin.lab → *Dashboard → Users → +* |

### 5.5 Creating an account yourself (staff, guests, or a student who can't self-register)
*Directory → Users → Create* → username (index number for students), name, email → **Create** → **Set password** or **Create recovery link** (one-time, 60 min) → *Groups → Add to existing group*.

### 5.6 Forgotten password
User → **Create recovery link** → send it (one use). Or **Set password**.

### 5.7 Make someone an admin
Add to `homelab-admins` (+ `authentik Admins` if they should manage accounts). Remove to revoke.

### 5.8 Offboarding (student leaves / misuse)
User → **Edit → Is active ✘**. Within 2 minutes: lab sign-in stops, dashboard/forum/Qdrant become unreachable, and the Forgejo login is suspended (repositories are kept). Re-activating restores everything. For immediate effect also delete their *Sessions*. Remove Vaultwarden/Paperless/n8n/Jellyfin accounts in those apps if needed.

### 5.9 Check who did what
*Events → Logs* → filter by user or action (login, login_failed, model_updated…).

---

## 6. Qdrant (vector database) access

**Request:** students click *Research & AI → Qdrant API key → Request access* (or https://qdrant.lab/request) and describe their purpose, collection and whether they need to write. You get *"Qdrant access request"* on ntfy; they join `qdrant-pending`.

**Review:** *Directory → Groups → qdrant-pending → Users* → open the user → *Attributes* → `qdrant_request` (purpose, collections, write, time).

**Grant:**

| Need | Action |
|---|---|
| Read/search all data | add to `qdrant-readers` |
| Own project | create the collection (https://qdrant.lab/dashboard → *Collections*), add user to `qdrant-users`, set user attribute:<br>`qdrant_collections:`<br>`  thesis_rag: rw` (`r` = read-only) |
| Team project | make a group (e.g. `qdrant-proj-chatbot`) with that attribute, add members to it **and** to `qdrant-users` |
| Full control (staff) | add to `qdrant-managers` |

Then remove them from `qdrant-pending` and tell them to sign out/in. Their key and examples are at https://qdrant.lab/my-token.

**How it is secured:** at each sign-in Authentik creates a personal key carrying exactly those permissions (expires in 7 days; attribute `qdrant_token_days` changes it). Nobody sees the master key. Revoking stops dashboard access at next sign-in; already-copied keys run until expiry; **(server)** rotating the master key revokes all keys at once.

---

## 7. App-specific administration

| App | Where | Notes |
|---|---|---|
| Forum | forum.lab → avatar → *Administration* | Categories (*Tags*), permissions, appearance. Email is not configured — accounts are confirmed by the sync job instead |
| Forgejo | git.lab → avatar → *Site administration* | Users, organisations, repos. Repos are private by default; sign-in needed to browse. Org `nibm-lab` holds the lab docs |
| Paperless | docs.lab → *Settings* | Users/groups, mail rules, OCR. Drop files into the consume folder **(server)** `/opt/homelab/paperless/consume` |
| Vaultwarden | vault.lab/admin | Invite, delete, deauthorise sessions, diagnostics |
| Speedtest | speed.lab/admin | Schedule (every 6 h), thresholds |
| Uptime Kuma | status.lab | Add monitors, maintenance windows, status page `services` |
| Portainer | portainer.lab | Restart/stop containers, view logs, console. Don't edit stacks here — the compose file is the source of truth (§15) |
| AdGuard | dns.lab | *Filters → DNS rewrites* = the `.lab` names; query log; blocklists |
| Crafty | crafty.lab | Minecraft server start/stop/backups (campus world `NIBM2_0`) |
| MeshCentral | mesh.lab | Remote desktop to enrolled lab PCs |
| Jellyfin | jellyfin.lab → *Dashboard* | Media from the NAS share `JellyfinMedia` |

---

## 8. Admin credentials

| Account | How to set / change |
|---|---|
| `supun` (Authentik, daily admin) | auth.lab/if/user → *Change password*; **add TOTP** under *MFA devices* |
| `akadmin` (break-glass) | bootstrap password in the server `.env`; keep offline, change when logged in as akadmin |
| Forgejo `supun` · Paperless `admin` · Beszel · ntfy `admin` · Speedtest admin | generated passwords in the server `.env` (`FORGEJO_ADMIN_PASSWORD`, `PAPERLESS_ADMIN_PASSWORD`, `BESZEL_ADMIN_PASSWORD`, `NTFY_ADMIN_PASSWORD`, `SPEEDTEST_ADMIN_PASSWORD`). Read once **(server)**, then change in the app and store in Vaultwarden |
| Portainer · NPM · AdGuard · Uptime Kuma · Crafty · MeshCentral · Jellyfin `admin` · n8n owner · Vaultwarden | set during the original build; change in each app's profile/settings |
| Server SSH | key-only (§15) |
| ESXi `root` · Synology DSM · ZeroTier Central · Cloudflare | outside the VM — keep them in the institute's password manager |

Rule: every admin password lives in **Vaultwarden** (an organisation shared by the IT staff), never in a document or chat.

---

## 9. Alerts (ntfy)

Phone: install **ntfy** → *Settings → Users* → `https://ntfy.lab`, user `admin` → subscribe:

| Topic | You get |
|---|---|
| `homelab-auth` | new registrations · Qdrant access requests · account sync actions |
| `homelab-alerts` | service down/up (25+ Uptime Kuma probes) · backup failures |
| `homelab-updates` | new versions of installed apps (daily 06:00) |

The phone must be on campus Wi-Fi or ZeroTier.

---

## 10. Health, logs, performance

- **Something down?** status.lab (or the alert). Restart it in portainer.lab → *Containers*.
- **Slow?** metrics.lab → per-container CPU/RAM/disk history.
- **Errors?** logs.lab → pick the container → search.
- **Who logged in / failed?** auth.lab → *Events → Logs*.

---

## 11. Backups and restore

- **What:** every database (consistent dumps), all app data and configs, Qdrant snapshot, firewall/SSH/system config, ZeroTier identity.
- **Where / when:** nightly 02:30, encrypted (restic) to the Synology `JellyfinMedia/.homelab-backups`; 7 daily, 4 weekly, 6 monthly; integrity check every Sunday.
- **Watch:** *Nightly Backup* in Uptime Kuma; failures alert `homelab-alerts`.
- **Restore (server):** `sudo systemctl stop`/`docker compose stop <app>` → `restic restore` the folder or `_dumps/<db>` → start → verify. Full commands: `README.md` in the `homelab-admin` repo. The restic password is `/root/.restic-password` — **copy it into the institute password manager**; without it backups are unreadable.

---

## 12. Updates

- OS security updates install automatically.
- App versions are pinned. `homelab-updates` tells you when a new version exists. **(server)** read the release notes → backup → change the version in `docker-compose.yml` → `docker compose up -d <app>` → check status.lab.

---

## 13. Security model

- **Firewall:** the campus LAN reaches only web (80/443), DNS (53/853), SSH (22), Minecraft (25565), git-SSH (2222). Everything else only via ZeroTier or the admin PC.
- **Two locks** on consoles: lab admin account, then the app's own login.
- **Identity binding:** student usernames = index numbers; forum/Forgejo accounts must match; disabled lab accounts are locked out of Forgejo automatically.
- **Approval:** every self-registration starts inactive; duplicate emails/usernames refused.
- **Qdrant:** per-user, scoped, expiring keys.
- **SSH:** keys only, fail2ban.
- Detailed findings: `docs/security.md` in the `homelab-admin` repo.

---

## 14. Troubleshooting

| Symptom | Fix |
|---|---|
| Student: "Access denied" on home.lab | account active but no group → add to `students` |
| Student can't register: "must be your index number" | they must type it lowercase, `co…-NNN` |
| Forum/Forgejo sign-up "Username must be your lab account username" | working as intended; use the same username + email as the lab account |
| Forum account still "unconfirmed" | wait 2 min (sync), or confirm it in forum *Administration → Users* |
| Approved Qdrant user sees "No Qdrant access yet" | sign out (`https://qdrant.lab/outpost.goauthentik.io/sign_out`) and in; check group **and** `qdrant_collections` attribute |
| Dashboard change not visible | press ↻ bottom-right |
| Browser certificate warning | expected until the internal CA is deployed (§16) |
| Locked out of `supun` | sign in as `akadmin`, reset `supun` |
| A `.lab` name doesn't resolve | the device must use the lab DNS (192.168.1.10) or ZeroTier |

---

## 15. Server administration (SSH)

- Host: `admin@192.168.1.10`, key-only. Add a successor's public key to `~/.ssh/authorized_keys`; remove keys of people who leave.
- Layout: `/opt/homelab/docker-compose.yml` (all apps) · `.env` (secrets, mode 600) · `<app>/` (data) · `npm/gen-npm.sh` (**every** proxy host — the NPM UI's host list is retired) · `authentik/blueprints/homelab.yaml` (groups, flows, gates as code) · `docs/`.
- Helpers: `qdrant-token` · `homelab-backup` · `lab-account-sync` · `pki-issue` (not yet active).
- Timers: `homelab-backup.timer` (02:30) · `lab-account-sync.timer` (2 min) · `pki-renew.timer`.
- Proxy change: edit `npm/gen-npm.sh` → `bash npm/gen-npm.sh npm/data/nginx/proxy_host && docker exec nginx-proxy-manager nginx -s reload`.
- New service checklist: compose (pinned image, data in `/opt/homelab/<app>`) → AdGuard rewrite → proxy host → Uptime Kuma probe → dashboard tile (+ ZeroTier bookmark) → backup coverage → this guide.

---

## 16. Pending improvements

| Item | Why | How |
|---|---|---|
| Internal certificate authority | removes browser warnings; prerequisite for single sign-on | `sudo pki-issue --force` **(server)**, then distribute `http://auth.lab/nibm-ca.crt` to lab PCs (Group Policy / MDM) |
| SSO for Forgejo, Paperless, Vaultwarden, forum | removes the separate app passwords | after the CA: OIDC providers in Authentik (blueprint) + app settings |
| Dedicated NAS backup share + off-site copy | backups currently share the media share and sit in the same building | create `HomelabBackups` on the NAS; add a second restic repository (cloud or another site) |
| Rotate legacy DB passwords (n8n, forum) | they were once in a plaintext file | `ALTER USER` + `.env` **(server)** |
| SMTP (campus mail relay) | password-reset emails, invitations | set SMTP in Authentik, Vaultwarden, Forgejo, forum, Paperless |

---

## 17. Handover checklist (when the administrator changes)

- [ ] New admin creates their own Authentik account; add to `homelab-admins` + `authentik Admins`; enable TOTP.
- [ ] Disable the previous admin's Authentik account (do **not** delete `akadmin`).
- [ ] Change every admin password in §8 and store them in the institute's Vaultwarden organisation.
- [ ] Copy the restic password (`/root/.restic-password`) to the institute password manager.
- [ ] Add the new admin's SSH key, remove the old one (§15).
- [ ] Transfer ownership of ZeroTier Central (network), Cloudflare, and any domains to an institute account.
- [ ] Re-subscribe the new admin's phone to the ntfy topics (§9).
- [ ] Check the last backup restored cleanly and status.lab is all green.

---

*NIBM Lab infrastructure · designed and built by **Supun Hewagamage** ([github.com/supunhg](https://github.com/supunhg)) during his tenure as Technical Assistant, 2026.*
