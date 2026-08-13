#!/usr/bin/env bash
# claude-usage — plan-utilization relay for lilypad (and anything else on the
# tailnet that wants it). Reads the local Claude Code OAuth token, asks the
# usage endpoint, prints ONLY utilization percentages + reset times as compact
# JSON. The token never appears in output. 60s cache so a bar widget can poll
# freely without hammering the endpoint.
set -euo pipefail

CACHE=/tmp/claude-usage-cache.json
CREDS="$HOME/.claude/.credentials.json"

if [ -f "$CACHE" ] && [ $(( $(date +%s) - $(stat -c %Y "$CACHE") )) -lt 60 ]; then
    cat "$CACHE"
    exit 0
fi

TOKEN=$(python3 -c "import json;print(json.load(open('$CREDS'))['claudeAiOauth']['accessToken'])" 2>/dev/null) || { echo '{"error":"no-creds"}'; exit 0; }

RESP=$(curl -sf --max-time 8 \
    -H "Authorization: Bearer $TOKEN" \
    -H "anthropic-beta: oauth-2025-04-20" \
    https://api.anthropic.com/api/oauth/usage) || { echo '{"error":"fetch-failed"}'; exit 0; }

OUT=$(printf '%s' "$RESP" | python3 -c "
import json, sys
j = json.load(sys.stdin)
def bucket(k):
    b = j.get(k) or {}
    return {'pct': round(b.get('utilization') or 0), 'reset': b.get('resets_at')}
print(json.dumps({'five': bucket('five_hour'), 'seven': bucket('seven_day')}, separators=(',', ':')))
") || { echo '{"error":"parse-failed"}'; exit 0; }

printf '%s\n' "$OUT" | tee "$CACHE"
