#!/usr/bin/env python3
"""A simulated ResQMesh phone, for testing discovery with only one phone.

Speaks the protocol from PROTOCOL.md: announces itself with HELLO every 5 s,
answers DISCOVERY and NAME_CHECK, accepts TCP control connections (HELLO
handshake, PING/PONG, REGISTER), receives chat messages (MESSAGE_ACK and
MESSAGE_DELIVERED back) and, with --echo, answers each one. Receives files
the app sends (data connections on --file-port, checksum verified, resume
supported) and sends files given with --send-file. Prints what it hears.
Standard library only.

Same Wi-Fi as a real phone (Mac and phone on one network):
    python3 tool/lan_peer_sim.py --name "Mac Tester"

Android emulator (forward the port first):
    adb emu redir add udp:28760:28760
    python3 tool/lan_peer_sim.py --name "Mac Tester" --listen 28770 \
        --target 127.0.0.1:28760

Files from the emulator to the Mac arrive in --save-dir. Files from the Mac
to the emulator need the app's file port forwarded first:
    adb forward tcp:28762 tcp:28762
    python3 tool/lan_peer_sim.py ... --send-file ~/big.bin \
        --app-file-addr 127.0.0.1:28762

Ctrl-C sends GOODBYE and stops.
"""

import argparse
import datetime
import hashlib
import json
import mimetypes
import os
import re
import select
import socket
import struct
import threading
import time
import uuid

MAGIC = b"RQM1"
PORT = 28760


def now():
    t = datetime.datetime.now(datetime.timezone.utc)
    return t.isoformat(timespec="milliseconds").replace("+00:00", "Z")


