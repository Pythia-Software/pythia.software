#!/usr/bin/env bash
# Generate the standalone static pages used locally and by deploy.sh.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_PAGE="$REPO_ROOT/index.html"
CONTACT_PAGE="$REPO_ROOT/site/pages/contact.html"
OUTPUT_DIR="$REPO_ROOT/.site-build"

for file in "$SOURCE_PAGE" "$CONTACT_PAGE"; do
  if [[ ! -f "$file" ]]; then
    echo "error: required build source is missing: $file" >&2
    exit 1
  fi
done

rm -rf -- "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# Python is used only for safe, explicit text substitution. The generated
# result is still ordinary static HTML, with no runtime templating dependency.
REPO_ROOT="$REPO_ROOT" python3 <<'PYTHON'
from pathlib import Path
import os
import re
import shutil

root = Path(os.environ["REPO_ROOT"])
source = (root / "index.html").read_text(encoding="utf-8")
contact = (root / "site/pages/contact.html").read_text(encoding="utf-8").strip()
output = root / ".site-build"

start = "<!-- PAGE_CONTENT_START: build.sh substitutes this section for each page. -->"
end = "<!-- PAGE_CONTENT_END -->"
pattern = re.compile(re.escape(start) + r".*?" + re.escape(end), re.DOTALL)
if len(pattern.findall(source)) != 1:
    raise SystemExit("error: expected exactly one PAGE_CONTENT section in index.html")

def write_page(name: str, html: str) -> None:
    (output / name).write_text(html, encoding="utf-8")

# The source is also the homepage's complete content, so it can be emitted as-is.
write_page("index.html", source)

contact_html = pattern.sub(f"{start}\n{contact}\n  {end}", source)
contact_html = contact_html.replace("<title>Pythia Software</title>", "<title>Contact Information · Pythia Software</title>")
contact_html = contact_html.replace(
    '<meta name="description" content="A View from Delphi, an essay about building software that translates between AI capabilities and human goals.">',
    '<meta name="description" content="Contact information for Pythia Software.">',
)
contact_html = contact_html.replace('href="#essay">Skip to essay', 'href="#contact">Skip to contact information')
contact_html = contact_html.replace(
    '<span class="tick"><a href="mailto:hello@pythia.software">hello@pythia.software</a></span>',
    '',
)
write_page("contact.html", contact_html)

for asset in (
    "site.webmanifest", "favicon.ico", "favicon-16x16.png", "favicon-32x32.png",
    "apple-touch-icon.png", "android-chrome-192x192.png", "android-chrome-512x512.png",
):
    shutil.copy2(root / asset, output / asset)
PYTHON

echo "Built static site in $OUTPUT_DIR"
