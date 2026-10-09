# Testing ResQMesh

How the app is tested, and the record of tests on real devices. Started in phase P2; the device matrix (§3) fills in as phases land.

## 1. Automated tests

```sh
flutter test        # 284 tests, about 30 seconds (the 200 MB transfer test takes most of it)
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
| Message store | `test/features/chat/message_repository_test.dart` | SQLite on the real schema: round trip (Bangla, emoji, microseconds); duplicates refused; chat list query and order; live updates; unread counts; status never moves backwards; outbox order; restart recovery; owed receipts; stable stored codes; unknown codes; Clear chat history; data kept after reopening the file |
| Schema | `test/drift/app_database/migration_test.dart` | Every schema version has a snapshot; a new install creates exactly the latest schema. Migration tests go here. |
| Messaging | `test/features/chat/messaging_service_test.dart` | Two phones on fake time, each with its own database: sent, delivered and read; offline outbox in order; lost ACK resends once stored once; fails after 5 tries and retry; connection lost mid-send; full attempts per connection; app killed mid-send and restarted; READ and DELIVERED queued until reconnect; late receipts; spoofed receipts and misaddressed messages ignored; replies; delete |
| Chat UI | `test/features/chat/chat_ui_test.dart` | Whole app: send from People with ticks, new message badge and notification, reading sends READ, notification explainer, long-press Copy / Reply / Delete, waiting to send, tapping a notification opens the chat; chats and badges after a restart; Storage count, cancel and Clear chat history |
| Transfer engine | `test/features/file_transfer/transfer_engine_test.dart` | Real sockets on loopback: whole file verified and renamed; empty file; reject; already-have; cancel and pause from either side with partial-file rules; resume from the partial size; corruption detected and deleted; dropped connection keeps the partial file; wrong device refused; missing source; the worker isolate; **200 MB with corruption, cancel, pause and resume while memory grows less than 64 MB** |
| Transfer service | `test/features/file_transfer/transfer_service_test.dart` | Real database and files, engine played by a stand-in: preparing (move, sanitise, hash); scheduling when connected with a file port; at most 3 at a time; pause/resume; 3 automatic resumes with backoff, then Failed and Retry; one retry after a checksum mismatch; receiver decisions (invalid, too large, no space and later accepted, duplicates by content and by ID, cancelled); interrupted downloads; restart recovery; Storage actions |
| File messages | `test/features/chat/file_messages_test.dart` | Two phones: a file sent offline is announced on connect, recorded by the receiver, confirmed, then uploaded; names in notifications sanitised; delete removes the file; a reused file ID is ignored |
| Everyone and selected people | `test/features/chat/broadcast_test.dart` | Three phones: Everyone reaches those online, each tracked; only people online at that moment; nobody online; one recipient failing while others succeed, then Retry; a recipient dropping out gets it on return; READ to each sender; selected people as direct messages queued for those away; one hash per file for several people and for Everyone; restart recovery; chat-list preview; one packet per recipient with the same ID |
| 3 phones on loopback | `test/features/chat/broadcast_loopback_test.dart` | **P7 exit:** real sockets and transfer engines; a broadcast text and a 3 MB file reach both phones byte-identical, with "Delivered to 2 of 2" |
| Everyone screens | `test/features/chat/broadcast_ui_test.dart` | Everyone send with summary and per-person sheet; nobody online; an incoming Everyone message in the list, notification and thread; Select people → send |
| File screens | `test/features/file_transfer/file_ui_test.dart` | Whole app: attach → review → remove → send → Sending % → Sent; receive with progress → preview → Open, Share, Save; details with live numbers and Pause; Storage *Clear all local data* back to onboarding |
| File names | `test/core/storage/file_name_sanitizer_test.dart` | Traversal, hidden names, control and bidi characters, reserved names, 255-byte limit on character boundaries; storage paths from IDs; SHA-256 test vectors |
| App flows | `test/features/onboarding/onboarding_flow_test.dart` | Whole app: onboarding, relaunch, tabs, New chat sheet, Change name, connection method, theme |
| Discovery UI | `test/features/discovery/discovery_ui_test.dart` | Whole app with a second simulated phone: status line, People Nearby, leaving, name taken during onboarding, clash banner, developer screen |

**Stand-ins.** Tests replace only what needs a phone: SharedPreferences (`MemoryKeyValueStore`), the database file (the real schema on in-memory SQLite, `testDatabase()`; pass the same one to `launchApp` twice to simulate a restart), the Wi-Fi bridge (`FakeNetworkMonitor`), notifications (`FakeNotifications`), TCP links in widget and messaging tests (`FakePeerLinks`, `LinkedPair`, which can cut the connection or lose packets) and UDP (`MemoryDatagramNetwork`, which behaves like a LAN: broadcast, unicast, unreachable phones, routers that drop broadcasts). The discovery engine, codec and UI under test are the real code. Socket code is also tested on real loopback sockets.

**Timing.** Discovery tests run on fake time (`fake_async`), so "offline after 20 s" or "name free after 3 s" run instantly and exactly.

**Real file work in widget tests.** Widget tests run on fake time, but moving, measuring and deleting files is real I/O. Such tests let real time pass in small steps (`tester.runAsync`, then a frame) until the screen shows the result. A widget test that fails while the app is still running can keep its test process alive, so `flutter test --timeout 120s` is a safer way to run the whole suite.

## 2. Testing with one phone: the simulated peer

`tool/lan_peer_sim.py` pretends to be a second phone. It announces itself, answers DISCOVERY and NAME_CHECK, and accepts TCP connections on port 28771: the HELLO handshake, PING, REGISTER and MESSAGE (answered with ACK and DELIVERED). With `--echo` it also replies to each message with *You said: …*. It also takes files: files the app sends arrive in `--save-dir` (default `./sim_received`) with the checksum verified, and `--send-file PATH` (repeatable) sends files to the app once it connects. It keeps the same device ID for the same `--name` across runs, like a real phone, so queued messages reach it when it comes back (`--id` sets one explicitly). It prints what it hears and needs only Python 3.

**Real phone + Mac on the same Wi-Fi**

```sh
python3 tool/lan_peer_sim.py --name "Mac Tester"
```

The phone should show *Mac Tester* in People Nearby within a few seconds, and the Mac prints `+ found 'Yusuf' …`. Press Ctrl-C to stop: the phone moves it to *Seen earlier* at once. If the Mac's firewall asks, allow incoming connections for Python.

**Android emulator** (each emulator sits behind its own virtual router, so forward the port)

```sh
adb emu redir add udp:28760:28760
python3 tool/lan_peer_sim.py --name "Mac Tester" --listen 28770 --tcp 28771 --target 127.0.0.1:28760 --echo
# to send files from the Mac to the app, also:
adb forward tcp:28762 tcp:28762
python3 tool/lan_peer_sim.py ... --send-file ~/big.bin --app-file-addr 127.0.0.1:28762
# when done:
adb emu redir del udp:28760
adb forward --remove tcp:28762
```

In this mode the emulator hears the Mac, but its broadcasts can't reach the Mac; that's a limitation of the emulator's network, not of the app. The app then connects to the Mac over TCP: it dials `10.0.2.2:28771`, which the emulator maps to the Mac.

**Developer screen.** In a release build, open Settings, then tap the version number 7 times. It shows the phone's IP, subnet, broadcast address, whether the app is bound to Wi-Fi, ports, peers with their source (UDP/NSD), packet counters, errors and recent logs. **Copy logs** puts the logs on the clipboard for bug reports.

## 3. Real-device matrix

From PROJECT_PLAN.md §13.2. Fill in one row per run.

| ID | Test | Phones / router | Build | Result | Notes |
|---|---|---|---|---|---|
| R1–R5 | Text (P4) and files (P6) | | | — | |
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
| 9 Oct 2026 | Android 17 emulator + simulator with `--echo` | version 6 | First chat shows the notification explainer, then Android's permission dialog (allowed); message goes Sending → Delivered; echo reply arrives; with the app in the background the reply shows a *LinkUp · Mac Tester* notification; tapping it opens that chat | Pass |
| 9 Oct 2026 | Android 17 emulator + simulator | version 7 | **M3 exit.** Message saved; simulator stopped; *Waiting for you* queued (clock icon); app force-stopped and reopened: chat and *Waiting to send* still there; simulator back: message delivered automatically, echo arrived with unread badge. Settings → Storage: *3 messages saved*, confirmation dialog, *Chat history cleared*. Cold start 1.7 s. | Pass |
| 9 Oct 2026 | **Two real phones** (Yusuf and Miskat) on a router with the internet unplugged | version 7 | Text messages sent and received both ways (run by the user). A first attempt failed one way until the phones' Wi-Fi was sorted out; the cause wasn't captured. If it happens again, compare Settings → Developer options on both phones: *Bound to Wi-Fi*, *Peers*, the packet counters and the errors. | Pass |
| 9 Oct 2026 | Android 17 emulator + simulator with files | version 8 | **1 GB Mac → app**: offered, confirmed, received, checksum verified, card shows it; 1,073.7 MB in 109 s (9.8 MB/s through `adb forward`); app memory about 80 MB PSS afterwards. File picker → Send sheet (*Send to Mac Tester · 1 file · 286 MB*). Found: after the picker put the app in the background, Android cut its network and the discovery socket never recovered (fixed in version 9). | Pass, one bug found |
| 10 Oct 2026 | **Two real phones** | version 9 | Images sent several times in both directions (run by the user). | Pass |
| 10 Oct 2026 | Android 17 emulator + simulator | version 10 | New chat → Everyone nearby → *1 online now*; *Hello everyone* reached the Mac marked *(to everyone)*; bubble shows *Delivered to 1 of 1*. | Pass |
| 9 Oct 2026 | Android 17 emulator + simulator with files | version 9 | The 300 MB file queued under version 8 was hashed again after the update, announced, confirmed and sent: **300 MB app → Mac**, SHA-256 identical, 71 s (4.2 MB/s through the emulator's network); memory about 97 MB PSS. App sent to the background for 40 s: reconnected by itself. | Pass |

**Still needed for M2** (plan §11.2): two real phones on a router with the internet unplugged and mobile data on. They should see each other within 10 s, go offline within 20 s of Wi-Fi off, and be rediscovered after a router reboot.
