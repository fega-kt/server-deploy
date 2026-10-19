#!/usr/bin/env python3
"""
Pull một image và in tiến trình dễ đọc cho log deploy (GitHub Actions không phải terminal: `docker compose pull`
in hàng nghìn dòng "Downloading 62.91MB" không có tổng). Gọi thẳng Docker Engine API qua socket để có
current/total từng lớp, cứ PULL_PROGRESS_INTERVAL giây in một khối: tổng đã tải / cần tải, tốc độ, còn lại,
và thanh tiến trình của các lớp đang tải.

Dùng: python3 pull-progress.py <image>   (vd ghcr.io/fega-kt/backend:latest)
Đăng nhập registry lấy từ $DOCKER_CONFIG/config.json hoặc ~/.docker/config.json (như docker login ghi ra).
Lỗi (không đọc được socket, registry từ chối…) thì thoát mã khác 0 để script gọi quay về `docker compose pull`.
Chỉ dùng thư viện chuẩn.
"""
import base64
import http.client
import json
import os
import socket
import sys
import time
import urllib.parse

SOCKET_PATH = os.environ.get("DOCKER_SOCKET", "/var/run/docker.sock")
INTERVAL = float(os.environ.get("PULL_PROGRESS_INTERVAL", "5"))
BAR_WIDTH = 30
MB = 1024 * 1024


class UnixHTTPConnection(http.client.HTTPConnection):
    def __init__(self, path):
        super().__init__("localhost", timeout=None)
        self.socket_path = path

    def connect(self):
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.connect(self.socket_path)


def split_ref(ref):
    """ghcr.io/org/app:tag → (ghcr.io/org/app, tag); …@sha256:… → (…, sha256:…); không có tag → latest"""
    if "@" in ref:
        return tuple(ref.split("@", 1))
    slash, colon = ref.rfind("/"), ref.rfind(":")
    return (ref[:colon], ref[colon + 1:]) if colon > slash else (ref, "latest")


def registry_host(name):
    first = name.split("/")[0]
    return first if "/" in name and ("." in first or ":" in first or first == "localhost") else "https://index.docker.io/v1/"


def registry_auth(name):
    """Header X-Registry-Auth từ config.json của docker login; không có thì pull ẩn danh (image công khai)"""
    host = registry_host(name)
    config_dir = os.environ.get("DOCKER_CONFIG") or os.path.expanduser("~/.docker")
    try:
        with open(os.path.join(config_dir, "config.json")) as f:
            auths = json.load(f).get("auths", {})
    except (OSError, ValueError):
        return None
    entry = auths.get(host) or auths.get("https://" + host) or {}
    if "auth" not in entry:
        return None
    user, _, password = base64.b64decode(entry["auth"]).decode().partition(":")
    payload = json.dumps({"username": user, "password": password, "serveraddress": host})
    return base64.urlsafe_b64encode(payload.encode()).decode()


def mb(n):
    return f"{n / MB:.1f}"


def duration(seconds):
    seconds = int(seconds)
    return f"{seconds // 60}m{seconds % 60:02d}s" if seconds >= 60 else f"{seconds}s"


def bar(current, total):
    filled = int(BAR_WIDTH * current / total) if total else 0
    return "[" + "=" * max(filled - 1, 0) + (">" if filled else "") + " " * (BAR_WIDTH - filled) + "]"


