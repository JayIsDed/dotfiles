#!/bin/sh
# pond-glance — printer-fleet snapshot for PondDeck (dms desktop widget).
# Sources the pond .env; the Bambuddy API key stays on 111.
set -e
set -a; . /home/jay/git/the-pond/.env; set +a
python3 - << 'PY'
import json, os, urllib.request

base = os.environ["BAMBUDDY_URL"]
hdr = {os.environ.get("BAMBUDDY_KEY_HEADER", "X-API-Key"): os.environ["BAMBUDDY_API_KEY"]}

def get(path):
    req = urllib.request.Request(base + path, headers=hdr)
    with urllib.request.urlopen(req, timeout=5) as r:
        return json.load(r)

out = []
for p in get("/api/v1/printers/"):
    if not p.get("is_active"):
        continue
    try:
        s = get("/api/v1/printers/%d/status" % p["id"])
        out.append({
            "name": p["name"], "model": p["model"],
            "connected": s.get("connected", False),
            "state": s.get("state", "?"),
            "job": s.get("current_print") or "",
            "progress": s.get("progress", 0),
            "remaining": s.get("remaining_time", 0),
            "layer": s.get("layer_num", 0), "layers": s.get("total_layers", 0),
            "nozzle": round(s.get("temperatures", {}).get("nozzle", 0)),
            "bed": round(s.get("temperatures", {}).get("bed", 0))})
    except Exception:
        out.append({"name": p["name"], "model": p["model"], "connected": False, "state": "OFFLINE"})
print(json.dumps(out))
PY
