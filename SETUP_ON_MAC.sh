#!/bin/zsh
set -e
REPO_DIR="$HOME/qcm-trainer"
if [ -d "$REPO_DIR/.git" ]; then
  echo "Using existing $REPO_DIR"
  cd "$REPO_DIR"
  git pull --rebase origin main
else
  gh repo clone nathanboccardi-IRL/qcm-trainer "$REPO_DIR"
  cd "$REPO_DIR"
fi
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cp "$SCRIPT_DIR/index.html" "$REPO_DIR/index.html"
cp "$SCRIPT_DIR/questions.json" "$REPO_DIR/questions.json"
cp "$SCRIPT_DIR/manifest.webmanifest" "$REPO_DIR/manifest.webmanifest"
cp "$SCRIPT_DIR/sw.js" "$REPO_DIR/sw.js"
cp "$SCRIPT_DIR/README.md" "$REPO_DIR/README.md"
cp "$SCRIPT_DIR/.nojekyll" "$REPO_DIR/.nojekyll"
mkdir -p "$REPO_DIR/.github/workflows"
cp "$SCRIPT_DIR/.github/workflows/deploy.yml" "$REPO_DIR/.github/workflows/deploy.yml"
git add index.html questions.json manifest.webmanifest sw.js README.md .nojekyll .github/workflows/deploy.yml
git commit -m "build QCM Trainer V2" || true
git push origin main
echo
echo "Done. GitHub Pages workflow has been pushed."
echo "After GitHub Pages finishes, the app URL will be:"
echo "https://nathanboccardi-irl.github.io/qcm-trainer/"
