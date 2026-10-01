#!/usr/bin/env python3
"""
Capture a screenshot of a kiosk dashboard (URL from WALL_KIOSK_URL) using
headless Chromium driven over the DevTools Protocol (CDP).

Why CDP instead of `chromium --headless --screenshot=...`:
The dashboard's outer page loads instantly, but it fetches its config via
JS and then sets an <iframe src=...> asynchronously -- that happens AFTER
the outer page's `load` event fires. Chromium's plain --screenshot flag
takes the shot right at `load`, so it always captures a blank/black frame.
Driving navigation over CDP lets us wait a fixed, real (non-virtual) amount
of time after navigation before capturing, which lets the iframe's content
actually render. `--virtual-time-budget` was also tried and reliably
deadlocks against this page's open EventSource (SSE) connection -- avoid it.

Exit code is non-zero on any failure and nothing is written to OUT, so a
failed capture never clobbers the last-known-good background image.

Readiness: instead of a blind sleep after navigation, this drives the page
over CDP and waits until <iframe id="display"> actually has a non-empty src
and a loaded document, then retries the screenshot while it still looks
blank. The kiosk sets its iframe src asynchronously in app.js, so a fixed
settle alone intermittently captured a blank about:blank frame (~25 KB).
"""
import base64
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request

# All values overridable via wall-kiosk.env (loaded by the systemd unit) or
# the process environment; these defaults match Trevor's wall kiosk.
WALL_KIOSK_URL = os.environ.get("WALL_KIOSK_URL", "https://example.invalid/kiosk-dashboard")
WALL_KIOSK_WIDTH = int(os.environ.get("WALL_KIOSK_WIDTH", "2560"))
WALL_KIOSK_HEIGHT = int(os.environ.get("WALL_KIOSK_HEIGHT", "1440"))
WALL_KIOSK_SETTLE = int(os.environ.get("WALL_KIOSK_SETTLE", "5"))  # seconds after nav before capture
DEVTOOLS_TIMEOUT = 10  # seconds to wait for the devtools endpoint to appear


def fail(msg):
    print(f"wall-kiosk-capture: {msg}", file=sys.stderr)
    sys.exit(1)


