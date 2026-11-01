# NIBM Lab — Student Guide

The lab gives you free tools for coursework and projects: a forum, Git hosting, a document archive, a password manager, PDF and developer tools, a whiteboard, a vector database for AI projects, and more. Use them from the **campus network**.

---

## 1. Create your NIBM lab account (once)

1. Open **https://auth.lab** and click **Sign up** (under the login box).
2. **Username = your student index number, in lowercase**, e.g. `cohndne251f-019`. It must start with `co` and end with a dash and three digits.
3. Enter your full name, your campus email and a password (10+ characters with letters and a number).
4. You'll see *"Registration received"*. The lab admin checks and activates new accounts — usually within a working day.
5. Once activated, sign in at **https://home.lab**.

> One account per person. Each index number and email can be registered only once.
> **Browser shows a certificate warning?** Expected for now — the lab uses its own certificates. Continue to the site.

---

## 2. Your dashboard (https://home.lab)

| Section | Contains |
|---|---|
| Header | search box, weather, clock |
| **Study & Create** | Forum · Forgejo · Excalidraw · Paperless |
| **Tools** | Vaultwarden · IT-Tools · Stirling PDF · n8n |
| **Research & AI** | Qdrant dashboard · *Qdrant API key* (your key, or request access) |
| **Media & Network** | Jellyfin · Speedtest |
| **Account** | *Student Guide* (this page) · *My account* (change password, add 2-factor) · *Sign out* |

A green dot means the service is up.

---

## 3. Each service

### Forum — https://forum.lab
Sign in with your lab account first. Then click **Sign up** on the forum and use **exactly the same username (your index number) and email** as your lab account — other names are refused. Your forum account is activated within a couple of minutes; then **Log in** with the forum password you chose.

### Git (Forgejo) — https://git.lab
Click **Register**, sign in with your lab account when asked, and register with **the same username and email**. Activation takes a couple of minutes. Your repositories are **private** unless you change them. Clone over HTTPS with your Forgejo username/password (or an access token from *Settings → Applications*), or add an SSH key and use port **2222**:
```
git clone ssh://git@git.lab:2222/<your-index>/<repo>.git
```

### Excalidraw — https://draw.lab
No account. Drawings are stored **in your browser only** — use *Menu → Export* (or *Save to disk*) to keep them.

### Paperless — https://docs.lab
Scan or upload PDFs/images; text becomes searchable. Ask the lab admin for an account (username = index number). You only see your own documents.

### Vaultwarden — https://vault.lab
Password manager that works with the official Bitwarden apps and browser extension (server URL `https://vault.lab`). Ask the admin for an invite, then **Create account** with the invited email. **Nobody can recover your master password** — write it down somewhere safe.

### IT-Tools — https://tools.lab · Stirling PDF — https://pdf.lab
No account. Encoders, generators, converters; merge/split/convert/sign PDFs. Files are processed and not kept.

### n8n — https://n8n.lab · Jellyfin — https://jellyfin.lab
Accounts on request from the lab admin.

### Speedtest — https://speed.lab
View the campus internet speed history.

---

## 4. Qdrant for AI / RAG projects

1. Dashboard → **Research & AI → Qdrant API key** (https://qdrant.lab/my-token).
2. *"No Qdrant access yet"* → **Request access** → describe your project, the collection name you need, and whether you must write data.
3. When the admin approves, **sign out and back in**, then open https://qdrant.lab/my-token: your personal key and a Python example.

```python
from qdrant_client import QdrantClient
client = QdrantClient(url="https://qdrant-api.lab", port=443, api_key="YOUR_KEY")
print(client.get_collections())
```

- The key only works for what you were granted and expires after about a week — revisit the page for a fresh one.
- Never commit keys to Git; use environment variables or a `.env` file listed in `.gitignore`.
- Browse your data at https://qdrant.lab/dashboard.

---

## 5. Your account

- **Change password / add 2-factor:** https://auth.lab/if/user (or dashboard → *My account*).
- **Forgot your password:** ask the lab admin for a one-time reset link.
- **Sign out:** dashboard → *Account → Sign out*.

## 6. House rules

- Don't share accounts or keys. Use the services for study and projects.
- Ask before uploading very large files (videos, multi-GB datasets).
- Something broken? Post in the forum or tell the lab admin.

---

*NIBM Lab · built by Supun Hewagamage ([@supunhg](https://github.com/supunhg))*
