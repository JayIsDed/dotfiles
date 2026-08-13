#!/bin/sh
# shelf-glance — calibration-shelf snapshot for ShelfDeck (dms desktop
# widget on the laptop). Sources the ha-mcp-bridge env; the HA token
# never leaves 111 — the laptop just gets this JSON over ssh.
set -e
set -a; . /home/jay/git/ha-mcp-bridge/.env; set +a
curl -sf -m 5 -H "Authorization: Bearer $HA_TOKEN" "$HA_URL/api/states" | python3 -c '
import json, sys
S = {s["entity_id"]: s for s in json.load(sys.stdin)}
def num(e):
    try: return round(float(S.get(e, {}).get("state")), 1)
    except (TypeError, ValueError): return None
mt = S.get("climate.main_tank", {}).get("attributes", {})
print(json.dumps({
    "tank": num("sensor.plant_shelf_temperatures_tank_center"),
    "substrate": num("sensor.plant_shelf_temperatures_tank_substrate"),
    "ambient": num("sensor.plant_shelf_temperatures_shelf_ambient"),
    "bucket": num("sensor.plant_shelf_temperatures_bucket_rig_water"),
    "heater_action": mt.get("hvac_action"),
    "target": mt.get("temperature"),
    "heater_w": num("sensor.cal_shelf_inkbird_10g_current_consumption")}))'
