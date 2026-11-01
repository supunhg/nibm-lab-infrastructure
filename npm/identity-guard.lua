-- Identity guard for app sign-up forms (Flarum /register, Forgejo /user/sign_up).
-- Runs after Authentik forward-auth: the account being created must use the SAME username and email
-- as the signed-in NIBM lab account, so one person = one identity across every service.
-- Installed to /opt/homelab/npm/data/nginx/custom/identity-guard.lua   (Supun Hewagamage · github.com/supunhg)
if ngx.req.get_method() ~= "POST" then return end

local want_user  = (ngx.var.authentik_username or ""):lower()
local want_email = (ngx.var.authentik_email or ""):lower()
local is_json = (ngx.var.content_type or ""):find("json", 1, true) ~= nil

ngx.req.read_body()
local user, email
if is_json then
  local data = require("cjson.safe").decode(ngx.req.get_body_data() or "") or {}
  user, email = data.username, data.email
else
  local args = ngx.req.get_post_args(50) or {}
  user, email = args.user_name or args.username, args.email
end
user  = tostring(user or ""):lower()
email = tostring(email or ""):lower()

local problem
if want_user == "" then
  problem = "Sign in to your NIBM lab account first (https://auth.lab)."
elseif user ~= want_user then
  problem = "Username must be your lab account username: " .. want_user
elseif want_email ~= "" and email ~= want_email then
  problem = "Email must be your lab account email: " .. want_email
end
if not problem then return end

ngx.log(ngx.WARN, "identity-guard blocked sign-up: lab=", want_user, " form=", user)
ngx.status = 422
if is_json then -- Flarum shows JSON:API errors inside the sign-up modal
  ngx.header["Content-Type"] = "application/vnd.api+json"
  ngx.say(require("cjson.safe").encode({ errors = { {
    status = "422", code = "validation_error", detail = problem, source = { pointer = "/data/attributes/username" } } } }))
else
  ngx.header["Content-Type"] = "text/html; charset=utf-8"
  ngx.say("<!doctype html><meta charset=utf-8><title>Sign-up blocked</title>",
          "<body style='font:16px system-ui;background:#07090d;color:#e6e9ef;display:grid;place-items:center;min-height:100vh;margin:0'>",
          "<div style='max-width:560px;padding:2rem;border:1px solid #ffffff22;border-radius:16px'>",
          "<h2 style='margin-top:0'>Sign-up blocked</h2><p>", problem, "</p>",
          "<p><a style='color:#2dd4bf' href='javascript:history.back()'>Go back</a></p></div></body>")
end
return ngx.exit(422)
