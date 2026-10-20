#!/usr/bin/env python3
"""Weather for the shell: location from the public IP, forecast from Open-Meteo.

Prints one JSON object: place, current conditions, 7 days, and 3-hourly points per day.
No API keys. The IP lookup is cached for 6 hours in $XDG_CACHE_HOME/quickshell.
"""
import datetime as dt
import json
import os
import sys
import time
import urllib.request

CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache")), "quickshell")
GEO_CACHE = os.path.join(CACHE, "geo.json")

# WMO weather codes -> (label, day glyph, night glyph) in Nerd Font weather icons
WMO = {
    0: ("Clear Sky", 0xe30d, 0xe32b), 1: ("Mainly Clear", 0xe30c, 0xe379),
    2: ("Partly Cloudy", 0xe302, 0xe37e), 3: ("Overcast", 0xe312, 0xe312),
    45: ("Fog", 0xe303, 0xe346), 48: ("Rime Fog", 0xe303, 0xe346),
    51: ("Light Drizzle", 0xe30b, 0xe32c), 53: ("Drizzle", 0xe30b, 0xe32c), 55: ("Heavy Drizzle", 0xe30b, 0xe32c),
    56: ("Freezing Drizzle", 0xe3aa, 0xe3aa), 57: ("Freezing Drizzle", 0xe3aa, 0xe3aa),
    61: ("Light Rain", 0xe308, 0xe325), 63: ("Rain", 0xe308, 0xe325), 65: ("Heavy Rain", 0xe318, 0xe318),
    66: ("Freezing Rain", 0xe3aa, 0xe3aa), 67: ("Freezing Rain", 0xe3aa, 0xe3aa),
    71: ("Light Snow", 0xe30a, 0xe327), 73: ("Snow", 0xe30a, 0xe327), 75: ("Heavy Snow", 0xe31a, 0xe31a),
    77: ("Snow Grains", 0xe31a, 0xe31a), 80: ("Showers", 0xe309, 0xe326), 81: ("Showers", 0xe309, 0xe326),
    82: ("Heavy Showers", 0xe318, 0xe318), 85: ("Snow Showers", 0xe30a, 0xe327), 86: ("Snow Showers", 0xe30a, 0xe327),
    95: ("Thunderstorm", 0xe30f, 0xe338), 96: ("Thunderstorm", 0xe30f, 0xe338), 99: ("Thunderstorm", 0xe30f, 0xe338),
}


def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "quickshell-weather/1.0"})
    with urllib.request.urlopen(req, timeout=10) as r:
        return json.load(r)


def location():
    try:
        if time.time() - os.path.getmtime(GEO_CACHE) < 6 * 3600:
            with open(GEO_CACHE) as f:
                return json.load(f)
    except OSError:
        pass
    geo = get("http://ip-api.com/json/?fields=status,city,lat,lon")
    if geo.get("status") != "success":
        raise RuntimeError("ip geolocation failed")
    os.makedirs(CACHE, exist_ok=True)
    with open(GEO_CACHE, "w") as f:
        json.dump(geo, f)
    return geo


def describe(code, is_day):
    label, day, night = WMO.get(code, ("Unknown", 0xe374, 0xe374))
    return label, chr(day if is_day else night)


# The calendar popup ported from Serpantinum expects its own forecast format;
# same WMO -> (glyph, color, label) table as its weather.sh.
SERP_MAP = [
    (lambda c, d: c == 0 and d, 0xf185, "#f9e2af", "Sunny"),
    (lambda c, d: c == 0, 0xf186, "#cba6f7", "Clear"),
    (lambda c, d: 1 <= c <= 3, 0xf0c2, "#bac2de", "Cloudy"),
    (lambda c, d: c in (45, 48), 0xf0591, "#84afdb", "Mist"),
    (lambda c, d: 51 <= c <= 57 or 61 <= c <= 67 or 80 <= c <= 82, 0xf0597, "#74c7ec", "Rainy"),
    (lambda c, d: 71 <= c <= 77 or c in (85, 86), 0xf2dc, "#cdd6f4", "Snow"),
    (lambda c, d: c in (95, 96, 99), 0xf0e7, "#f9e2af", "Storm"),
]


def serp_map(code, is_day):
    for test, glyph, hexc, desc in SERP_MAP:
        if test(code, is_day):
            return {"icon": chr(glyph), "hex": hexc, "desc": desc}
    return {"icon": chr(0xf0c2), "hex": "#cdd6f4", "desc": "Unknown"}


def fmt(t):
    return f"{round(t * 10) / 10:.1f}"


