#!/usr/bin/env python3
"""Upcoming events from one or more Google Calendar secret iCal addresses, merged.

Reads ~/.config/quickshell/calendar.url (keep that file private): one URL per line,
blank lines ignored. A "# Name" line right above a URL renames that calendar;
other # lines are comments. Prints JSON: events in the next 14 days
from all calendars, recurring ones expanded, sorted by start, each tagged with its
calendar's name (X-WR-CALNAME) and index so the shell can color it.
Handles DAILY/WEEKLY/MONTHLY/YEARLY RRULEs with INTERVAL, COUNT, UNTIL, BYDAY and EXDATE,
which covers what Google exports for normal calendars and timetables.
"""
import datetime as dt
import json
import os
import sys
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from zoneinfo import ZoneInfo

URL_FILE = os.environ.get("QS_CALENDAR_URL_FILE", os.path.expanduser("~/.config/quickshell/calendar.url"))
LOCAL = dt.datetime.now().astimezone().tzinfo
DAYS = {"MO": 0, "TU": 1, "WE": 2, "TH": 3, "FR": 4, "SA": 5, "SU": 6}
HORIZON = 70      # days ahead
PAST = 35         # days back, so clicking past calendar days still shows them


def unfold(text):
    # RFC 5545 line folding: a leading space continues the previous line
    return text.replace("\r\n ", "").replace("\n ", "").replace("\r\n\t", "").splitlines()


def unescape(v):
    return v.replace("\\n", " ").replace("\\,", ",").replace("\\;", ";").replace("\\\\", "\\").strip()


def parse_time(params, value):
    """Return (datetime in local tz, all_day)."""
    if params.get("VALUE") == "DATE" or (len(value) == 8 and value.isdigit()):
        d = dt.datetime.strptime(value[:8], "%Y%m%d")
        return d.replace(tzinfo=LOCAL), True
    if value.endswith("Z"):
        t = dt.datetime.strptime(value, "%Y%m%dT%H%M%SZ").replace(tzinfo=dt.timezone.utc)
    else:
        t = dt.datetime.strptime(value, "%Y%m%dT%H%M%S")
        tz = params.get("TZID")
        t = t.replace(tzinfo=ZoneInfo(tz) if tz else LOCAL)
    return t.astimezone(LOCAL), False


def events(lines):
    ev = None
    for line in lines:
        if line == "BEGIN:VEVENT":
            ev = {"exdates": set()}
        elif line == "END:VEVENT" and ev is not None:
            yield ev
            ev = None
        elif ev is not None and ":" in line:
            head, value = line.split(":", 1)
            name, *rest = head.split(";")
            params = dict(p.split("=", 1) for p in rest if "=" in p)
            if name in ("DTSTART", "DTEND"):
                ev[name] = parse_time(params, value)
            elif name == "EXDATE":
                for v in value.split(","):
                    ev["exdates"].add(parse_time(params, v)[0])
            elif name == "RECURRENCE-ID":
                ev[name] = parse_time(params, value)[0]
            elif name in ("SUMMARY", "LOCATION", "RRULE", "STATUS", "UID"):
                ev[name] = unescape(value) if name in ("SUMMARY", "LOCATION") else value


