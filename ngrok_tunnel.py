#!/usr/bin/env python3
"""Start ngrok tunnel via double-fork daemon."""
import os, sys, time, json

PORT = sys.argv[1] if len(sys.argv) > 1 else "8080"
LOG_DIR = sys.argv[2] if len(sys.argv) > 2 else "/kaggle/working/logs"
TOKEN = os.environ.get("ngrok_token") or os.environ.get("NGROK_AUTH_TOKEN", "")
LOG_FILE = f"{LOG_DIR}/ngrok.log"
URL_FILE = f"{LOG_DIR}/ngrok_url.txt"

os.makedirs(LOG_DIR, exist_ok=True)
os.system("pkill -f 'ngrok http' 2>/dev/null")
time.sleep(1)

if TOKEN:
    os.system(f"ngrok authtoken {TOKEN} 2>/dev/null")

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

os.execve("/usr/local/bin/ngrok", ["ngrok", "http", PORT, "--log=stdout"], os.environ)