class Progress:
    def __init__(self, image):
        self.image = image
        self.layers = {}  # id -> {"state", "current", "total"}
        self.started = time.monotonic()
        self.last_print = 0.0
        self.last_bytes = 0
        self.last_bytes_at = self.started

    def update(self, event):
        layer_id, status = event.get("id"), event.get("status", "")
        if not layer_id or status.startswith(("Pulling from", "Digest", "Status")):
            return
        layer = self.layers.setdefault(layer_id, {"state": "waiting", "current": 0, "total": 0})
        detail = event.get("progressDetail") or {}
        if status == "Already exists":
            layer["state"] = "exists"
        elif status == "Downloading":
            layer.update(state="downloading", current=detail.get("current", 0), total=detail.get("total", layer["total"]))
        elif status in ("Verifying Checksum", "Download complete", "Extracting", "Pull complete"):
            layer["state"] = "done" if status == "Pull complete" else "downloaded"
            layer["current"] = layer["total"] = max(layer["total"], layer["current"])

    def totals(self):
        needed = [l for l in self.layers.values() if l["state"] != "exists"]
        done_bytes = sum(l["current"] for l in needed)
        known_total = sum(l["total"] for l in needed)
        # Lớp chưa bắt đầu tải chưa biết dung lượng (lớp rất nhỏ xong luôn, không báo dung lượng: không tính)
        unknown = sum(1 for l in needed if not l["total"] and l["state"] in ("waiting", "downloading"))
        return done_bytes, known_total, unknown

    def print_block(self, force=False):
        now = time.monotonic()
        if not force and now - self.last_print < INTERVAL:
            return
        self.last_print = now
        done_bytes, known_total, unknown = self.totals()
        speed = (done_bytes - self.last_bytes) / max(now - self.last_bytes_at, 1e-6)
        self.last_bytes, self.last_bytes_at = done_bytes, now
        states = [l["state"] for l in self.layers.values()]
        counts = {s: states.count(s) for s in ("exists", "done", "downloaded", "downloading", "waiting")}
        percent = f" ({done_bytes * 100 // known_total}%)" if known_total else ""
        remaining = f" · còn ~{duration((known_total - done_bytes) / speed)}" if speed > 0 and known_total > done_bytes else ""
        unknown_note = f" (+{unknown} lớp chưa rõ dung lượng)" if unknown else ""
        print(
            f"{time.strftime('%H:%M:%S')}  {mb(done_bytes)} / {mb(known_total)} MB{percent}{unknown_note}"
            f" · {speed / MB:.2f} MB/s{remaining}"
            f" · {len(states)} lớp: {counts['exists']} có sẵn, {counts['done'] + counts['downloaded']} xong,"
            f" {counts['downloading']} đang tải, {counts['waiting']} chờ",
            flush=True,
        )
        for layer_id, layer in self.layers.items():
            if layer["state"] == "downloading" and layer["total"]:
                print(f"  {layer_id} {bar(layer['current'], layer['total'])} {mb(layer['current']):>7} / {mb(layer['total'])} MB", flush=True)

    def summary(self):
        done_bytes, _, _ = self.totals()
        elapsed = time.monotonic() - self.started
        print(f"[pull] xong {self.image}: tải {mb(done_bytes)} MB trong {duration(elapsed)} ({done_bytes / MB / max(elapsed, 1e-6):.2f} MB/s)", flush=True)


def pull(image):
    name, tag = split_ref(image)
    query = urllib.parse.urlencode({"fromImage": name, "tag": tag})
    headers = {}
    auth = registry_auth(name)
    if auth:
        headers["X-Registry-Auth"] = auth

    print(f"[pull] {image}", flush=True)
    conn = UnixHTTPConnection(SOCKET_PATH)
    conn.request("POST", f"/images/create?{query}", headers=headers)
    res = conn.getresponse()
    if res.status != 200:
        print(f"[pull] lỗi {res.status}: {res.read().decode(errors='replace').strip()}", file=sys.stderr, flush=True)
        return 1

    progress = Progress(image)
    for raw in res:
        line = raw.strip()
        if not line:
            continue
        try:
            event = json.loads(line)
        except ValueError:
            continue
        if "error" in event:
            print(f"[pull] lỗi: {event['error']}", file=sys.stderr, flush=True)
            return 1
        progress.update(event)
        progress.print_block()
    progress.print_block(force=True)
    progress.summary()
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Dùng: pull-progress.py <image>", file=sys.stderr)
        sys.exit(2)
    try:
        sys.exit(pull(sys.argv[1]))
    except OSError as error:
        print(f"[pull] không gọi được Docker ({SOCKET_PATH}): {error}", file=sys.stderr, flush=True)
        sys.exit(1)