def main():
    if len(sys.argv) != 2:
        fail("usage: wall-kiosk-capture.py <output-png-path>")
    out_path = sys.argv[1]

    import websocket  # provided by system package python-websocket-client

    profile_dir = tempfile.mkdtemp(prefix="wall-kiosk-chrome-")
    proc = subprocess.Popen(
        [
            "chromium",
            "--headless=new",
            "--disable-extensions",
            "--disable-gpu",
            "--no-sandbox",
            "--hide-scrollbars",
            f"--user-data-dir={profile_dir}",
            "--remote-debugging-port=0",
            "--remote-allow-origins=*",
            f"--window-size={WALL_KIOSK_WIDTH},{WALL_KIOSK_HEIGHT}",
            "about:blank",
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )

    try:
        port_file = os.path.join(profile_dir, "DevToolsActivePort")
        deadline = time.time() + DEVTOOLS_TIMEOUT
        port = None
        while time.time() < deadline:
            if os.path.exists(port_file):
                with open(port_file) as f:
                    lines = f.read().splitlines()
                if lines and lines[0].strip():
                    port = int(lines[0].strip())
                    break
            if proc.poll() is not None:
                fail(f"chromium exited early with code {proc.returncode}")
            time.sleep(0.1)
        if port is None:
            fail("devtools port file never appeared")

        ws_url = None
        deadline = time.time() + DEVTOOLS_TIMEOUT
        while time.time() < deadline:
            try:
                with urllib.request.urlopen(
                    f"http://127.0.0.1:{port}/json/list", timeout=1
                ) as r:
                    targets = json.load(r)
                pages = [t for t in targets if t.get("type") == "page"]
                if pages:
                    ws_url = pages[0]["webSocketDebuggerUrl"]
                    break
            except (urllib.error.URLError, ConnectionError, TimeoutError):
                pass
            time.sleep(0.2)
        if ws_url is None:
            fail("no page target became available")

        ws = websocket.create_connection(ws_url, timeout=10)
        counter = {"id": 0}

        def send(method, params=None):
            counter["id"] += 1
            ws.send(
                json.dumps(
                    {"id": counter["id"], "method": method, "params": params or {}}
                )
            )
            return counter["id"]

        def recv_for(target_id):
            while True:
                data = json.loads(ws.recv())
                if data.get("id") == target_id:
                    return data

        recv_for(send("Page.enable"))
        recv_for(
            send(
                "Emulation.setDeviceMetricsOverride",
                {
                    "width": WALL_KIOSK_WIDTH,
                    "height": WALL_KIOSK_HEIGHT,
                    "deviceScaleFactor": 1,
                    "mobile": False,
                },
            )
        )
        def evaluate(expression):
            res = recv_for(
                send(
                    "Runtime.evaluate",
                    {"expression": expression, "returnByValue": True},
                )
            )
            return res.get("result", {}).get("result", {}).get("value")

        def page_ready():
            # The kiosk outer page sets its <iframe id="display"> src
            # asynchronously in app.js AFTER the outer load event. Until that
            # src is set (and its document has loaded) the page renders blank,
            # which is what produced intermittent black frames.
            try:
                return bool(
                    evaluate(
                        "(function(){"
                        "  var i=document.getElementById('display');"
                        "  if(!i||!i.getAttribute('src')) return false;"
                        "  try{ var d=i.contentDocument;"
                        "    if(d && d.readyState!=='complete') return false;"
                        "    if(d && (d.body?d.body.childElementCount:0)===0) return false;"
                        "  }catch(e){ return false; }"
                        "  return document.readyState==='complete';"
                        "})()"
                    )
                )
            except Exception:
                return False

        nav = recv_for(send("Page.navigate", {"url": WALL_KIOSK_URL}))
        if "error" in nav:
            fail(f"navigation failed: {nav['error']}")

        # Wait until the async iframe actually has content instead of blindly
        # sleeping. Poll the page, then apply the settle delay once ready.
        ready_deadline = time.time() + (WALL_KIOSK_SETTLE + 20)
        while time.time() < ready_deadline and not page_ready():
            time.sleep(0.5)
        # Real wall-clock settle time for the iframe content to finish painting.
        time.sleep(WALL_KIOSK_SETTLE)

        # Capture, retrying while the frame still looks blank. A blank frame
        # (about:blank / loading logo) compresses to ~25 KB; a rendered 2560x1440
        # dashboard is well over 500 KB. Retry within a bounded deadline so a
        # genuinely-broken kiosk still fails instead of looping forever.
        png_bytes = b""
        MIN_REAL = 200 * 1024
        capture_deadline = time.time() + 25
        while True:
            shot = recv_for(
                send("Page.captureScreenshot", {"format": "png", "fromSurface": True})
            )
            if "error" in shot:
                fail(f"screenshot failed: {shot['error']}")
            png_bytes = base64.b64decode(shot["result"]["data"])
            if len(png_bytes) >= MIN_REAL:
                break
            if not page_ready():
                # iframe regressed (e.g. a reload); wait for it again
                rdl = time.time() + 10
                while time.time() < rdl and not page_ready():
                    time.sleep(0.5)
                time.sleep(WALL_KIOSK_SETTLE)
            if time.time() >= capture_deadline:
                break
            time.sleep(2)

        if len(png_bytes) < 1024:
            fail("captured image suspiciously small, refusing to write")

        tmp_out = out_path + ".tmp"
        with open(tmp_out, "wb") as f:
            f.write(png_bytes)
        os.replace(tmp_out, out_path)
        print(f"wall-kiosk-capture: wrote {out_path} ({len(png_bytes)} bytes)")
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()
        shutil.rmtree(profile_dir, ignore_errors=True)


if __name__ == "__main__":
    main()
