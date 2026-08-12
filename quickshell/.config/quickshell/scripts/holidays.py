#!/usr/bin/env python3
"""Indian holidays + observances -> ~/.cache/quickshell/holidays.json

Source: Google's public holiday calendar for India, the ICS feed behind
"Holidays in India" in Google Calendar. No API key, no rate limit, and it
carries ~54 entries a year from 2021 to 2031 in a single request — including
the lunar festivals (Holi, Diwali, Eid) that fixed-date lists get wrong.

DESCRIPTION's first line separates the ~18 gazetted "Public holiday" entries
from the "Observance" ones, so the UI can weight them differently.

Output: {"fetched": <epoch s>, "days": {"2026-08-15": [{"n": name, "p": 1}]}}
  p=1 gazetted public holiday, p=0 observance.

Refetches only when the cache is older than TTL_DAYS; a failed fetch leaves
the existing cache in place, so the calendar keeps working offline.
Pass --force to refetch regardless, --print to dump the resolved cache path.
"""
import json
import os
import re
import sys
import time
import urllib.request
from datetime import date, timedelta

URL = ("https://calendar.google.com/calendar/ical/"
       "en.indian%23holiday%40group.v.calendar.google.com/public/basic.ics")
CACHE = os.path.expanduser("~/.cache/quickshell/holidays.json")
TTL_DAYS = 7
TIMEOUT = 20


def parse(ics):
    # RFC 5545 line folding: a leading space continues the previous line
    text = ics.replace("\r\n ", "").replace("\r\n", "\n").replace("\n ", "")
    days = {}
    for ev in re.findall(r"BEGIN:VEVENT(.*?)END:VEVENT", text, re.S):
        start = re.search(r"DTSTART;VALUE=DATE:(\d{8})", ev)
        name = re.search(r"SUMMARY:(.*)", ev)
        if not (start and name):
            continue
        desc = re.search(r"DESCRIPTION:(.*)", ev)
        public = bool(desc) and desc.group(1).split("\\n")[0].strip() == "Public holiday"
        # ICS escapes , ; and \ in text values
        label = re.sub(r"\\([,;\\])", r"\1", name.group(1).strip())

        s = start.group(1)
        d = date(int(s[:4]), int(s[4:6]), int(s[6:]))
        end = re.search(r"DTEND;VALUE=DATE:(\d{8})", ev)
        if end:
            e = end.group(1)
            last = date(int(e[:4]), int(e[4:6]), int(e[6:]))  # exclusive
        else:
            last = d + timedelta(days=1)

        while d < last:
            days.setdefault(d.isoformat(), []).append({"n": label, "p": int(public)})
            d += timedelta(days=1)

    # Gazetted holidays first, then alphabetical — stable render order
    for v in days.values():
        v.sort(key=lambda h: (-h["p"], h["n"]))
    return days


def fresh():
    try:
        age = time.time() - os.path.getmtime(CACHE)
    except OSError:
        return False
    if age > TTL_DAYS * 86400:
        return False
    # A cache that got truncated or written empty must not count as fresh
    try:
        with open(CACHE) as f:
            return bool(json.load(f).get("days"))
    except (OSError, ValueError):
        return False


def keep(msg):
    """Report and fall back to whatever cache we already have."""
    have = os.path.exists(CACHE)
    print(f"holidays: {msg}; "
          + ("keeping existing cache" if have else "no cache to fall back on"),
          file=sys.stderr)
    return 0 if have else 1


def main():
    if "--print" in sys.argv:
        print(CACHE)
        return 0
    if fresh() and "--force" not in sys.argv:
        return 0

    try:
        req = urllib.request.Request(URL, headers={"User-Agent": "quickshell-holidays/1"})
        with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
            days = parse(r.read().decode("utf-8", "replace"))
    except Exception as e:
        return keep(f"fetch failed ({e})")

    if not days:
        return keep("feed parsed to zero events")

    os.makedirs(os.path.dirname(CACHE), exist_ok=True)
    tmp = CACHE + ".tmp"
    with open(tmp, "w") as f:
        json.dump({"fetched": int(time.time()), "days": days}, f, ensure_ascii=False)
    os.replace(tmp, CACHE)  # atomic: FileView never sees a half-written file
    print(f"holidays: {sum(len(v) for v in days.values())} entries "
          f"across {len(days)} days -> {CACHE}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
