#!/bin/bash
set -e

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

if [ -n "$(git status --porcelain)" ]; then
  echo "Working tree is not clean. Commit or stash your local changes first."
  exit 1
fi

git fetch origin main
git merge --ff-only origin/main

python3 - <<'PY'
from pathlib import Path

p = Path('index.html')
s = p.read_text()

old_score = "const score=pct(quiz.correct,quiz.index);"
new_score = "const answeredCount=quiz.index+(quiz.locked?1:0);const score=pct(quiz.correct,answeredCount);"

if old_score not in s:
    raise SystemExit('Could not find the live score calculation. No changes were made.')
s = s.replace(old_score, new_score, 1)

old_pass = "passed=mode==='exam'?p>=60:null"
new_pass = "passed=mode==='exam'?p>=68:null"

if old_pass not in s:
    raise SystemExit('Could not find the exam pass threshold. No changes were made.')
s = s.replace(old_pass, new_pass, 1)

old_version = 'style="font-size:11px;color:var(--muted);font-weight:700;letter-spacing:.04em">v4.1</span>'
new_version = 'style="font-size:11px;color:var(--muted);font-weight:700;letter-spacing:.04em">v4.1.1</span>'
if old_version in s:
    s = s.replace(old_version, new_version, 1)

p.write_text(s)
PY

git add index.html
git commit -m "Fix live quiz score and 68 percent pass mark"
git push origin main

echo "V4.1.1 score fix deployed."
