#!/bin/bash
set -e

python3 - <<'PY'
from pathlib import Path

p = Path('index.html')
s = p.read_text()

old = '<div class="brand">QCM Trainer</div>'
new = '''<div class="brand" style="display:flex;align-items:baseline;gap:8px">\n  <span>QCM Trainer</span><span style="font-size:11px;color:var(--muted);font-weight:700;letter-spacing:.04em">v4.1</span>\n</div>'''

if old not in s:
    raise SystemExit('Brand markup not found. Refusing to modify the file.')

s = s.replace(old, new, 1)
p.write_text(s)
PY

git add index.html
git commit -m "Show app version v4.1"
git push origin main

echo "V4.1 version label deployed."