def occurrences(start, rule, exdates, until_view):
    if not rule:
        yield start
        return
    r = dict(p.split("=", 1) for p in rule.split(";") if "=" in p)
    freq, step = r.get("FREQ"), int(r.get("INTERVAL", 1))
    count = int(r["COUNT"]) if "COUNT" in r else None
    until = parse_time({}, r["UNTIL"])[0] if "UNTIL" in r else None
    byday = [DAYS[d[-2:]] for d in r.get("BYDAY", "").split(",") if d[-2:] in DAYS]

    if freq not in ("DAILY", "WEEKLY", "MONTHLY", "YEARLY"):
        yield start
        return

    def nth(k):
        """Start of the k-th period, or None when that month/year lacks the day (e.g. 29 Feb)."""
        if freq == "DAILY":
            return start + dt.timedelta(days=k * step)
        if freq == "WEEKLY":
            return start + dt.timedelta(weeks=k * step)
        months = k * step * (12 if freq == "YEARLY" else 1)
        m = start.month - 1 + months
        try:
            return start.replace(year=start.year + m // 12, month=m % 12 + 1)
        except ValueError:
            return None

    n, k = 0, 0
    while k < 100000:
        cur = nth(k)
        k += 1
        if cur is None:
            continue
        if cur > until_view or (until is not None and cur > until) or (count is not None and n >= count):
            return
        candidates = [cur]
        if freq == "WEEKLY" and byday:
            monday = cur - dt.timedelta(days=cur.weekday())
            candidates = sorted(monday + dt.timedelta(days=d) for d in byday)
        for c in candidates:
            if c < start or (until and c > until) or (count is not None and n >= count):
                continue
            n += 1
            if c not in exdates:
                yield c


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": "quickshell-calendar/1.0"})
    with urllib.request.urlopen(req, timeout=15) as r:
        return unfold(r.read().decode("utf-8", "replace"))


def calendar_name(lines, fallback):
    for line in lines:
        if line.startswith("X-WR-CALNAME:"):
            return unescape(line.split(":", 1)[1]) or fallback
        if line == "BEGIN:VEVENT":
            break
    return fallback


def main():
    urls, labels = [], []
    try:
        label = None
        for raw in open(URL_FILE):
            line = raw.strip()
            if line.startswith("#"):
                label = line.lstrip("#").strip() or None
            elif line:
                urls.append(line)
                labels.append(label)
                label = None
            else:
                label = None
    except OSError:
        pass
    if not urls:
        print(json.dumps({"configured": False, "events": []}))
        return

    # Fetch all calendars at once; one failing doesn't hide the others
    def safe(url):
        try:
            return fetch(url), None
        except Exception as e:
            return None, str(e)
    with ThreadPoolExecutor(max_workers=8) as pool:
        results = list(pool.map(safe, urls))

    out, calendars, errors = [], [], []
    for idx, (lines, err) in enumerate(results):
        if lines is None:
            errors.append(f"calendar {idx + 1}: {err}")
            calendars.append({"name": f"Calendar {idx + 1}", "ok": False})
            continue
        name = labels[idx] or calendar_name(lines, f"Calendar {idx + 1}")
        try:
            events = list(expand(lines))
        except Exception as e:
            errors.append(f"{name}: {e}")
            calendars.append({"name": name, "ok": False})
            continue
        calendars.append({"name": name, "ok": True})
        out.extend(dict(e, calendar=name, calIndex=idx) for e in events)

    out.sort(key=lambda x: x["start"])
    today = dt.date.today()
    print(json.dumps({
        "configured": True,
        "from": (today - dt.timedelta(days=PAST)).isoformat(),
        "to": (today + dt.timedelta(days=HORIZON - 1)).isoformat(),
        "calendars": calendars,
        "error": "; ".join(errors),
        "events": out[:3000],
    }, ensure_ascii=False))


def expand(lines):
    now = dt.datetime.now(LOCAL)
    today = now.replace(hour=0, minute=0, second=0, microsecond=0)
    end_view = today + dt.timedelta(days=HORIZON)
    start_view = today - dt.timedelta(days=PAST)

    all_ev = list(events(lines))
    # Moved/edited single occurrences of a series (RECURRENCE-ID) replace the generated one
    overrides = {(e.get("UID"), e["RECURRENCE-ID"]) for e in all_ev if "RECURRENCE-ID" in e}

    out = []
    for e in all_ev:
        if "DTSTART" not in e or e.get("STATUS") == "CANCELLED":
            continue
        start, all_day = e["DTSTART"]
        end = e.get("DTEND", (start + dt.timedelta(days=1 if all_day else 0, hours=0 if all_day else 1), all_day))[0]
        length = end - start
        for s in occurrences(start, e.get("RRULE"), e["exdates"], end_view):
            if "RRULE" in e and (e.get("UID"), s) in overrides:
                continue
            f = s + length
            if f <= start_view or s >= end_view:
                continue
            out.append({
                "title": e.get("SUMMARY", "(no title)"),
                "location": e.get("LOCATION", ""),
                "start": s.isoformat(), "end": f.isoformat(),
                "allDay": all_day,
                "date": s.strftime("%Y-%m-%d"),
            })
    return out


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(json.dumps({"configured": True, "error": str(e), "events": []}))
        sys.exit(1)
