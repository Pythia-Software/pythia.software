#!/usr/bin/env bash
# Stage and deploy the static site to its dedicated Firebase Hosting target.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$REPO_ROOT/.site-build"
OUTPUT_DIR="$REPO_ROOT/.firebase-public"
PROJECT_ID="pythia-mail"
HOSTING_TARGET="pythia-software"

SITE_FILES=(
  index.html
  about/index.html
  contact.html
  privacy.html
  terms.html
  site.webmanifest
  favicon.ico
  favicon-16x16.png
  favicon-32x32.png
  apple-touch-icon.png
  android-chrome-192x192.png
  android-chrome-512x512.png
)

"$REPO_ROOT/build.sh"

if ! command -v firebase >/dev/null 2>&1; then
  echo "error: firebase CLI is not installed" >&2
  echo "       install it with: npm install --global firebase-tools" >&2
  exit 1
fi

for file in "${SITE_FILES[@]}"; do
  if [[ ! -f "$BUILD_DIR/$file" ]]; then
    echo "error: required site file is missing: $file" >&2
    exit 1
  fi
done

# This generated directory deliberately excludes scripts and repository metadata.
if [[ "$OUTPUT_DIR" != "$REPO_ROOT/.firebase-public" ]]; then
  echo "error: refusing to clean unexpected output directory: $OUTPUT_DIR" >&2
  exit 1
fi
rm -rf -- "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

for file in "${SITE_FILES[@]}"; do
  mkdir -p "$(dirname "$OUTPUT_DIR/$file")"
  cp "$BUILD_DIR/$file" "$OUTPUT_DIR/$file"
done

echo "==> Deploying $HOSTING_TARGET to Firebase Hosting"
firebase deploy \
  --config "$REPO_ROOT/firebase.json" \
  --project "$PROJECT_ID" \
  --only "hosting:$HOSTING_TARGET" \
  --non-interactive

echo "==> Done. Live at https://$HOSTING_TARGET.web.app"
