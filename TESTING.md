# Testing ResQMesh

How the app is tested, and the record of tests on real devices. Started in phase P2; the device matrix (§3) fills in as phases land.

## 1. Automated tests

```sh
flutter test        # 138 tests, about 10 seconds
```

| Area | File | What it proves |
|---|---|---|
| Layer rules | `test/architecture_test.dart` | Material comes from `material_ui`; `core/` never imports features; domain is pure Dart; widgets never import `dart:io` |
| Username rules | `test/core/identity/username_test.dart` | 2–30 graphemes, trimming, control characters, Bangla, emoji, case-insensitive comparison |
| Identity | `test/core/identity/identity_repository_test.dart` | Device ID created once and kept; claim time only changes with the name |
| Logging | `test/core/logging/app_logger_test.dart` | Levels, ring buffer, file rotation |
| Protocol | `test/core/network/protocol/packet_codec_test.dart` | Fixtures from PROTOCOL.md round-trip; every field validated; garbage never throws; UDP magic; TCP framing with split reads and size limits |
| Peer list | `test/core/network/discovery/peer_registry_test.dart` | Merge by device ID, expiry after 20 s, GOODBYE, name holders, clash rule |
| Discovery | `test/core/network/discovery/discovery_engine_test.dart` | Two to three engines on an in-memory LAN: find each other, leave, come back, IP change, Wi-Fi lost and back, name check (taken, free, no network), name clash, blocked access, isolation hint, malformed packets, NSD when broadcasts are dropped |
| Sockets | `test/core/network/network_test.dart` | Real UDP sockets on loopback; subnet and broadcast maths; display names; "last seen" text |
| TCP connections | `test/core/network/connection/connection_manager_test.dart` | Real sockets on loopback: lower ID dials, grace period, duplicate tie-break, keep-alive and round-trip time, idle timeout, no HELLO, packets before HELLO, malformed and oversized frames, self-connection, wrong device at an address, reconnect, network reset, port fallback |
| Nearby and REGISTER | `test/core/network/connection/nearby_and_register_test.dart` | Online means connected; unreachable state; devices only seen over TCP; renames applied and answered |
| App flows | `test/features/onboarding/onboarding_flow_test.dart` | Whole app: onboarding, relaunch, tabs, New chat sheet, Change name, connection method, theme |
| Discovery UI | `test/features/discovery/discovery_ui_test.dart` | Whole app with a second simulated phone: status line, People Nearby, leaving, name taken during onboarding, clash banner, developer screen |

**Stand-ins.** Tests replace only what needs a phone: SharedPreferences (`MemoryKeyValueStore`), the Wi-Fi bridge (`FakeNetworkMonitor`) and UDP (`MemoryDatagramNetwork`, which behaves like a LAN: broadcast, unicast, unreachable phones, routers that drop broadcasts). The discovery engine, codec and UI under test are the real code. Socket code is also tested on real loopback sockets.

**Timing.** Discovery tests run on fake time (`fake_async`), so "offline after 20 s" or "name free after 3 s" run instantly and exactly.

## 2. Testing with one phone: the simulated peer

`tool/lan_peer_sim.py` pretends to be a second phone. It announces itself, answers DISCOVERY and NAME_CHECK, and accepts TCP connections on port 28771: the HELLO handshake, PING and REGISTER. It prints what it hears and needs only Python 3.

**Real phone + Mac on the same Wi-Fi**

```sh
python3 tool/lan_peer_sim.py --name "Mac Tester"
```

The phone should show *Mac Tester* in People Nearby within a few seconds, and the Mac prints `+ found 'Yusuf' …`. Press Ctrl-C to stop: the phone moves it to *Seen earlier* at once. If the Mac's firewall asks, allow incoming connections for Python.

**Android emulator** (each emulator sits behind its own virtual router, so forward the port)

```sh
adb emu redir add udp:28760:28760
python3 tool/lan_peer_sim.py --name "Mac Tester" --listen 28770 --tcp 28771 --target 127.0.0.1:28760
# when done:
adb emu redir del udp:28760
```

In this mode the emulator hears the Mac, but its broadcasts can't reach the Mac; that's a limitation of the emulator's network, not of the app. The app then connects to the Mac over TCP: it dials `10.0.2.2:28771`, which the emulator maps to the Mac.

**Developer screen.** In a release build, open Settings, then tap the version number 7 times. It shows the phone's IP, subnet, broadcast address, whether the app is bound to Wi-Fi, ports, peers with their source (UDP/NSD), packet counters, errors and recent logs. **Copy logs** puts the logs on the clipboard for bug reports.

## 3. Real-device matrix

From PROJECT_PLAN.md §13.2. Fill in one row per run.

| ID | Test | Phones / router | Build | Result | Notes |
|---|---|---|---|---|---|
| R1–R5 | Text and files (needs P4–P6) | | | — | |
| R6 | Router WAN unplugged, Wi-Fi on: discovery | | | | |
| R7 | Mobile data on + Wi-Fi without internet | | | | |
| R8 | Router reboot: peers rediscovered within 60 s | | | | |
| R9 | IP change: reconnected within 30 s | | | | |
| R10 | Airplane mode on, Wi-Fi re-enabled | | | | |
| R16 | Two phones choose the same name | | | | |
| R17 | Router with client isolation: hint shown | | | | |

### Runs so far

| Date | Setup | Build | What was checked | Result |
|---|---|---|---|---|
| 8 Oct 2026 | Android 17 emulator + `lan_peer_sim.py` on the Mac | version 3 | Wi-Fi bridge (joined, bound to Wi-Fi, interfaces), UDP bound on 28760, NSD browsing, simulated peer appears *Online* in Home and People, GOODBYE moves it to *Seen earlier*, isolation hint after 30 s alone, developer unlock by 7 taps | Pass |

| 9 Oct 2026 | Android 17 emulator + simulator with TCP | version 5 | Version 5: app dials the simulator after the 3 s grace period; handshake; Home shows *connected · 1 nearby* only once TCP is up; rename sends REGISTER (`'Yusuf' is now 'Yusuf Ali'`); connection kept open by PING/PONG | Pass |

**Still needed for M2** (plan §11.2): two real phones on a router with the internet unplugged and mobile data on. They should see each other within 10 s, go offline within 20 s of Wi-Fi off, and be rediscovered after a router reboot.
