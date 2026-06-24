#!/usr/bin/env python3
"""Daemonize llama-server via double-fork."""
import os, sys, time

REASONING = sys.argv[1] if len(sys.argv) > 1 else "off"
MODEL = sys.argv[2] if len(sys.argv) > 2 else "/kaggle/working/models/gemma-4-12B-it-qat-UD-Q4_K_XL.gguf"
BIN_DIR = sys.argv[3] if len(sys.argv) > 3 else "/kaggle/working/llama/cuda-12.8"
PORT = sys.argv[4] if len(sys.argv) > 4 else "8080"

os.environ["LD_LIBRARY_PATH"] = f"{BIN_DIR}:{os.environ.get('LD_LIBRARY_PATH','')}"
os.system(f"ldconfig -N -n {BIN_DIR} 2>/dev/null")
os.system("pkill -f llama-server 2>/dev/null")
time.sleep(1)

pid = os.fork()
if pid > 0:
    sys.exit(0)

os.setsid()
pid = os.fork()
if pid > 0:
    sys.exit(0)

os.chdir("/")
with open("/dev/null", "w") as f:
    os.dup2(f.fileno(), 0)
    os.dup2(f.fileno(), 1)
    os.dup2(f.fileno(), 2)

CTX = os.environ.get("CTX_SIZE", "262144")

os.execve(f"{BIN_DIR}/llama-server", [
    f"{BIN_DIR}/llama-server",
    "-m", MODEL,
    "-ngl", "99",
    "-c", CTX,
    "-ctk", "q8_0",
    "-ctv", "q8_0",
    "--host", "0.0.0.0",
    "--port", PORT,
    "--jinja",
    "--reasoning", REASONING
], os.environ)
