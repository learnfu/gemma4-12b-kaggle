#!/usr/bin/env python3
"""Start cloudflared tunnel via double-fork daemon."""
import os, sys, time

PORT = sys.argv[1] if len(sys.argv) > 1 else "8080"
CF = sys.argv[2] if len(sys.argv) > 2 else "/kaggle/working/cloudflared"
LOG_DIR = sys.argv[3] if len(sys.argv) > 3 else "/kaggle/working/logs"
LOG_FILE = f"{LOG_DIR}/cf.log"

os.makedirs(LOG_DIR, exist_ok=True)
os.system("pkill -f 'cloudflared tunnel' 2>/dev/null")
time.sleep(1)

pid = os.fork()
if pid > 0:
    sys.exit(0)

os.setsid()
pid = os.fork()
if pid > 0:
    sys.exit(0)

os.chdir("/")
with open(LOG_FILE, "w") as f:
    os.dup2(f.fileno(), 1)
    os.dup2(f.fileno(), 2)

os.execve(CF, [CF, "tunnel", "--url", f"http://localhost:{PORT}", "--no-autoupdate"], os.environ)
