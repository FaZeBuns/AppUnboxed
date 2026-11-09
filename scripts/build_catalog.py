"""Builds Resources/catalog.json: bundle ids + names of popular App Store apps
and games, taken from Apple's public top-chart feeds.

A sandboxed app cannot ask iOS which apps are installed, so App Unboxed ships
this list and probes each entry on the device. Re-run before a release to
refresh it:   python scripts/build_catalog.py
"""
import json, os, sys, urllib.request
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "Resources", "catalog.json")

APP_GENRES = [6000, 6001, 6002, 6003, 6004, 6005, 6006, 6007, 6008, 6009, 6010, 6011, 6012,
              6013, 6015, 6016, 6017, 6018, 6020, 6023, 6024, 6025, 6026, 6027]
GAME_GENRES = [6014] + list(range(7001, 7020))
FEEDS = ["topfreeapplications", "toppaidapplications", "topgrossingapplications"]
COUNTRIES = ["us", "gb", "ca", "au"]


def fetch(job):
    country, feed, genre, is_game = job
    url = f"https://itunes.apple.com/{country}/rss/{feed}/limit=200/genre={genre}/json"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "catalog-builder"})
        with urllib.request.urlopen(req, timeout=30) as r:
            data = json.load(r)
    except Exception as e:
        return job, None, str(e)
    entries = data.get("feed", {}).get("entry", [])
    if isinstance(entries, dict):
        entries = [entries]
    out = []
    for e in entries:
        try:
            bid = e["id"]["attributes"]["im:bundleId"]
            name = e["im:name"]["label"]
        except (KeyError, TypeError):
            continue
        out.append((bid, name, is_game))
    return job, out, None


def short(name):
    # "Clash of Clans: Build & Battle - Strategy" -> "Clash of Clans"
    for sep in [" - ", " – ", " — ", ": ", " | ", " ("]:
        i = name.find(sep)
        if i >= 3:
            name = name[:i]
    return name.strip()[:28]


def main():
    jobs = []
    for c in COUNTRIES:
        genres = [(g, False) for g in APP_GENRES] + [(g, True) for g in GAME_GENRES]
        if c != "us":
            genres = [(6014, True), (6005, False), (6016, False), (6008, False), (6007, False), (6002, False)]
        for g, is_game in genres:
            for f in FEEDS:
                jobs.append((c, f, g, is_game))
    apps = {}
    failed = 0
    with ThreadPoolExecutor(8) as pool:
        for job, out, err in pool.map(fetch, jobs):
            if out is None:
                failed += 1
                continue
            for bid, name, is_game in out:
                if bid not in apps:
                    apps[bid] = [bid, short(name), 1 if is_game else 0]
                elif is_game:
                    apps[bid][2] = 1
    rows = sorted(apps.values(), key=lambda r: r[0].lower())
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(rows, f, ensure_ascii=False, separators=(",", ":"))
    games = sum(r[2] for r in rows)
    print(f"feeds={len(jobs)} failed={failed} apps={len(rows)} games={games} bytes={os.path.getsize(OUT)}")
    return 0 if rows else 1


if __name__ == "__main__":
    sys.exit(main())
