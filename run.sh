#!/bin/bash
set -e

# Find an open port starting from 8000
find_open_port() {
  local port=8000
  while lsof -iTCP:$port -sTCP:LISTEN -n -P >/dev/null 2>&1; do
    ((port++))
  done
  echo $port
}

PORT=$(find_open_port)
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
"$DIR/build.sh"

echo "Starting live-reload server on port $PORT..."
echo "Open http://localhost:$PORT in your browser"
echo ""

# Create a temporary directory for our inject script
TEMP_DIR=$(mktemp -d)
cleanup() {
  rm -rf -- "$TEMP_DIR"
}
trap cleanup EXIT

# Create a simple reload script that polls for changes
cat > "$TEMP_DIR/reload.js" << 'SCRIPT'
(function() {
  let lastCheck = Date.now();
  setInterval(async () => {
    try {
      const response = await fetch(window.location.href, { cache: 'no-store' });
      const html = await response.text();
      let hash = 0;
      for (let i = 0; i < html.length; i++) {
        hash = ((hash << 5) - hash + html.charCodeAt(i)) | 0;
      }
      const stored = localStorage.getItem('_page_hash');
      const fingerprint = `${html.length}:${hash}`;
      if (stored && stored !== fingerprint) {
        window.location.reload();
      }
      localStorage.setItem('_page_hash', fingerprint);
    } catch (e) {}
  }, 1000);
})();
SCRIPT

# Create a middleware server that injects the reload script
python3 << PYTHON
import os
import sys
import http.server
import socketserver
import subprocess
import time
import webbrowser
import threading
from functools import partial
from pathlib import Path

repo_dir = Path('$DIR')
build_dir = repo_dir / '.site-build'
pages_dir = repo_dir / 'site' / 'pages'

def pages_snapshot():
    while True:
        try:
            snapshot = {}
            for path in pages_dir.rglob('*'):
                if path.is_file():
                    stat = path.stat()
                    snapshot[str(path.relative_to(pages_dir))] = (stat.st_mtime_ns, stat.st_size)
            return snapshot
        except FileNotFoundError:
            # An editor may replace a temporary file while it is being scanned.
            continue

def watch_pages():
    snapshot = pages_snapshot()
    while True:
        time.sleep(0.25)
        current = pages_snapshot()
        if current == snapshot:
            continue

        # Give editors that save through a temporary file a moment to settle.
        time.sleep(0.1)
        current = pages_snapshot()
        print('Pages changed; rebuilding...', file=sys.stderr, flush=True)
        try:
            subprocess.run([str(repo_dir / 'build.sh')], check=True)
        except subprocess.CalledProcessError:
            print('Build failed; waiting for the next save.', file=sys.stderr, flush=True)
        snapshot = current

class LiveReloadHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        # Serve files normally
        if self.path == '/' or self.path.endswith('.html'):
            # For HTML files, inject the reload script
            try:
                file_path = build_dir / (self.path.lstrip('/') or 'index.html')
                if file_path.is_file() and file_path.suffix == '.html':
                    with open(file_path, 'rb') as f:
                        content = f.read()

                    # Inject reload script before closing body tag
                    reload_script = b'<script src="/reload.js"></script>'
                    if b'</body>' in content:
                        content = content.replace(b'</body>', reload_script + b'</body>')
                    elif b'</html>' in content:
                        content = content.replace(b'</html>', reload_script + b'</html>')

                    self.send_response(200)
                    self.send_header('Content-type', 'text/html')
                    self.send_header('Content-Length', len(content))
                    self.end_headers()
                    self.wfile.write(content)
                    return
            except:
                pass

        # Handle reload.js
        if self.path == '/reload.js':
            with open('$TEMP_DIR/reload.js', 'rb') as f:
                content = f.read()
            self.send_response(200)
            self.send_header('Content-type', 'application/javascript')
            self.send_header('Content-Length', len(content))
            self.end_headers()
            self.wfile.write(content)
            return

        # Default handler for other files
        super().do_GET()

    def log_message(self, format, *args):
        # Minimal logging
        if 'GET' in args[0]:
            print(f"  {args[0]}", file=sys.stderr)

handler = partial(LiveReloadHandler, directory=str(build_dir))
with socketserver.TCPServer(('', $PORT), handler) as httpd:
    url = f'http://localhost:$PORT'
    print(f'Server running on {url}', file=sys.stderr)

    # Open browser in background thread
    def open_browser():
        time.sleep(0.5)
        webbrowser.open(url)

    threading.Thread(target=open_browser, daemon=True).start()
    threading.Thread(target=watch_pages, daemon=True).start()

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print('\\nServer stopped', file=sys.stderr)
PYTHON
