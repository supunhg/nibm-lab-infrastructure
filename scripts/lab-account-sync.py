#!/usr/bin/env python3
"""NIBM Lab account sync — Authentik is the source of truth for who is a member.

Every 2 minutes (lab-account-sync.timer):
  Forum (Flarum)   unconfirmed account whose username+email match an active lab member  -> confirmed
                   (disabled lab members can't reach forum.lab at all: it is behind Authentik)
  Git (Forgejo)    inactive account matching an active lab member                       -> activated
                   student account (co...-NNN) whose lab account is disabled/deleted    -> login prohibited
                   ...and re-allowed when the lab account is active again
Admin and non-student accounts are never touched. Changes are pushed to ntfy (homelab-auth).

Supun Hewagamage · github.com/supunhg
"""
import json, os, re, subprocess, urllib.request

ENV = dict(l.strip().split("=", 1) for l in open("/opt/homelab/.env") if "=" in l and not l.startswith("#"))
AK = "http://127.0.0.1:9100/api/v3"
STUDENT = re.compile(r"co[a-z0-9]+-[0-9]{3}")
MEMBER_GROUPS = {"students", "homelab-admins"}


def ak_users():
    users, url = [], f"{AK}/core/users/?page_size=200&type=internal"
    while url:
        req = urllib.request.Request(url, headers={"Authorization": "Bearer " + ENV["AUTHENTIK_BOOTSTRAP_TOKEN"]})
        data = json.load(urllib.request.urlopen(req, timeout=20))
        users += data["results"]
        nxt = data["pagination"].get("next")
        url = f"{AK}/core/users/?page_size=200&type=internal&page={nxt}" if nxt else None
    return users


def sh(*cmd, stdin=None):
    return subprocess.run(cmd, input=stdin, capture_output=True, text=True, check=True).stdout


def flarum(sql):
    out = sh("docker", "exec", "-i", "flarum-db", "sh", "-c", 'mariadb -uroot -p"$MYSQL_ROOT_PASSWORD" flarum -N -B', stdin=sql)
    return [l.split("\t") for l in out.splitlines() if l]


def forgejo(sql):
    out = sh("docker", "exec", "-i", "forgejo-db", "psql", "-U", "forgejo", "-tA", "-F", "\t", stdin=sql)
    return [l.split("\t") for l in out.splitlines() if l]


def q(s):  # SQL string literal (values come from our own DBs, still quote defensively)
    return "'" + str(s).replace("\\", "\\\\").replace("'", "''") + "'"


def main():
    members = {}
    for u in ak_users():
        groups = {g["name"] for g in u.get("groups_obj") or []}
        members[u["username"].lower()] = {"active": u["is_active"] and bool(groups & MEMBER_GROUPS),
                                          "email": (u.get("email") or "").lower()}
    changes = []

    for uid, name, email in flarum("select id, username, email from flarum_users where is_email_confirmed = 0;"):
        m = members.get(name.lower())
        if m and m["active"] and m["email"] == email.lower():
            flarum(f"update flarum_users set is_email_confirmed = 1 where id = {int(uid)};")
            changes.append(f"forum: confirmed {name}")

    for name, email, active, prohibited, admin in forgejo(
            'select lower_name, lower(email), is_active, prohibit_login, is_admin from "user" where type = 0;'):
        if admin == "t":
            continue
        m = members.get(name)
        ok = bool(m and m["active"] and m["email"] == email)
        if active == "f" and ok:
            forgejo(f'update "user" set is_active = true where lower_name = {q(name)};')
            changes.append(f"git: activated {name}")
        if STUDENT.fullmatch(name):
            if ok and prohibited == "t":
                forgejo(f'update "user" set prohibit_login = false where lower_name = {q(name)};')
                changes.append(f"git: re-enabled {name}")
            elif not (m and m["active"]) and prohibited == "f":
                forgejo(f'update "user" set prohibit_login = true where lower_name = {q(name)};')
                changes.append(f"git: suspended {name} (lab account disabled)")

    for c in changes:
        print(c)
    if changes:
        body = json.dumps({"topic": "homelab-auth", "title": "Lab account sync", "message": "\n".join(changes),
                           "tags": ["arrows_counterclockwise"], "priority": 2}).encode()
        try:
            urllib.request.urlopen(urllib.request.Request("http://127.0.0.1:8093/", data=body,
                headers={"Authorization": "Bearer " + ENV["NTFY_PUBLISH_TOKEN"]}), timeout=5)
        except Exception as exc:  # alerts are best-effort
            print("ntfy failed:", exc)


if __name__ == "__main__":
    main()
