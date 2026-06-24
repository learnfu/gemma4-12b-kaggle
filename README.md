# Gemma 4 12B on Dual T4

Run Google's Gemma 4 12B (Unsloth QAT GGUF) on Kaggle's dual Tesla T4 GPUs.

## Quick start

```bash
bash setup.sh
```

This downloads the CUDA llama.cpp binary, downloads the model (6.7 GB), starts the server, and creates a tunnel.

## Usage

```bash
./gemma4.sh start          # start server
./gemma4.sh start:think    # start with reasoning on
./gemma4.sh chat           # interactive chat
./gemma4.sh "question"     # one-shot query
./gemma4.sh stop           # stop everything
```

## Tunnel (public access)

| Env var | Tunnel | URL |
|---|---|---|
| (none) + `cloudflared` | Cloudflare TryCloudflare | Random, proxied through worker |
| `export ngrok_token=xxx` | ngrok | Persistent ngrok domain |

With a Cloudflare account, deploy `worker/` via `npx wrangler deploy` and on each restart update the secret:  
`echo "$TUNNEL_URL" | npx wrangler secret put TUNNEL_URL --name your-worker`

## Files

| File | Purpose |
|---|---|
| `setup.sh` | One-shot setup + start |
| `gemma4.sh` | Daily driver |
| `start_server.py` | llama-server daemon |
| `tunnel.py` | Cloudflare tunnel daemon |
| `ngrok_tunnel.py` | ngrok tunnel daemon |
| `worker/` | Cloudflare Worker for permanent URL |
