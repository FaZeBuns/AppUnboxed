"""Reads the installed-app list from an iPhone connected by USB (read-only,
via pymobiledevice3) and reports which of those apps App Unboxed's catalogs
know about. Used to measure and close gaps in on-device detection.

Usage:  python scripts/compare_with_device.py [out.json]
"""
import asyncio, inspect, io, json, os, re, sys

from pymobiledevice3.lockdown import create_using_usbmux
from pymobiledevice3.services.installation_proxy import InstallationProxyService

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")


async def maybe(x):
    return await x if inspect.isawaitable(x) else x


async def read_apps():
    lockdown = await maybe(create_using_usbmux())
    proxy = InstallationProxyService(lockdown=lockdown)
    out = {}
    for kind in ("User", "System"):
        apps = await maybe(proxy.get_apps(application_type=kind))
        for bid, info in apps.items():
            out[bid] = {
                "name": info.get("CFBundleDisplayName") or info.get("CFBundleName") or bid,
                "type": kind,
                "schemes": [s for t in info.get("CFBundleURLTypes", []) or [] for s in t.get("CFBundleURLSchemes", []) or []],
                "hidden": bool(info.get("SBAppTags")) or info.get("IsHidden", False),
            }
    return out


def main():
    apps = asyncio.run(read_apps())
    catalog = {r[0] for r in json.load(io.open(os.path.join(ROOT, "Resources", "catalog.json"), encoding="utf-8"))}
    curated = set(re.findall(r'CatalogApp\("([^"]+)"', io.open(os.path.join(ROOT, "src", "AppCatalog.swift"), encoding="utf-8").read()))
    user = {b: a for b, a in apps.items() if a["type"] == "User"}
    rows = {"curated": [], "catalog": [], "neither": []}
    for bid, a in sorted(user.items(), key=lambda kv: kv[1]["name"].lower()):
        where = "curated" if bid in curated else "catalog" if bid in catalog else "neither"
        rows[where].append([bid, a["name"], a["schemes"][:3]])
    clean = lambda s: s.encode("ascii", "replace").decode()
    print(f"user apps: {len(user)}   system apps: {len(apps) - len(user)}")
    for k in ("curated", "catalog", "neither"):
        print(f"--- {k}: {len(rows[k])}")
        for bid, name, schemes in rows[k]:
            print(f"   {clean(name)} | {bid} | {','.join(schemes)}")
    if len(sys.argv) > 1:
        json.dump({"apps": apps, "rows": rows}, io.open(sys.argv[1], "w", encoding="utf-8"), ensure_ascii=False)


if __name__ == "__main__":
    main()
