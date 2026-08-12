#!/usr/bin/env bash
# shelf.sh — AI shelf (llama-swap) up/down/status on this box.
# Mirrors lab-train-prep/-done semantics: a deliberate stop persists across
# reboots (restart: unless-stopped honours it) — that is the point.
set -euo pipefail

case "${1:-status}" in
  down)
    docker stop llama-swap >/dev/null 2>&1 || true
    ;;
  up)
    docker start llama-swap >/dev/null 2>&1 || true
    ;;
  status)
    state=$(docker inspect -f '{{.State.Status}}' llama-swap 2>/dev/null || echo "absent")
    vram=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>/dev/null || echo "?")
    echo "llama-swap: ${state} | vram: ${vram} MiB"
    ;;
  *)
    echo "usage: shelf.sh [up|down|status]" >&2
    exit 1
    ;;
esac
