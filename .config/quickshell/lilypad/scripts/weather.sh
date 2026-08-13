#!/bin/bash
# Waybar module: Weather via wttr.in
# Caches for 15min to avoid rate limits

CACHE="$HOME/.cache/waybar-weather.json"
CACHE_AGE=900

if [ -f "$CACHE" ]; then
    AGE=$(( $(date +%s) - $(stat -c %Y "$CACHE") ))
    if [ "$AGE" -lt "$CACHE_AGE" ]; then
        cat "$CACHE"
        exit 0
    fi
fi

# Fetch weather (auto-detects location via IP)
DATA=$(curl -sf "wttr.in/?format=j1" 2>/dev/null)

if [ -z "$DATA" ]; then
    echo '{"text": "󰖐 ?", "tooltip": "Weather unavailable", "class": "error"}'
    exit 0
fi

TEMP=$(echo "$DATA" | jq -r '.current_condition[0].temp_F')
FEELS=$(echo "$DATA" | jq -r '.current_condition[0].FeelsLikeF')
DESC=$(echo "$DATA" | jq -r '.current_condition[0].weatherDesc[0].value')
HUMIDITY=$(echo "$DATA" | jq -r '.current_condition[0].humidity')
WIND=$(echo "$DATA" | jq -r '.current_condition[0].windspeedMiles')
WIND_DIR=$(echo "$DATA" | jq -r '.current_condition[0].winddir16Point')
LOCATION=$(echo "$DATA" | jq -r '.nearest_area[0].areaName[0].value')

# Pick icon based on description
case "${DESC,,}" in
    *sunny*|*clear*)    ICON="󰖙" ;;
    *partly*|*cloud*)   ICON="󰖐" ;;
    *overcast*)         ICON="󰖐" ;;
    *rain*|*drizzle*)   ICON="󰖗" ;;
    *thunder*)          ICON="󰖓" ;;
    *snow*)             ICON="󰖘" ;;
    *fog*|*mist*)       ICON="󰖑" ;;
    *)                  ICON="󰖐" ;;
esac

# 3-day forecast for tooltip
FORECAST=""
for i in 0 1 2; do
    DAY=$(echo "$DATA" | jq -r ".weather[$i].date")
    HIGH=$(echo "$DATA" | jq -r ".weather[$i].maxtempF")
    LOW=$(echo "$DATA" | jq -r ".weather[$i].mintempF")
    FDESC=$(echo "$DATA" | jq -r ".weather[$i].hourly[4].weatherDesc[0].value")
    FORECAST="${FORECAST}${DAY}: ${LOW}°-${HIGH}°F ${FDESC}\\n"
done

TOOLTIP="${LOCATION}: ${DESC}\\nFeels like: ${FEELS}°F\\nHumidity: ${HUMIDITY}%\\nWind: ${WIND}mph ${WIND_DIR}\\n\\n${FORECAST}"

RESULT="{\"text\": \"${ICON} ${TEMP}°F\", \"tooltip\": \"${TOOLTIP}\", \"class\": \"weather\"}"
echo "$RESULT" > "$CACHE"
echo "$RESULT"
