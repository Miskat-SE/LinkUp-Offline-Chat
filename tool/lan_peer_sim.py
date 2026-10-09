#!/usr/bin/env python3
"""A simulated ResQMesh phone, for testing discovery with only one phone.

Speaks the protocol from PROTOCOL.md: announces itself with HELLO every 5 s,
answers DISCOVERY and NAME_CHECK, accepts TCP control connections (HELLO
handshake, PING/PONG, REGISTER), and prints what it hears. Standard library
only.

Same Wi-Fi as a real phone (Mac and phone on one network):
    python3 tool/lan_peer_sim.py --name "Mac Tester"

Android emulator (forward the port first):
    adb emu redir add udp:28760:28760
    python3 tool/lan_peer_sim.py --name "Mac Tester" --listen 28770 \
        --target 127.0.0.1:28760

Ctrl-C sends GOODBYE and stops.
"""

import argparse
import datetime
import json
import select
import socket
import struct
import time
import uuid

MAGIC = b"RQM1"
PORT = 28760


def now():
    t = datetime.datetime.now(datetime.timezone.utc)
    return t.isoformat(timespec="milliseconds").replace("+00:00", "Z")


class Peer:
    def __init__(self, name, listen, targets, tcp_port):
        self.id = str(uuid.uuid4())
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
                state["peer"], state["id"] = p.get("senderName"), sender
                print(f"= TCP handshake with {state['peer']!r} ({sender[:4]})")
            elif kind_name == "PING":
                nonce = p["payload"]["nonce"]
                conn.sendall(self.frame("PONG", {"nonce": nonce}, sender))
            elif kind_name == "REGISTER":
                new = p["payload"]["name"]
                print(f"~ REGISTER: {state['peer']!r} is now {new!r}")
                state["peer"] = new
                conn.sendall(self.frame("REGISTER_RESPONSE", {"result": "ok", "name": new}, sender))
            else:
                print(f"  TCP {kind_name} from {state['peer']!r}")

    def run(self):
        print(f"Simulated phone {self.name!r} ({self.id[:4]}), sending to {self.targets}, TCP on {self.tcp_port}")
        self.announce("DISCOVERY")
        next_hello = 0.0
        try:
            while True:
                if time.monotonic() >= next_hello:
                    self.announce()
                    next_hello = time.monotonic() + 5
                ready, _, _ = select.select([self.sock, self.tcp, *self.conns], [], [], 0.5)
                for r in ready:
                    if r is self.sock:
                        data, address = self.sock.recvfrom(2048)
                        self.handle(data, address)
                    elif r is self.tcp:
                        self.accept()
                    else:
                        self.on_tcp(r)
        except KeyboardInterrupt:
            for target in self.targets:
                self.send(self.packet("GOODBYE", {"reason": "appStopped"}), target)
            print("\nSent GOODBYE")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--name", default="Mac Tester", help="name to announce (2-30 characters)")
    parser.add_argument("--listen", type=int, default=PORT, help=f"UDP port to listen on (default {PORT})")
    parser.add_argument("--tcp", type=int, default=28771, help="TCP port to accept connections on (default 28771)")
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
    Peer(args.name, args.listen, targets, args.tcp).run()


if __name__ == "__main__":
    main()
