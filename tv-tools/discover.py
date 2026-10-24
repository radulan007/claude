#!/usr/bin/env python3
"""Detecteaza televizoarele smart din reteaua locala (doar biblioteca standard Python).

Rulare:  python discover.py            (scaneaza automat subnetul /24 al calculatorului)
         python discover.py 192.168.1  (scaneaza explicit 192.168.1.1-254)
"""
import concurrent.futures
import json
import re
import socket
import sys
import urllib.request
import xml.etree.ElementTree as ET

PORTS = {
    8001: "Samsung Tizen (API)",
    8002: "Samsung Tizen (API securizat)",
    5555: "ADB - Android/Google TV (debug in retea ACTIV)",
    6466: "Android TV Remote",
    8008: "Chromecast / Google Cast",
    8009: "Chromecast / Google Cast",
    1925: "Philips JointSPACE API",
    1926: "Philips JointSPACE API (securizat)",
}


def local_prefix():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 80))  # nu trimite nimic, doar alege interfata
        ip = s.getsockname()[0]
    finally:
        s.close()
    return ip.rsplit(".", 1)[0]


def ssdp_search(timeout=4):
    """Trimite M-SEARCH SSDP si intoarce {ip: url_descriere}."""
    msg = (
        "M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\n"
        'MAN: "ssdp:discover"\r\nMX: 3\r\nST: ssdp:all\r\n\r\n'
    ).encode()
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
    sock.settimeout(timeout)
    sock.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_TTL, 2)
    found = {}
    try:
        for _ in range(2):
            sock.sendto(msg, ("239.255.255.250", 1900))
        while True:
            data, (ip, _) = sock.recvfrom(65507)
            m = re.search(r"(?im)^location:\s*(\S+)", data.decode(errors="ignore"))
            if m:
                found.setdefault(ip, set()).add(m.group(1))
    except socket.timeout:
        pass
    finally:
        sock.close()
    return found


def fetch(url, timeout=3):
    with urllib.request.urlopen(url, timeout=timeout) as r:
        return r.read()


def describe(urls):
    """Citeste descrierea UPnP si intoarce (producator, model, nume)."""
    for url in urls:
        try:
            root = ET.fromstring(fetch(url))
        except Exception:
            continue
        def find(tag):
            el = root.find(f".//{{*}}device/{{*}}{tag}")
            return el.text.strip() if el is not None and el.text else ""
        if find("manufacturer") or find("modelName"):
            return find("manufacturer"), find("modelName"), find("friendlyName")
    return "", "", ""


def open_ports(ip):
    res = []
    for port in PORTS:
        with socket.socket() as s:
            s.settimeout(0.4)
            if s.connect_ex((ip, port)) == 0:
                res.append(port)
    return ip, res


def samsung_info(ip):
    try:
        d = json.loads(fetch(f"http://{ip}:8001/api/v2/"))["device"]
        return d.get("modelName", ""), d.get("name", ""), d.get("OS", "")
    except Exception:
        return None


def main():
    prefix = sys.argv[1] if len(sys.argv) > 1 else local_prefix()
    print(f"Caut prin SSDP si scanez {prefix}.1-254 ... (~30 secunde)\n")

    with concurrent.futures.ThreadPoolExecutor(max_workers=128) as ex:
        ssdp_future = ex.submit(ssdp_search)
        scans = dict(ex.map(open_ports, [f"{prefix}.{i}" for i in range(1, 255)]))
        ssdp = ssdp_future.result()

    candidates = sorted(
        {ip for ip, p in scans.items() if p} | set(ssdp),
        key=lambda ip: tuple(int(x) for x in ip.split(".")),
    )
    tvs = []
    for ip in candidates:
        maker, model, name = describe(ssdp.get(ip, []))
        ports = scans.get(ip, [])
        if 8001 in ports or 8002 in ports:
            info = samsung_info(ip)
            if info:
                maker, model, name = "Samsung", info[0], f"{info[1]} ({info[2]})"
        text = f"{maker} {model} {name}".lower()
        is_tv = any(k in text for k in ("tv", "samsung", "philips", "tpvision", "tcl", "sony", "bravia")) \
            or any(p in ports for p in (8001, 8002, 5555, 6466, 1925, 1926))
        if is_tv:
            tvs.append((ip, maker, model, name, ports))

    if not tvs:
        print("Nu am gasit televizoare. Verifica sa fie pornite si in aceeasi retea cu calculatorul.")
        return
    for ip, maker, model, name, ports in tvs:
        print(f"== {ip}  {maker} {model}  {name}".rstrip())
        for p in ports:
            print(f"     port {p}: {PORTS[p]}")
        if 5555 in ports:
            print(f"     -> poti rula: python android_tv_optimize.py {ip}")
        print()
    print("Daca un Android TV nu are portul 5555 deschis, activeaza 'Network debugging' (vezi README).")


if __name__ == "__main__":
    main()
