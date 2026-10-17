#!/usr/bin/env python3
"""AirDrop for MacShell, speaking LocalSend's protocol (v2).

Any device running LocalSend — phone, laptop, tablet — shows up here, and anything sent from here lands
in its downloads. Nothing is installed or configured: discovery is a UDP multicast announcement on the
local network, and sending is two HTTPS-less HTTP calls.

    macshell-airdrop.py discover [seconds]        print one JSON object per device found
    macshell-airdrop.py send <ip> <port> <file…>  send files to a device, print progress as JSON lines
"""
import json
import mimetypes
import os
import random
import socket
import string
import sys
import threading
import time
import urllib.error
import urllib.request

MULTICAST = "224.0.0.167"
PORT = 53317
ALIAS = os.environ.get("MACSHELL_AIRDROP_ALIAS") or socket.gethostname()
FINGERPRINT = "".join(random.choice(string.hexdigits.lower()) for _ in range(64))

ME = {
    "alias": ALIAS,
    "version": "2.1",
    "deviceModel": "MacShell",
    "deviceType": "desktop",
    "fingerprint": FINGERPRINT,
    "port": PORT,
    "protocol": "http",
    "download": False,
    "announce": True,
}


def discover(seconds=3.0):
    """Announce ourselves and print every device that answers."""
    seen = {}
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEPORT, 1)
    except (AttributeError, OSError):
        pass
    try:
        sock.bind(("", PORT))
        mreq = socket.inet_aton(MULTICAST) + socket.inet_aton("0.0.0.0")
        sock.setsockopt(socket.IPPROTO_IP, socket.IP_ADD_MEMBERSHIP, mreq)
    except OSError:
        # another LocalSend is already bound to the port; we can still announce and catch unicast replies
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)

    payload = json.dumps(ME).encode()
    for _ in range(3):
        try:
            sock.sendto(payload, (MULTICAST, PORT))
        except OSError:
            pass
        time.sleep(0.15)

    sock.settimeout(0.4)
    end = time.time() + float(seconds)
    while time.time() < end:
        try:
            data, addr = sock.recvfrom(8192)
        except socket.timeout:
            continue
        except OSError:
            break
        try:
            d = json.loads(data.decode())
        except (ValueError, UnicodeDecodeError):
            continue
        fp = d.get("fingerprint")
        if not fp or fp == FINGERPRINT or fp in seen:
            continue
        seen[fp] = True
        print(json.dumps({
            "alias": d.get("alias", addr[0]),
            "ip": addr[0],
            "port": d.get("port", PORT),
            "deviceModel": d.get("deviceModel", ""),
            "deviceType": d.get("deviceType", "desktop"),
            "fingerprint": fp,
        }), flush=True)
        # answering an announce is what makes us visible on their screen
        if d.get("announce"):
            reply = dict(ME, announce=False)
            try:
                sock.sendto(json.dumps(reply).encode(), addr)
            except OSError:
                pass
    return 0


def _post(url, obj, timeout=10):
    req = urllib.request.Request(url, data=json.dumps(obj).encode(),
                                 headers={"Content-Type": "application/json"}, method="POST")
    with urllib.request.urlopen(req, timeout=timeout) as r:
        body = r.read().decode()
    return json.loads(body) if body.strip() else {}


def send(ip, port, paths):
    files = {}
    for i, p in enumerate(paths):
        if not os.path.isfile(p):
            continue
        fid = str(i)
        files[fid] = {
            "id": fid,
            "fileName": os.path.basename(p),
            "size": os.path.getsize(p),
            "fileType": mimetypes.guess_type(p)[0] or "application/octet-stream",
        }
    if not files:
        print(json.dumps({"event": "error", "message": "no files"}), flush=True)
        return 1

    base = "http://%s:%s/api/localsend/v2" % (ip, port)
    print(json.dumps({"event": "asking"}), flush=True)
    try:
        res = _post(base + "/prepare-upload", {"info": ME, "files": files}, timeout=90)
    except urllib.error.HTTPError as e:
        msg = "declined" if e.code in (403, 204) else "HTTP %s" % e.code
        print(json.dumps({"event": "error", "message": msg}), flush=True)
        return 1
    except OSError as e:
        print(json.dumps({"event": "error", "message": str(e)}), flush=True)
        return 1

    session = res.get("sessionId", "")
    tokens = res.get("files", {})
    sent = 0
    for fid, token in tokens.items():
        path = paths[int(fid)]
        url = "%s/upload?sessionId=%s&fileId=%s&token=%s" % (base, session, fid, token)
        print(json.dumps({"event": "sending", "file": os.path.basename(path)}), flush=True)
        try:
            with open(path, "rb") as fh:
                req = urllib.request.Request(url, data=fh.read(),
                                             headers={"Content-Type": "application/octet-stream"}, method="POST")
                urllib.request.urlopen(req, timeout=600).read()
            sent += 1
        except OSError as e:
            print(json.dumps({"event": "error", "file": os.path.basename(path), "message": str(e)}), flush=True)
    print(json.dumps({"event": "done", "sent": sent, "total": len(files)}), flush=True)
    return 0 if sent else 1


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    cmd = argv[1]
    if cmd == "discover":
        return discover(argv[2] if len(argv) > 2 else 3.0)
    if cmd == "send" and len(argv) >= 5:
        return send(argv[2], argv[3], argv[4:])
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
