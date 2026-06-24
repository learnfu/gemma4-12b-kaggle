#!/bin/bash
# Gemma 4 12B on Dual T4 - One-shot setup
# Run: bash setup.sh

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

MODEL_DIR="$SCRIPT_DIR/models"
BIN_DIR="$SCRIPT_DIR/llama-bin"
MODEL_FILE="$MODEL_DIR/gemma-4-12B-it-qat-UD-Q4_K_XL.gguf"
LLAMA_BIN="$BIN_DIR/llama-server"
PORT=8080
LOG_DIR="$SCRIPT_DIR/logs"
CF="$SCRIPT_DIR/cloudflared"

mkdir -p "$MODEL_DIR" "$BIN_DIR" "$LOG_DIR"

echo "=== Gemma 4 12B Setup ==="

# 1. Download llama.cpp CUDA binary
if [ ! -f "$LLAMA_BIN" ]; then
  # Try copying from existing location first
  if [ -f "/kaggle/working/llama/cuda-12.8/llama-server" ]; then
    echo "[1/3] Copying existing CUDA binary..."
    cp -r /kaggle/working/llama/cuda-12.8/* "$BIN_DIR/"
    chmod +x "$LLAMA_BIN"
    ldconfig -N -n "$BIN_DIR"
  else
    echo "[1/3] Downloading llama.cpp CUDA binary..."
    wget -qO /tmp/llama.tar.gz --timeout=30 \
      "https://github.com/ai-dock/llama.cpp-cuda/releases/download/b9775/llama.cpp-b9775-cuda-12.8-amd64.tar.gz" \
      || { echo "  Download failed"; exit 1; }
    tar -xzf /tmp/llama.tar.gz -C "$BIN_DIR" --strip-components=1
    chmod +x "$LLAMA_BIN"
    rm /tmp/llama.tar.gz
    ldconfig -N -n "$BIN_DIR"
  fi
else
  echo "[1/3] Binary already exists, skipping download"
  chmod +x "$LLAMA_BIN" 2>/dev/null || true
  ldconfig -N -n "$BIN_DIR" 2>/dev/null || true
fi

# 2. Download model
if [ ! -f "$MODEL_FILE" ]; then
  echo "[2/3] Downloading Gemma 4 12B QAT GGUF (6.7 GB)..."
  pip install -q huggingface_hub 2>/dev/null
  python3 -c "
from huggingface_hub import hf_hub_download
path = hf_hub_download('unsloth/gemma-4-12B-it-qat-GGUF', 'gemma-4-12B-it-qat-UD-Q4_K_XL.gguf')
import os
os.symlink(path, '$MODEL_DIR/gemma-4-12B-it-qat-UD-Q4_K_XL.gguf')
" 2>/dev/null || wget -qO "$MODEL_FILE" --timeout=60 \
  "https://huggingface.co/unsloth/gemma-4-12B-it-qat-GGUF/resolve/main/gemma-4-12B-it-qat-UD-Q4_K_XL.gguf"
  echo "  Model: $MODEL_FILE"
else
  echo "[2/3] Model already exists, skipping download"
fi

REASON="${1:-off}"

# 3. Start server
echo "[3/3] Starting server on port $PORT..."
python3 "$SCRIPT_DIR/start_server.py" "$REASON" "$MODEL_FILE" "$BIN_DIR" "$PORT"

echo -n "  Waiting"
for i in {1..15}; do
  sleep 1
  curl -s --max-time 2 http://localhost:$PORT/health >/dev/null 2>&1 && echo " READY!" && break
  [ "$i" -eq 15 ] && echo " TIMEOUT" && exit 1
done
sleep 2

echo ""
echo "=== Gemma 4 12B is running! ==="
echo "API: http://localhost:$PORT/v1/chat/completions"
echo ""
echo "Quick test:"
for attempt in 1 2; do
  RES=$(curl -s --max-time 30 http://localhost:$PORT/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d '{"messages":[{"role":"user","content":"Say hello in one word"}],"max_tokens":10,"temperature":0}' \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('choices',[{}])[0].get('message',{}).get('content','FAIL'))" 2>/dev/null)
  [ "$RES" != "FAIL" ] && echo "  Response: $RES" && break
  [ "$attempt" = "1" ] && echo "  (retrying...)" && sleep 3
done
[ "$RES" = "FAIL" ] && echo "  Quick test failed - server may still be warming up"
echo ""

# 4. Tunnel (ngrok or Cloudflare)
URL=""
if [ -n "${ngrok_token:-}" ] || [ -n "${NGROK_AUTH_TOKEN:-}" ]; then
  echo "[4/4] Starting ngrok tunnel..."
  python3 "$SCRIPT_DIR/ngrok_tunnel.py" "$PORT" "$LOG_DIR"
  echo -n "  Waiting for ngrok URL"
  for i in {1..20}; do
    URL=$(python3 -c "
import json
try:
    with open('$LOG_DIR/ngrok.log') as f:
        for line in f:
            line=line.strip()
            if not line: continue
            try:
                d=json.loads(line)
                if d.get('lvl')=='info' and 'url' in d:
                    print(d['url'])
            except: pass
except: pass
" 2>/dev/null || true)
    [ -n "$URL" ] && echo "" && break
    echo -n "."; sleep 1
  done
  [ -z "$URL" ] && echo " failed"
  echo "  Ngrok URL: $URL"

elif [ -f "$CF" ]; then
  echo "[4/4] Starting Cloudflare tunnel..."
  chmod +x "$CF" 2>/dev/null || true
  python3 "$SCRIPT_DIR/tunnel.py" "$PORT" "$CF" "$LOG_DIR"
  echo -n "  Tunnel: "
  for i in {1..20}; do
    URL=$(grep -oP 'https://[a-z0-9-]+\.trycloudflare\.com' "$LOG_DIR/cf.log" 2>/dev/null | head -1 || true)
    [ -n "$URL" ] && echo "$URL" && break
    sleep 1
  done
  [ -z "$URL" ] && echo "failed"
else
  echo "[4/4] No tunnel available (install cloudflared or set ngrok_token)"
fi

# Print tunnel info
if [ -n "$URL" ]; then
  echo ""
  echo "  Tunnel URL: $URL"
  echo "$URL" > "$LOG_DIR/tunnel_url.txt"
  echo ""
  echo "  For a permanent URL, deploy worker/ via Cloudflare Workers"
  echo "  and update the TUNNEL_URL secret on each restart."
fi