def serp_forecast(data):
    h = data["hourly"]
    days = {}
    for i, ts in enumerate(h["time"]):
        days.setdefault(ts[:10], []).append(i)
    out = []
    for idx, (date, ids) in enumerate(list(days.items())[:5]):
        temps = [h["temperature_2m"][i] for i in ids]
        d = dt.date.fromisoformat(date)
        mid = ids[12] if len(ids) > 12 else ids[0]
        dm = serp_map(h["weather_code"][mid], 1)
        slots = []
        for k in range(0, len(ids), 3):
            i = ids[k]
            hour = int(h["time"][i][11:13])
            sm = serp_map(h["weather_code"][i], 6 <= hour <= 18)
            slots.append({"time": h["time"][i][11:16], "temp": fmt(h["temperature_2m"][i]), "icon": sm["icon"], "hex": sm["hex"]})
        out.append({
            "id": str(idx), "day": d.strftime("%a"), "day_full": d.strftime("%A"), "date": str(d.day),
            "max": fmt(max(temps)), "min": fmt(min(temps)),
            "feels_like": fmt(max(h["apparent_temperature"][i] for i in ids)),
            "wind": str(round(max(h["wind_speed_10m"][i] for i in ids))),
            "humidity": str(round(sum(h["relative_humidity_2m"][i] for i in ids) / len(ids))),
            "pop": str(max((h["precipitation_probability"][i] or 0) for i in ids)),
            "icon": dm["icon"], "hex": dm["hex"], "desc": dm["desc"], "hourly": slots,
        })
    return out


def main():
    geo = location()
    data = get(
        "https://api.open-meteo.com/v1/forecast"
        f"?latitude={geo['lat']}&longitude={geo['lon']}"
        "&current=temperature_2m,apparent_temperature,relative_humidity_2m,precipitation,"
        "weather_code,wind_speed_10m,is_day"
        "&hourly=temperature_2m,weather_code,is_day,precipitation_probability,"
        "apparent_temperature,relative_humidity_2m,wind_speed_10m"
        "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,"
        "sunrise,sunset,wind_speed_10m_max"
        "&wind_speed_unit=ms&forecast_days=7&timezone=auto"
    )
    cur, hourly, daily = data["current"], data["hourly"], data["daily"]
    label, glyph = describe(cur["weather_code"], cur["is_day"])

    days = []
    for i, date in enumerate(daily["time"]):
        dlabel, dglyph = describe(daily["weather_code"][i], 1)
        hours = []
        for j, t in enumerate(hourly["time"]):
            # 3-hourly points through the day, like 01:00 04:00 ... 22:00
            if t.startswith(date) and int(t[11:13]) % 3 == 1:
                _, hglyph = describe(hourly["weather_code"][j], hourly["is_day"][j])
                hours.append({"time": t[11:16], "temp": round(hourly["temperature_2m"][j], 1), "icon": hglyph})
        days.append({
            "date": date, "label": dlabel, "icon": dglyph,
            "max": round(daily["temperature_2m_max"][i], 1), "min": round(daily["temperature_2m_min"][i], 1),
            "rain": daily["precipitation_probability_max"][i] or 0,
            "wind": round(daily["wind_speed_10m_max"][i]),
            "sunrise": daily["sunrise"][i][11:16], "sunset": daily["sunset"][i][11:16],
            "hours": hours,
        })

    # Rain chance for the current hour
    now_hour = cur["time"][:13]
    rain_now = next((hourly["precipitation_probability"][j] for j, t in enumerate(hourly["time"])
                     if t.startswith(now_hour)), 0) or 0

    print(json.dumps({
        "place": geo.get("city", ""),
        "temp": round(cur["temperature_2m"], 1),
        "feels": round(cur["apparent_temperature"], 1),
        "humidity": cur["relative_humidity_2m"],
        "wind": round(cur["wind_speed_10m"]),
        "rain": rain_now,
        "label": label,
        "icon": glyph,
        "isDay": bool(cur["is_day"]),
        "days": days,
        # Serpantinum-format fields for the ported calendar popup
        "forecast": serp_forecast(data),
        "current_icon": serp_map(cur["weather_code"], cur["is_day"])["icon"],
        "current_hex": serp_map(cur["weather_code"], cur["is_day"])["hex"],
        "current_temp": fmt(cur["temperature_2m"]),
        "unit_sym": "°C",
        "offline": False,
    }, ensure_ascii=False))


if __name__ == "__main__":
    try:
        main()
    except Exception as e:  # the shell keeps its last good data
        print(json.dumps({"error": str(e)}))
        sys.exit(1)
