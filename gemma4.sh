#!/bin/bash
# Gemma 4 12B on Dual T4 - Daily driver
# Usage:
#   CTX_SIZE=32768 ./gemma4.sh start   - Start with 32K context window
#   CTX_SIZE=65536 ./gemma4.sh start   - Start with 64K context window
#   ./gemma4.sh start                  - Start API server (no reasoning)
#   ./gemma4.sh start:think            - Start API server (with reasoning)
#   ./gemma4.sh chat                   - Interactive chat
#   ./gemma4.sh "text"                 - Ask one question
#   ./gemma4.sh stop                   - Stop server
# 
# Model supports up to 262144 context. Set CTX_SIZE env var to adjust.
# Uses q8_0 KV cache to save VRAM.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODEL="$SCRIPT_DIR/models/gemma-4-12B-it-qat-UD-Q4_K_XL.gguf"
BIN_DIR="$SCRIPT_DIR/llama-bin"
PORT=8080

_start() {
  local reasoning="$1"
  local label="fast (no reasoning)"
  [ "$reasoning" = "on" ] && label="with reasoning (better for math/code/logic)"
  echo "Starting Gemma 4 12B ($label) on http://localhost:$PORT ..."
  python3 "$SCRIPT_DIR/start_server.py" "$reasoning" "$MODEL" "$BIN_DIR" "$PORT"
  for i in {1..15}; do
    sleep 1
    curl -s --max-time 2 http://localhost:$PORT/health >/dev/null 2>&1 && echo "Ready!" && return
  done
  echo "Failed to start server" && exit 1
}

case "${1:-chat}" in
  start:reason|start:think)
    _start "on"
    ;;
  start)
    _start "off"
    ;;
  chat)
    while true; do
      read -p "> " -r LINE || break
      [ -z "$LINE" ] && continue
      [ "$LINE" = "/exit" ] && break
      curl -s --max-time 60 http://localhost:$PORT/v1/chat/completions \
        -H "Content-Type: application/json" \
        -d "{\"messages\":[{\"role\":\"user\",\"content\":\"$LINE\"}],\"max_tokens\":1024,\"temperature\":0.7}" \
        | python3 -c "
import sys, json
d = json.load(sys.stdin)
msg = d['choices'][0]['message']
if msg.get('reasoning_content'):
    print('⚡ ' + msg['reasoning_content'])
    print('---')
print(msg['content'])
"
      echo ""
    done
    ;;
  stop)
    python3 -c "
import os
os.system('pkill -f llama-server 2>/dev/null')
os.system('pkill -f cloudflared 2>/dev/null')
os.system('pkill -f ngrok 2>/dev/null')
" && echo "Stopped" || echo "Not running"
    ;;
  *)
    curl -s --max-time 60 http://localhost:$PORT/v1/chat/completions \
      -H "Content-Type: application/json" \
      -d "{\"messages\":[{\"role\":\"user\",\"content\":\"$*\"}],\"max_tokens\":1024,\"temperature\":0.7}" \
      | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['choices'][0]['message'].get('content',''))"
    ;;
esac
