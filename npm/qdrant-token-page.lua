-- /my-token on qdrant.lab: shows the signed-in user's own Qdrant key (minted by Authentik) or how to request one.
-- Installed to /opt/homelab/npm/data/nginx/custom/qdrant-token-page.lua
local function esc(s)
  return (tostring(s or ""):gsub("[&<>\"']", { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;", ['"'] = "&quot;", ["'"] = "&#39;" }))
end
local key, access, expires = ngx.var.qdrant_key or "", ngx.var.qdrant_access or "", ngx.var.qdrant_expires or ""
local who = esc(ngx.var.authentik_name ~= "" and ngx.var.authentik_name or ngx.var.authentik_username)
ngx.header["Cache-Control"] = "no-store"

local body
if key == "" then
  body = [[
  <h1>No Qdrant access yet</h1>
  <p>Hi ]] .. who .. [[. Your NIBM account is signed in, but it has not been granted Qdrant access.</p>
  <a class="btn" href="/request">Request access</a>
  <p class="muted">The lab admin reviews requests and will grant read-only, per-collection, or full access.
  Already approved? <a href="/outpost.goauthentik.io/sign_out">Sign out</a> and back in to refresh.</p>]]
else
  body = [[
  <h1>Your Qdrant API key</h1>
  <p>Signed in as <b>]] .. who .. [[</b> · access: <b>]] .. esc(access) .. [[</b> · expires: <b>]] .. esc(expires) .. [[</b></p>
  <textarea readonly onclick="this.select()">]] .. esc(key) .. [[</textarea>
  <button onclick="navigator.clipboard.writeText(document.querySelector('textarea').value);this.textContent='Copied'">Copy</button>
  <h2>Use it from Python</h2>
<pre>pip install qdrant-client

from qdrant_client import QdrantClient
client = QdrantClient(url="https://qdrant-api.lab", port=443, api_key="PASTE_KEY_HERE")
print(client.get_collections())</pre>
  <p class="muted">Treat this like a password. It stops working on the expiry date or when your access changes;
  revisit this page to get a fresh one. Dashboard: <a href="/dashboard">qdrant.lab/dashboard</a>.
  Install the <a href="/nibm-ca.crt">NIBM certificate</a> if Python reports a certificate error.</p>]]
end

ngx.say([[<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Qdrant access · NIBM</title><style>
body{margin:0;min-height:100vh;display:grid;place-items:center;background:#07090d;color:#e6e9ef;font:15px/1.55 Inter,system-ui,sans-serif}
main{width:min(680px,92vw);padding:2rem 2.2rem;background:rgba(255,255,255,.035);border:1px solid rgba(255,255,255,.08);border-radius:18px}
h1{margin:.2rem 0 1rem;font-size:1.5rem;letter-spacing:-.02em}h2{font-size:1rem;margin:1.6rem 0 .5rem;color:#8a93a6;text-transform:uppercase;letter-spacing:.12em}
a{color:#2dd4bf}.muted{color:#8a93a6;font-size:.88rem}
textarea{width:100%;height:7rem;box-sizing:border-box;background:#000a;color:#2dd4bf;border:1px solid rgba(255,255,255,.12);border-radius:10px;padding:.8rem;font:12px/1.4 ui-monospace,monospace;word-break:break-all}
pre{background:#000a;border:1px solid rgba(255,255,255,.08);border-radius:10px;padding:1rem;overflow:auto;font-size:12.5px}
button,.btn{display:inline-block;margin:.6rem 0;padding:.55rem 1.2rem;border:0;border-radius:99px;font-weight:600;cursor:pointer;color:#04120f;text-decoration:none;background:linear-gradient(100deg,#2dd4bf,#818cf8)}
</style></head><body><main>]] .. body .. [[</main></body></html>]])
