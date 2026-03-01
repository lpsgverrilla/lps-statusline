#!/usr/bin/env python3
"""
Claude AI Usage Limits Fetcher
Fetches your Claude usage limits using cookies from your browser.
"""

import os
import sys
import json
import argparse
from datetime import datetime

try:
    import requests
    import cloudscraper
except ImportError:
    sys.exit("Missing dependencies. Install with: pip install requests cloudscraper")

try:
    import browser_cookie3
except ImportError:
    sys.exit("Missing 'browser_cookie3'. Install with: pip install browser-cookie3")


def get_cookies_for_claude():
    """Try to get Claude cookies from various browsers."""
    browsers = [
        ("Chrome", browser_cookie3.chrome),
        ("Firefox", browser_cookie3.firefox),
        ("Edge", browser_cookie3.edge),
        ("Chromium", browser_cookie3.chromium),
    ]

    for name, browser_fn in browsers:
        try:
            cj = browser_fn(domain_name=".claude.ai")
            if any("claude.ai" in c.domain for c in cj):
                print(f"✓ Found cookies from {name}")
                return cj
        except Exception as e:
            print(f"  Could not access {name}: {e}", file=sys.stderr)
            continue

    return None


def get_cookies_for_claude_quiet():
    """Try to get Claude cookies from various browsers (silent version)."""
    browsers = [
        browser_cookie3.chrome,
        browser_cookie3.firefox,
        browser_cookie3.edge,
        browser_cookie3.chromium,
    ]

    for browser_fn in browsers:
        try:
            cj = browser_fn(domain_name=".claude.ai")
            if any("claude.ai" in c.domain for c in cj):
                return cj
        except Exception:
            continue

    return None


def get_organization_uuid(session, quiet=False):
    """Fetch the organization UUID."""
    response = session.get("https://claude.ai/api/organizations", timeout=10)
    response.raise_for_status()

    try:
        orgs = response.json()
    except json.JSONDecodeError as e:
        raise ValueError(f"Invalid JSON response from organizations API: {e}")

    if not orgs:
        raise ValueError("No organizations found")

    # Warn if multiple organizations exist (user may want a different one)
    if len(orgs) > 1 and not quiet:
        print(f"   Note: Found {len(orgs)} organizations, using first one: {orgs[0].get('name', 'Unknown')}")
        print(f"   Set CLAUDE_ORG_UUID env var to override.")

    # Allow override via environment variable
    env_uuid = os.environ.get("CLAUDE_ORG_UUID")
    if env_uuid:
        return env_uuid

    return orgs[0]["uuid"]


def get_usage(session, org_uuid):
    """Fetch usage limits for the organization."""
    response = session.get(f"https://claude.ai/api/organizations/{org_uuid}/usage", timeout=10)
    response.raise_for_status()

    try:
        return response.json()
    except json.JSONDecodeError as e:
        raise ValueError(f"Invalid JSON response from usage API: {e}")


def format_time_remaining(reset_time_str):
    """Calculate and format time remaining until reset."""
    try:
        # Handle Z suffix (convert to +00:00 for fromisoformat)
        # Python 3.10+ fromisoformat handles milliseconds natively
        reset_time_str = reset_time_str.replace("Z", "+00:00")
        reset_time = datetime.fromisoformat(reset_time_str)
    except ValueError:
        return "unknown"

    now = datetime.now(reset_time.tzinfo)
    delta = reset_time - now

    if delta.total_seconds() < 0:
        return "resetting soon"

    hours, remainder = divmod(int(delta.total_seconds()), 3600)
    minutes = remainder // 60

    if hours > 24:
        days = hours // 24
        hours = hours % 24
        return f"{days}d {hours}h"
    elif hours > 0:
        return f"{hours}h {minutes}m"
    else:
        return f"{minutes}m"


def display_usage(usage_data):
    """Display usage data in a readable format."""
    print("\n" + "=" * 50)
    print("       CLAUDE USAGE LIMITS")
    print("=" * 50)

    # Current session (5-hour)
    if usage_data.get("five_hour"):
        fh = usage_data["five_hour"]
        time_left = format_time_remaining(fh["resets_at"])
        bar = create_progress_bar(fh["utilization"])
        print(f"\n📊 Current Session (5-hour)")
        print(f"   {bar} {fh['utilization']}% used")
        print(f"   Resets in: {time_left}")

    # Weekly - All models
    if usage_data.get("seven_day"):
        sd = usage_data["seven_day"]
        time_left = format_time_remaining(sd["resets_at"])
        bar = create_progress_bar(sd["utilization"])
        print(f"\n📊 Weekly (All Models)")
        print(f"   {bar} {sd['utilization']}% used")
        print(f"   Resets in: {time_left}")

    # Weekly - Sonnet only
    if usage_data.get("seven_day_sonnet"):
        ss = usage_data["seven_day_sonnet"]
        time_left = format_time_remaining(ss["resets_at"])
        bar = create_progress_bar(ss["utilization"])
        print(f"\n📊 Weekly (Sonnet Only)")
        print(f"   {bar} {ss['utilization']}% used")
        print(f"   Resets in: {time_left}")

    # Extra usage
    if usage_data.get("extra_usage"):
        eu = usage_data["extra_usage"]
        print(f"\n💰 Extra Usage")
        print(f"   {json.dumps(eu, indent=6)}")

    print("\n" + "=" * 50)


