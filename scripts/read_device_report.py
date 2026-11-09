"""Pulls App Unboxed's own saved data off an iPhone connected by USB: its
preferences (scan status, which URL schemes answered) and, when present, the
detection report the app writes to Documents/detection_report.json.

Read-only. Works because a sideloaded development-signed app's container can
be opened over USB.

Usage:  python scripts/read_device_report.py [out_dir]
"""
import asyncio, inspect, io, json, os, plistlib, sys

from pymobiledevice3.lockdown import create_using_usbmux
from pymobiledevice3.services.installation_proxy import InstallationProxyService
from pymobiledevice3.services.house_arrest import HouseArrestService


async def maybe(x):
    return await x if inspect.isawaitable(x) else x


async def main():
    out_dir = sys.argv[1] if len(sys.argv) > 1 else "."
    os.makedirs(out_dir, exist_ok=True)
    lockdown = await maybe(create_using_usbmux())
    apps = await maybe(InstallationProxyService(lockdown=lockdown).get_apps(application_type="User"))
    bundle = next((b for b in apps if b.startswith("com.appunboxed.duo")), None)
    if not bundle:
        print("App Unboxed is not installed on the connected device")
        return 1
    print("bundle:", bundle, "version:", apps[bundle].get("CFBundleShortVersionString"))
    try:
        afc = HouseArrestService(lockdown=lockdown, bundle_id=bundle, documents_only=False)
        if hasattr(afc, "connect"):
            await maybe(afc.connect())
    except TypeError:
        afc = await maybe(HouseArrestService.create(lockdown, bundle, documents_only=False))

    async def read(path):
        try:
            return await maybe(afc.get_file_contents(path))
        except Exception as e:
            return None

    prefs = await read(f"/Library/Preferences/{bundle}.plist")
    if prefs:
        d = plistlib.loads(prefs)
        print("status :", d.get("appunboxed.debug.status"))
        schemes = d.get("appunboxed.debug.schemes", [])
        print("schemes:", len(schemes), " ".join(schemes))
        rows = d.get("appunboxed.foundApps.v2", [])
        print("found  :", len(rows))
        print("        ", ", ".join(r[1] for r in rows).encode("ascii", "replace").decode())
        json.dump({k: v for k, v in d.items() if isinstance(v, (str, list, int, float))},
                  io.open(os.path.join(out_dir, "device_prefs.json"), "w", encoding="utf-8"), ensure_ascii=False, default=str)
    else:
        print("no preferences file yet (open the app once first)")

    report = await read("/Documents/detection_report.json")
    if report:
        open(os.path.join(out_dir, "detection_report.json"), "wb").write(report)
        print("detection report saved:", len(report), "bytes")
    return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
