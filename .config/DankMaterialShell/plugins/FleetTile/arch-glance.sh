#!/bin/sh
# arch-glance — archbox HA-side power snapshot for the FleetTile (dms).
# Wall watts ride the pc_strip plug; token stays on 111.
set -e
set -a; . /home/jay/git/ha-mcp-bridge/.env; set +a
python3 - << 'PY'
import json, os, urllib.request
base = os.environ["HA_URL"]; tok = os.environ["HA_TOKEN"]
def st(e):
    req = urllib.request.Request(base + "/api/states/" + e,
                                 headers={"Authorization": "Bearer " + tok})
    try:
        with urllib.request.urlopen(req, timeout=4) as r:
            return json.load(r)["state"]
    except Exception:
        return None
def num(e):
    try: return float(st(e))
    except (TypeError, ValueError): return None
print(json.dumps({
    "wall": num("sensor.pc_strip_current_consumption"),
    "kwh": num("sensor.pc_strip_today_s_consumption"),
    "switch": st("switch.archbox")}))
PY
