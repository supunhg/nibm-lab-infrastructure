#!/usr/bin/env python3
"""Render docs/STUDENT-GUIDE.md and docs/ADMIN-GUIDE.md to themed HTML served at home.lab/guide and home.lab/admin-guide.
usage: render-guides.py <docs_dir> <out_dir>      (out_dir = /opt/homelab/npm/data/nginx/custom/guides)"""
import pathlib, re, sys
import markdown

docs, out = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
out.mkdir(parents=True, exist_ok=True)

CSS = """
:root{--bg:#07090d;--line:rgba(255,255,255,.08);--text:#e6e9ef;--muted:#8a93a6;--accent:#2dd4bf;--accent2:#818cf8}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--text);font:15.5px/1.65 Inter,system-ui,-apple-system,"Segoe UI",sans-serif}
body::before{content:"";position:fixed;inset:-30vmax auto auto -20vmax;width:70vmax;height:70vmax;border-radius:50%;
 background:radial-gradient(circle,var(--accent),transparent 65%);filter:blur(120px);opacity:.12;z-index:-1}
header{position:sticky;top:0;backdrop-filter:blur(14px);background:rgba(7,9,13,.75);border-bottom:1px solid var(--line);
 padding:.8rem 1.5rem;display:flex;gap:1rem;align-items:center;justify-content:space-between;z-index:5}
header b{background:linear-gradient(100deg,#fff 10%,var(--accent) 60%,var(--accent2));-webkit-background-clip:text;background-clip:text;color:transparent}
header a{color:var(--muted);text-decoration:none;font-size:.9rem}header a:hover{color:var(--text)}
main{max-width:920px;margin:0 auto;padding:2rem 1.5rem 5rem}
h1{font-size:2rem;letter-spacing:-.03em;margin:.5rem 0 1rem}
h2{margin-top:2.6rem;padding-top:1rem;border-top:1px solid var(--line);font-size:1.3rem;letter-spacing:-.01em}
h3{margin-top:1.8rem;color:var(--accent);font-size:1.05rem}
a{color:var(--accent)}code{background:rgba(255,255,255,.06);padding:.1rem .35rem;border-radius:6px;font-size:.88em}
pre{background:#000a;border:1px solid var(--line);border-radius:12px;padding:1rem;overflow:auto}pre code{background:none;padding:0}
table{width:100%;border-collapse:collapse;margin:1rem 0;font-size:.92rem;display:block;overflow-x:auto}
th,td{text-align:left;padding:.55rem .7rem;border-bottom:1px solid var(--line);vertical-align:top}
th{color:var(--muted);font-weight:600;text-transform:uppercase;font-size:.72rem;letter-spacing:.1em}
blockquote{margin:1rem 0;padding:.6rem 1rem;border-left:3px solid var(--accent2);background:rgba(129,140,248,.07);border-radius:0 10px 10px 0}
hr{border:0;border-top:1px solid var(--line);margin:2rem 0}
nav.toc{background:rgba(255,255,255,.03);border:1px solid var(--line);border-radius:14px;padding:.6rem 1.2rem;margin:1.5rem 0}
nav.toc ul{margin:.3rem 0;padding-left:1.1rem}nav.toc a{color:var(--text);text-decoration:none}nav.toc a:hover{color:var(--accent)}
"""

for src, name, title in [("STUDENT-GUIDE.md", "student.html", "Student Guide"),
                         ("ADMIN-GUIDE.md", "admin.html", "Admin Guide")]:
    text = (docs / src).read_text(encoding="utf-8")
    md = markdown.Markdown(extensions=["tables", "fenced_code", "toc", "sane_lists"], extension_configs={"toc": {"toc_depth": "2"}})
    html = md.convert(text)
    # links to sibling docs point at the versioned copies in Forgejo
    html = re.sub(r'href="(security|operations|ADMIN-GUIDE)\.md(#[^"]*)?"',
                  r'href="https://git.lab/nibm-lab/homelab-admin/src/branch/main/docs/\1.md\2"', html)
    page = f"""<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{title} · NIBM Lab</title><style>{CSS}</style></head><body>
<header><b>NIBM Lab · {title}</b><span><a href="https://home.lab">← Dashboard</a></span></header>
<main><nav class="toc"><strong>Contents</strong>{md.toc}</nav>{html}</main></body></html>"""
    (out / name).write_text(page, encoding="utf-8")
    print("rendered", out / name)
