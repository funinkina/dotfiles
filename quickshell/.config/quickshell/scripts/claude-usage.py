#!/usr/bin/env python3
"""Claude Code usage for the quickshell widget.

Reads the Claude Code CLI's OAuth token and queries Anthropic's usage and
profile endpoints. Prints one compact JSON object; never prints the token.
"""
import json
import os
import time
import urllib.request

CRED = "/home/funinkina/.claude/.credentials.json"
CACHE = os.path.expanduser("~/.cache/claude-usage.json")
CACHE_TTL = 60  # serve from cache within this window (shell reload storms)


def get(url, tok):
    req = urllib.request.Request(url, headers={
        "Authorization": f"Bearer {tok}",
        "anthropic-beta": "oauth-2025-04-20",
    })
    with urllib.request.urlopen(req, timeout=10) as r:
        return json.load(r)


def plan_name(tier):
    t = (tier or "").lower()
    if "max" in t:
        for mult in ("20x", "5x"):
            if mult in t:
                return f"Max {mult}"
        return "Max"
    if "pro" in t:
        return "Pro"
    return tier or "Claude"


def window(w):
    return {"pct": w["utilization"], "resets_at": w["resets_at"]} if w else None


def cached():
    try:
        c = json.load(open(CACHE))
        return c if c.get("ok") else None
    except Exception:
        return None


prev = cached()
if prev and time.time() - prev.get("fetched_at", 0) < CACHE_TTL:
    print(json.dumps(prev))
    raise SystemExit

try:
    tok = json.load(open(CRED))["claudeAiOauth"]["accessToken"]
    usage = get("https://api.anthropic.com/api/oauth/usage", tok)
    prof = get("https://api.anthropic.com/api/oauth/profile", tok)
    acct = prof.get("account", {})
    out = {
        "ok": True,
        "fetched_at": time.time(),
        "account": acct.get("display_name") or acct.get("full_name") or "",
        "email": acct.get("email", ""),
        "plan": plan_name(prof.get("organization", {}).get("rate_limit_tier")),
        "five_hour": window(usage.get("five_hour")),
        "seven_day": window(usage.get("seven_day")),
        "seven_day_opus": window(usage.get("seven_day_opus")),
    }
    os.makedirs(os.path.dirname(CACHE), exist_ok=True)
    json.dump(out, open(CACHE, "w"))
    print(json.dumps(out))
except Exception as e:  # noqa: BLE001 — fall back to stale cache if any
    if prev:
        print(json.dumps(prev))
    else:
        print(json.dumps({"ok": False, "error": str(e)}))
