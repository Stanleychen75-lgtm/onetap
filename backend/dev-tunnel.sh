#!/usr/bin/env bash
#
# OneTap — start the backend AND a public HTTPS tunnel in one shot, for testing the
# app on mobile data (5G). Run it, copy the printed https://….trycloudflare.com URL
# into the app's Debug screen, and search. Press Ctrl-C to stop both.
#
#   ./dev-tunnel.sh
#
cd "$(dirname "$0")" || exit 1

# 1) Start the backend (open, local dev — no API key) only if it isn't already running.
if curl -sf -m 3 http://localhost:8080/health >/dev/null 2>&1; then
  echo "✓ Backend already running on :8080"
else
  echo "▶ Starting backend (open, local dev)…"
  API_KEY= npm run dev > /tmp/onetap-backend.log 2>&1 &
  BACKEND_PID=$!
  # Kill the backend we started when this script exits (Ctrl-C).
  trap 'echo; echo "Stopping backend…"; kill $BACKEND_PID 2>/dev/null' EXIT
  printf "  waiting for backend"
  for _ in $(seq 1 40); do
    curl -sf -m 2 http://localhost:8080/health >/dev/null 2>&1 && { echo " ✓"; break; }
    printf "."; sleep 0.5
  done
fi

# 2) Open the public Cloudflare tunnel (stays in the foreground; Ctrl-C to stop).
#    --protocol http2: forces the tunnel over TCP/HTTP2 instead of QUIC/UDP. QUIC is
#    often throttled or blocked on cellular and restrictive Wi-Fi (that was almost
#    certainly behind the 30-minute spinner), so http2 is far more reliable for phone use.
echo
echo "▶ Opening public Cloudflare tunnel (http2 — reliable on cellular)…"
echo "  Copy the  https://….trycloudflare.com  URL below into the app:"
echo "  Home → 🐞 (top-right) → “Backend URL” → paste → “Use this URL”."
echo "  NOTE: this URL is NEW every run. For a URL that never changes (and works"
echo "        without your Mac on), deploy the hosted backend — see backend/DEPLOY.md."
echo
./cloudflared tunnel --no-autoupdate --protocol http2 --url http://localhost:8080