class Peer:
    def __init__(self, name, listen, targets, tcp_port, echo=False, device_id=None,
                 file_port=28772, save_dir="sim_received", send_files=(), app_file_addr=None):
        # Like a real phone, the same simulated phone keeps its device ID
        # between runs, so chats and queued messages carry over.
        self.id = device_id or str(uuid.uuid5(uuid.NAMESPACE_URL, f"resqmesh-sim:{name}"))
        self.name = name
        self.claimed_at = now()
        self.targets = targets
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        self.sock.bind(("0.0.0.0", listen))
        self.seen = {}
        self.tcp = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.tcp.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.tcp.bind(("0.0.0.0", tcp_port))
        self.tcp.listen(8)
        self.tcp_port = self.tcp.getsockname()[1]
        self.conns = {}  # socket -> {"buf": bytes, "peer": name or None}
        self.echo = echo
        self.echoes = []  # (due time, socket, receiver id, text)
        # Files (PROTOCOL.md §4.4).
        self.files = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.files.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.files.bind(("0.0.0.0", file_port))
        self.files.listen(8)
        self.file_port = self.files.getsockname()[1]
        self.save_dir = save_dir
        os.makedirs(save_dir, exist_ok=True)
        self.expected = {}  # fileId -> file announced in a MESSAGE
        self.to_send = list(send_files)
        self.outgoing = {}  # message ID -> (path, file dict, receiver, address, port)
        self.app_file_addr = app_file_addr

    def body(self, kind, payload, receiver="*"):
        return {
            "protocolVersion": 1,
            "type": kind,
            "messageId": str(uuid.uuid4()),
            "senderId": self.id,
            "senderName": self.name,
            "receiverId": receiver,
            "timestamp": now(),
            "payload": payload,
        }

    def packet(self, kind, payload, receiver="*"):
        return MAGIC + json.dumps(self.body(kind, payload, receiver)).encode()

    def frame(self, kind, payload, receiver="*"):
        data = json.dumps(self.body(kind, payload, receiver)).encode()
        return struct.pack(">BI", 1, len(data)) + data

    def announcement(self):
        return {
            "tcpPort": self.tcp_port,
            "appVersion": "sim",
            "minProtocol": 1,
            "maxProtocol": 1,
            "nameClaimedAt": self.claimed_at,
            "capabilities": [],
            "filePort": self.file_port,
        }

    def send(self, data, address):
        try:
            self.sock.sendto(data, address)
        except OSError as e:
            print(f"  ! send to {address} failed: {e}")

    def announce(self, kind="HELLO"):
        data = self.packet(kind, self.announcement() if kind == "HELLO" else {})
        for target in self.targets:
            self.send(data, target)

    def handle(self, data, address):
        if not data.startswith(MAGIC):
            return
        try:
            p = json.loads(data[len(MAGIC):])
        except ValueError:
            print(f"  ! malformed datagram from {address}")
            return
        if p.get("senderId") == self.id:
            return
        kind, sender, name = p.get("type"), p.get("senderId", "?"), p.get("senderName", "")
        if kind in ("HELLO", "DISCOVERY_RESPONSE"):
            if sender not in self.seen:
                print(f"+ found {name!r} ({sender[:4]}) at {address[0]}")
            elif self.seen[sender] != name:
                print(f"~ {sender[:4]} is now {name!r}")
            self.seen[sender] = name
        elif kind == "DISCOVERY":
            print(f"? DISCOVERY from {address[0]}:{address[1]}, answering")
            self.send(
                self.packet("DISCOVERY_RESPONSE", self.announcement(), sender),
                address,
            )
        elif kind == "NAME_CHECK":
            candidate = p.get("payload", {}).get("candidateName", "")
            taken = candidate.strip().lower() == self.name.strip().lower()
            print(f"? NAME_CHECK {candidate!r} -> {'taken' if taken else 'free'}")
            if taken:
                payload = {
                    "result": "nameTaken",
                    "name": self.name,
                    "holderId": self.id,
                    "holderClaimedAt": self.claimed_at,
                }
                self.send(self.packet("REGISTER_RESPONSE", payload, sender), address)
        elif kind == "GOODBYE":
            print(f"- {name!r} ({sender[:4]}) left")
            self.seen.pop(sender, None)

    def accept(self):
        conn, address = self.tcp.accept()
        print(f"> TCP connection from {address[0]}:{address[1]}")
        conn.sendall(self.frame("HELLO", self.announcement()))
        self.conns[conn] = {"buf": b"", "peer": None, "id": "*"}

    def on_tcp(self, conn):
        state = self.conns[conn]
        try:
            data = conn.recv(65536)
        except OSError:
            data = b""
        if not data:
            print(f"< TCP connection closed ({state['peer']})")
            conn.close()
            del self.conns[conn]
            return
        state["buf"] += data
        while len(state["buf"]) >= 5:
            kind, length = struct.unpack(">BI", state["buf"][:5])
            if len(state["buf"]) < 5 + length:
                break
            body, state["buf"] = state["buf"][5:5 + length], state["buf"][5 + length:]
            if kind != 1:
                continue
            p = json.loads(body)
            kind_name, sender = p.get("type"), p.get("senderId", "*")
            if kind_name == "HELLO":
                first = state["peer"] is None
                state["peer"], state["id"] = p.get("senderName"), sender
                state["filePort"] = p.get("payload", {}).get("filePort")
                if first:
                    print(f"= TCP handshake with {state['peer']!r} ({sender[:4]})")
                    self.offer_files(conn, state)
            elif kind_name == "PING":
                nonce = p["payload"]["nonce"]
                conn.sendall(self.frame("PONG", {"nonce": nonce}, sender))
            elif kind_name == "MESSAGE":
                mid, text = p["messageId"], p["payload"].get("text")
                f = p["payload"].get("file")
                if f:
                    self.expected[f["fileId"]] = f
                    print(f"📎 {state['peer']}: {f['name']!r} ({f['size']:,} bytes), waiting for the data")
                else:
                    to = " (to everyone)" if p["payload"].get("audience") == "broadcast" else ""
                    print(f"✉ {state['peer']}{to}: {text!r}")
                conn.sendall(self.frame("MESSAGE_ACK", {"ackFor": mid}, sender))
                conn.sendall(self.frame("MESSAGE_DELIVERED", {"messageIds": [mid]}, sender))
                if self.echo and text:
                    self.echoes.append((time.monotonic() + 1.5, conn, sender, text))
            elif kind_name in ("MESSAGE_ACK", "MESSAGE_DELIVERED", "MESSAGE_READ"):
                print(f"  {kind_name} from {state['peer']!r}")
                ids = p["payload"].get("messageIds") or [p["payload"].get("ackFor")]
                for mid in ids:
                    job = self.outgoing.pop(mid, None)
                    if job:
                        threading.Thread(target=self.upload, args=job, daemon=True).start()
            elif kind_name == "REGISTER":
                new = p["payload"]["name"]
                print(f"~ REGISTER: {state['peer']!r} is now {new!r}")
                state["peer"] = new
                conn.sendall(self.frame("REGISTER_RESPONSE", {"result": "ok", "name": new}, sender))
            else:
                print(f"  TCP {kind_name} from {state['peer']!r}")

    # ------------------------------------------------------------------ files

    def offer_files(self, conn, state):
        """Announces each --send-file with a file MESSAGE; the data follows
        once the app confirms it."""
        for path in self.to_send:
            size = os.path.getsize(path)
            print(f"# hashing {path} ({size:,} bytes)…")
            digest = hashlib.sha256()
            with open(path, "rb") as fh:
                for block in iter(lambda: fh.read(1 << 20), b""):
                    digest.update(block)
            f = {
                "fileId": str(uuid.uuid4()),
                "name": os.path.basename(path),
                "size": size,
                "mimeType": mimetypes.guess_type(path)[0] or "application/octet-stream",
                "sha256": digest.hexdigest(),
            }
            payload = {"messageType": "file", "audience": "direct", "text": None,
                       "replyToId": None, "file": f}
            body = self.body("MESSAGE", payload, state["id"])
            data = json.dumps(body).encode()
            conn.sendall(struct.pack(">BI", 1, len(data)) + data)
            if self.app_file_addr:
                host, port = self.app_file_addr
            else:
                host, port = conn.getpeername()[0], state.get("filePort")
            self.outgoing[body["messageId"]] = (path, f, state["id"], host, port, body["messageId"])
            print(f"📎 offered {f['name']!r} to {state['peer']!r}")
        self.to_send = []

    @staticmethod
    def read_frame(sock):
        header = Peer.read_exact(sock, 5)
        kind, length = struct.unpack(">BI", header)
        return kind, Peer.read_exact(sock, length)

    @staticmethod
    def read_exact(sock, n):
        data = bytearray()
        while len(data) < n:
            chunk = sock.recv(min(n - len(data), 1 << 20))
            if not chunk:
                raise ConnectionError("closed")
            data += chunk
        return bytes(data)

    def send_frame(self, sock, kind, payload, receiver):
        data = json.dumps(self.body(kind, payload, receiver)).encode()
        sock.sendall(struct.pack(">BI", 1, len(data)) + data)

    def upload(self, path, f, receiver, host, port, message_id):
        if not port:
            print("  ! the app announced no file port")
            return
        try:
            sock = socket.create_connection((host, port), timeout=10)
            sock.settimeout(120)
            self.send_frame(sock, "HELLO", self.announcement(), receiver)
            _, body = self.read_frame(sock)  # the app's HELLO
            offer = {"fileId": f["fileId"], "chatMessageId": message_id,
                     "fileName": f["name"], "fileSize": f["size"],
                     "mimeType": f["mimeType"], "sha256": f["sha256"]}
            self.send_frame(sock, "FILE_OFFER", offer, receiver)
            _, body = self.read_frame(sock)
            answer = json.loads(body)
            if answer["type"] == "FILE_COMPLETE":
                print(f"⇡ {f['name']!r}: the app already has it (duplicate)")
                return
            if answer["type"] != "FILE_ACCEPT":
                print(f"  ✗ {f['name']!r}: {answer['type']} {answer['payload']}")
                return
            offset = answer["payload"]["offset"]
            print(f"⇡ sending {f['name']!r} from byte {offset:,}")
            start, sent = time.monotonic(), offset
            with open(path, "rb") as fh:
                fh.seek(offset)
                for block in iter(lambda: fh.read(256 * 1024), b""):
                    sock.sendall(struct.pack(">BI", 2, len(block)) + block)
                    sent += len(block)
            _, body = self.read_frame(sock)
            done = json.loads(body)
            seconds = max(time.monotonic() - start, 0.001)
            mb = (sent - offset) / 1e6
            print(f"⇡ {f['name']!r}: {done['type']} · {mb:.1f} MB in {seconds:.1f} s ({mb / seconds:.1f} MB/s)")
            sock.close()
        except (OSError, ConnectionError, ValueError) as e:
            print(f"  ! sending {f['name']!r} failed: {e}")

    def accept_file(self):
        conn, address = self.files.accept()
        threading.Thread(target=self.download, args=(conn,), daemon=True).start()

    def download(self, sock):
        try:
            sock.settimeout(120)
            _, body = self.read_frame(sock)
            hello = json.loads(body)
            peer = hello["senderId"]
            self.send_frame(sock, "HELLO", self.announcement(), peer)
            _, body = self.read_frame(sock)
            offer = json.loads(body)["payload"]
            fid = offer["fileId"]
            known = self.expected.get(fid)
            if not known or known["sha256"] != offer["sha256"] or known["size"] != offer["fileSize"]:
                self.send_frame(sock, "FILE_REJECT", {"fileId": fid, "reason": "invalid"}, peer)
                print(f"  ✗ rejected unexpected file {offer.get('fileName')!r}")
                return
            part = os.path.join(self.save_dir, f"{fid}.part")
            offset = os.path.getsize(part) if os.path.exists(part) else 0
            if offset > offer["fileSize"]:
                os.remove(part)
                offset = 0
            digest = hashlib.sha256()
            if offset:
                with open(part, "rb") as fh:
                    for block in iter(lambda: fh.read(1 << 20), b""):
                        digest.update(block)
            self.send_frame(sock, "FILE_ACCEPT", {"fileId": fid, "offset": offset}, peer)
            print(f"⇣ receiving {offer['fileName']!r} from byte {offset:,}")
            start, received, size = time.monotonic(), offset, offer["fileSize"]
            with open(part, "ab") as out:
                while received < size:
                    kind, body = self.read_frame(sock)
                    if kind == 1:
                        p = json.loads(body)
                        print(f"  ⇣ {p['type']} {p['payload']}")
                        return
                    out.write(body)
                    digest.update(body)
                    received += len(body)
                out.flush()
                os.fsync(out.fileno())
            if digest.hexdigest() != offer["sha256"]:
                os.remove(part)
                self.send_frame(sock, "FILE_CANCEL", {"fileId": fid, "reason": "checksumMismatch"}, peer)
                print(f"  ✗ {offer['fileName']!r}: checksum mismatch")
                return
            name = re.sub(r'[\\/:*?"<>|]', "_", os.path.basename(offer["fileName"])) or "file"
            target = os.path.join(self.save_dir, name)
            n = 1
            while os.path.exists(target):
                stem, ext = os.path.splitext(name)
                target = os.path.join(self.save_dir, f"{stem} ({n}){ext}")
                n += 1
            os.rename(part, target)
            self.send_frame(sock, "FILE_COMPLETE", {"fileId": fid, "sha256": offer["sha256"]}, peer)
            seconds = max(time.monotonic() - start, 0.001)
            mb = (received - offset) / 1e6
            print(f"⇣ {offer['fileName']!r} saved as {target} · checksum OK · {mb:.1f} MB in {seconds:.1f} s ({mb / seconds:.1f} MB/s)")
        except (OSError, ConnectionError, ValueError, KeyError) as e:
            print(f"  ! receiving failed (partial file kept): {e}")
        finally:
            sock.close()

    def send_echoes(self):
        now = time.monotonic()
        for item in [e for e in self.echoes if e[0] <= now]:
            self.echoes.remove(item)
            _, conn, receiver, text = item
            if conn not in self.conns:
                continue
            payload = {"messageType": "text", "audience": "direct",
                       "text": f"You said: {text}", "replyToId": None}
            conn.sendall(self.frame("MESSAGE", payload, receiver))
            print(f"✉ echo sent to {self.conns[conn]['peer']!r}")

    def run(self):
        print(f"Simulated phone {self.name!r} ({self.id[:4]}), sending to {self.targets}, TCP on {self.tcp_port}, files on {self.file_port}")
        self.announce("DISCOVERY")
        next_hello = 0.0
        try:
            while True:
                if time.monotonic() >= next_hello:
                    self.announce()
                    next_hello = time.monotonic() + 5
                ready, _, _ = select.select([self.sock, self.tcp, self.files, *self.conns], [], [], 0.5)
                for r in ready:
                    if r is self.sock:
                        data, address = self.sock.recvfrom(2048)
                        self.handle(data, address)
                    elif r is self.tcp:
                        self.accept()
                    elif r is self.files:
                        self.accept_file()
                    else:
                        self.on_tcp(r)
                self.send_echoes()
        except KeyboardInterrupt:
            for target in self.targets:
                self.send(self.packet("GOODBYE", {"reason": "appStopped"}), target)
            print("\nSent GOODBYE")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--name", default="Mac Tester", help="name to announce (2-30 characters)")
    parser.add_argument("--listen", type=int, default=PORT, help=f"UDP port to listen on (default {PORT})")
    parser.add_argument("--tcp", type=int, default=28771, help="TCP port to accept connections on (default 28771)")
    parser.add_argument("--echo", action="store_true", help="answer every chat message")
    parser.add_argument("--id", help="device ID (default: fixed for each --name)")
    parser.add_argument("--file-port", type=int, default=28772, help="port for file data connections (default 28772)")
    parser.add_argument("--save-dir", default="sim_received", help="where received files go (default ./sim_received)")
    parser.add_argument("--send-file", action="append", default=[], help="send this file to the app once connected (repeatable)")
    parser.add_argument("--app-file-addr", help="host:port of the app's file port, e.g. 127.0.0.1:28762 after adb forward")
    parser.add_argument(
        "--target",
        action="append",
        help=f"host:port to announce to (repeatable; default 255.255.255.255:{PORT})",
    )
    args = parser.parse_args()
    targets = []
    for t in args.target or [f"255.255.255.255:{PORT}"]:
        host, port = t.rsplit(":", 1)
        targets.append((host, int(port)))
    app_file = None
    if args.app_file_addr:
        host, port = args.app_file_addr.rsplit(":", 1)
        app_file = (host, int(port))
    Peer(args.name, args.listen, targets, args.tcp, args.echo, args.id,
         args.file_port, args.save_dir, args.send_file, app_file).run()


if __name__ == "__main__":
    main()
