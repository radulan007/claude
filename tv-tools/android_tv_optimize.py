#!/usr/bin/env python3
"""Optimizeaza un televizor Android TV / Google TV (Sony, Philips, TCL) prin ADB in retea.

Ce face:
  * reduce durata animatiilor (interfata pare mult mai rapida)
  * iti arata aplicatiile preinstalate care par inutile si le DEZACTIVEAZA doar pe cele alese de tine
    (nu sterge nimic; totul se poate reactiva cu --restore)

Rulare:
  python android_tv_optimize.py 192.168.1.50            # doar arata ce ar face (nu schimba nimic)
  python android_tv_optimize.py 192.168.1.50 --apply    # aplica modificarile
  python android_tv_optimize.py 192.168.1.50 --restore  # anuleaza tot ce a facut scriptul
Necesita 'adb' (Android SDK Platform-Tools) instalat si in PATH.
"""
import argparse
import json
import pathlib
import shutil
import subprocess
import sys

# Cuvinte care apar des in numele aplicatiilor de reclame / promotii / demo.
BLOAT_HINTS = (
    "promo", "demo", "retail", "store", "shop", "select", "advert", "ads", "feedback",
    "tutorial", "survey", "partner", "games", "videos", "music", "news", "weather", "recommend",
)
# Pachete de sistem esentiale pe care scriptul nu le propune niciodata.
NEVER = (
    "launcher", "tvlauncher", "setupwraith", "settings", "katniss", "inputmethod", "systemui",
    "packageinstaller", "gms", "gsf", "vending", "webview", "tv.remote", "permission",
    "bluetooth", "provider", "frameworks", "android.tv.settings", "certinstaller",
)
ANIMATIONS = ("window_animation_scale", "transition_animation_scale", "animator_duration_scale")
FAST_SCALE = "0.5"


def adb(target, *args, check=True):
    r = subprocess.run(["adb", "-s", target, *args], capture_output=True, text=True)
    if check and r.returncode != 0:
        sys.exit(f"Eroare adb {' '.join(args)}: {r.stderr.strip() or r.stdout.strip()}")
    return r.stdout.strip()


def connect(ip):
    target = ip if ":" in ip else f"{ip}:5555"
    out = subprocess.run(["adb", "connect", target], capture_output=True, text=True).stdout
    if "connected" not in out:
        sys.exit(f"Nu ma pot conecta la {target}: {out.strip()}\n"
                 "Verifica 'Network debugging' / 'USB debugging' pe televizor.")
    state = subprocess.run(["adb", "-s", target, "get-state"], capture_output=True, text=True).stdout.strip()
    if state != "device":
        sys.exit("Accepta cererea 'Allow USB debugging?' afisata pe televizor, apoi ruleaza din nou.")
    return target


def suggestions(target):
    enabled = set(adb(target, "shell", "pm", "list", "packages", "-e").replace("package:", "").split())
    return sorted(
        p for p in enabled
        if any(h in p.lower() for h in BLOAT_HINTS) and not any(n in p.lower() for n in NEVER)
    )


def choose(packages):
    for i, p in enumerate(packages, 1):
        print(f"  {i:2}. {p}")
    raw = input("\nNumerele aplicatiilor de dezactivat (ex: 1,3,5), sau Enter pentru niciuna: ").strip()
    picked = []
    for part in raw.replace(" ", "").split(","):
        if part.isdigit() and 1 <= int(part) <= len(packages):
            picked.append(packages[int(part) - 1])
    return picked


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("ip")
    ap.add_argument("--apply", action="store_true", help="aplica modificarile (altfel doar le arata)")
    ap.add_argument("--restore", action="store_true", help="anuleaza modificarile facute anterior")
    ap.add_argument("--no-animations", action="store_true", help="opreste complet animatiile (0 in loc de 0.5)")
    args = ap.parse_args()

    if not shutil.which("adb"):
        sys.exit("Nu gasesc 'adb'. Instaleaza Android SDK Platform-Tools (vezi README).")
    target = connect(args.ip)
    brand = adb(target, "shell", "getprop", "ro.product.manufacturer")
    model = adb(target, "shell", "getprop", "ro.product.model")
    print(f"Conectat la {brand} {model} ({target})\n")

    backup = pathlib.Path(__file__).with_name(f"backup_{args.ip.replace(':', '_')}.json")

    if args.restore:
        if not backup.exists():
            sys.exit(f"Nu exista {backup.name}; nu am ce restaura.")
        data = json.loads(backup.read_text())
        for key, value in data["animations"].items():
            adb(target, "shell", "settings", "put", "global", key, value or "1.0")
        for pkg in data["disabled"]:
            adb(target, "shell", "pm", "enable", pkg, check=False)
            print(f"  reactivat {pkg}")
        backup.unlink()
        print("\nGata, televizorul a revenit la setarile anterioare.")
        return

    scale = "0" if args.no_animations else FAST_SCALE
    current = {k: adb(target, "shell", "settings", "get", "global", k) for k in ANIMATIONS}
    print(f"Animatii: {current} -> {scale}")

    found = suggestions(target)
    print("\nAplicatii preinstalate care par promotii/extra (verifica-le inainte sa alegi):")
    picked = choose(found) if found else []

    if not args.apply:
        print(f"\n[MOD TEST] As seta animatiile la {scale} si as dezactiva: {picked or 'nimic'}")
        print("Ruleaza din nou cu --apply ca sa aplici.")
        return

    previous = json.loads(backup.read_text()) if backup.exists() else {"animations": current, "disabled": []}
    for key in ANIMATIONS:
        adb(target, "shell", "settings", "put", "global", key, scale)
    for pkg in picked:
        out = adb(target, "shell", "pm", "disable-user", "--user", "0", pkg, check=False)
        print(f"  {pkg}: {out or 'eroare'}")
        if "disabled" in out and pkg not in previous["disabled"]:
            previous["disabled"].append(pkg)
    backup.write_text(json.dumps(previous, indent=2))
    print(f"\nGata. Backup salvat in {backup.name} (pentru --restore).")
    print("Reporneste televizorul ca sa vezi efectul complet.")


if __name__ == "__main__":
    main()