def create_progress_bar(percentage, width=20):
    """Create a simple ASCII progress bar."""
    filled = int(width * percentage / 100)
    empty = width - filled

    if percentage >= 80:
        color = "🔴"
    elif percentage >= 50:
        color = "🟡"
    else:
        color = "🟢"

    return f"[{'█' * filled}{'░' * empty}] {color}"


def format_statusline(usage_data):
    """Output compact format for statusline: 5h:45%:2h30m|7d:70%:3d12h|sonnet:N|extra:bool|iguana:val"""
    parts = []

    if usage_data.get("five_hour"):
        fh = usage_data["five_hour"]
        time_left = format_time_remaining(fh["resets_at"])
        parts.append(f"5h:{int(fh['utilization'])}%:{time_left}")

    if usage_data.get("seven_day"):
        sd = usage_data["seven_day"]
        time_left = format_time_remaining(sd["resets_at"])
        parts.append(f"7d:{int(sd['utilization'])}%:{time_left}")

    # Sonnet-specific weekly usage
    if usage_data.get("seven_day_sonnet"):
        ss = usage_data["seven_day_sonnet"]
        parts.append(f"sonnet:{int(ss['utilization'])}")
    else:
        parts.append("sonnet:null")

    # Extra usage indicator — only true when actually consuming extra usage
    # (a normal limit is at/above 100%), not just because the object exists
    eu = usage_data.get("extra_usage")
    actually_in_extra = False
    if eu:
        fh = usage_data.get("five_hour")
        sd = usage_data.get("seven_day")
        fh_over = fh and fh.get("utilization", 0) >= 100
        sd_over = sd and sd.get("utilization", 0) >= 100
        actually_in_extra = fh_over or sd_over
    parts.append(f"extra:{str(actually_in_extra).lower()}")

    # Iguana necktie field (sanitized to prevent output format corruption)
    iguana_val = usage_data.get("iguana_necktie")
    if iguana_val is not None:
        # Remove pipe and newline chars that would break statusline parsing
        sanitized = str(iguana_val).replace("|", "").replace("\n", "").replace("\r", "")
        parts.append(f"iguana:{sanitized}")
    else:
        parts.append("iguana:null")

    print("|".join(parts))


def main():
    parser = argparse.ArgumentParser(description="Fetch Claude AI usage limits")
    parser.add_argument(
        "--statusline",
        action="store_true",
        help="Output compact format for statusline integration",
    )
    args = parser.parse_args()

    quiet = args.statusline

    if not quiet:
        print("🔍 Looking for Claude session cookies...")

    cookies = get_cookies_for_claude_quiet() if quiet else get_cookies_for_claude()
    if not cookies:
        if not quiet:
            print("❌ Could not find Claude cookies in any browser.")
            print("   Make sure you're logged into claude.ai in Chrome, Firefox, or Edge.")
        sys.exit(1)

    if not quiet:
        cookie_names = [c.name for c in cookies if "claude.ai" in c.domain]
        print(f"   Cookies found: {cookie_names}")

    session = cloudscraper.create_scraper(
        browser={
            "browser": "chrome",
            "platform": "linux",
            "desktop": True,
        }
    )
    for cookie in cookies:
        if "claude.ai" in cookie.domain:
            session.cookies.set(
                cookie.name, cookie.value, domain=cookie.domain, path=cookie.path
            )
    session.headers.update({
        "Accept": "application/json, text/plain, */*",
        "Accept-Language": "en-US,en;q=0.9",
        "Origin": "https://claude.ai",
        "Referer": "https://claude.ai/",
    })

    try:
        if not quiet:
            print("🔍 Fetching organization info...")
        org_uuid = get_organization_uuid(session, quiet=quiet)

        if not quiet:
            print("🔍 Fetching usage limits...")
        usage = get_usage(session, org_uuid)

        if args.statusline:
            format_statusline(usage)
        else:
            display_usage(usage)

    except requests.exceptions.HTTPError as e:
        if not quiet:
            if e.response.status_code == 401:
                print("❌ Authentication failed. Your session may have expired.")
                print("   Try logging into claude.ai again in your browser.")
            elif e.response.status_code == 403:
                print(f"❌ HTTP Error: {e}")
                print(f"   Response body: {e.response.text[:500]}")
            else:
                print(f"❌ HTTP Error: {e}")
        sys.exit(1)
    except Exception as e:
        if not quiet:
            print(f"❌ Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
