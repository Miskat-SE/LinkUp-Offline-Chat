# Testing ResQMesh

How the app is tested, and the record of tests on real devices. Started in phase P2; the device matrix (§3) fills in as phases land.

## 1. Automated tests

```sh
flutter test --timeout 120s                 # 355 tests, about 40 seconds (the 200 MB transfer test takes most of it)
flutter test --coverage --timeout 120s      # writes coverage/lcov.info
flutter test integration_test -d <device>   # on a phone or emulator, about 20 seconds
flutter analyze && dart format --set-exit-if-changed lib test integration_test
```

**Coverage** (10 Oct 2026, generated `*.g.dart` excluded): `core/` 82.7%, feature `data/` 91.1%, screens 88.9%. The target is ≥ 80% for `core/` and `data/`. The least covered code is the Android-only wiring (`service_discovery.dart`, provider setup) and generated migration steps, which the device test and the migration tests exercise instead.

**On a device** (`integration_test/app_flow_test.dart`). The real app runs on the phone with everything real except notifications, the file picker and the stored settings: Wi-Fi bridge, discovery, TCP connections, the transfer worker isolate and SQLite. A second phone runs inside the test (its own connection manager, transfer engine, messaging service and database) and connects to the app through the device's own Wi-Fi address. The test goes through onboarding, opens the chat from People, sends text both ways, then sends a 5 MB file and checks the copy's SHA-256 on the other side. Needs Wi-Fi on (the emulator has it).

**Performance run** (P11.6). The same device test in profile mode, with a larger file, records frame times while the file is prepared and sent:

```sh
flutter drive --profile --no-dds -d <device> --driver=test_driver/perf_driver.dart \
  --target=integration_test/app_flow_test.dart --dart-define=PERF=true --dart-define=FILE_MB=200
# frame times → build/file_transfer_frames.json
```

Cold start: install the release APK, then `adb shell am force-stop com.resqmesh.resqmesh && adb shell am start -W -n com.resqmesh.resqmesh/.MainActivity` (*TotalTime*).

| Date | Device | Build | Measure | Result |
|---|---|---|---|---|
| 10 Oct 2026 | Android 17 emulator | profile | Frames during a 200 MB send (28 frames) | UI thread: average 1.4 ms, 99th percentile 5.6 ms, none over 16 ms. Raster: average 7.2 ms, 1 frame at 16.6 ms (the emulator's software GPU) |
| 10 Oct 2026 | Android 17 emulator | version 14 | Cold start to first frame, 3 runs | 3.4 s (first after install), 2.3 s, 1.9 s. Repeat on a mid-range phone for the 2 s target |

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
| TCP connections | `test/core/network/connection/connection_manager_test.dart` | Real sockets on loopback: lower ID dials, grace period, duplicate tie-break, keep-alive and round-trip time, idle timeout, no HELLO, packets before HELLO, malformed and oversized frames, self-connection, wrong device at an address, reconnect, redial backoff (1, 2, 4 … 30 s), network reset, port fallback |
| Nearby and REGISTER | `test/core/network/connection/nearby_and_register_test.dart` | Online means connected; unreachable state; devices only seen over TCP; renames applied and answered |
| Message store | `test/features/chat/message_repository_test.dart` | SQLite on the real schema: round trip (Bangla, emoji, microseconds); duplicates refused; chat list query and order; live updates; unread counts; status never moves backwards; outbox order; restart recovery; owed receipts; stable stored codes; unknown codes; Clear chat history; data kept after reopening the file |
| Schema | `test/drift/app_database/migration_test.dart` | Every schema version has a snapshot; a new install creates exactly the latest schema; v1 and v2 databases with data migrate to the latest and keep every row |
| Accessibility and layouts (P11) | `test/accessibility/accessibility_test.dart` | 11 main screens in light and dark meet Android's 48 dp touch target, label and 4.5:1 contrast guidelines; every screen lays out at 200% text; landscape phone gets a side rail; on a tablet the chat opens beside the list; About with privacy and licences |
| Chat features (P15) | `test/features/chat/broadcast_ui_test.dart`, `broadcast_loopback_test.dart`, `messaging_service_test.dart`, `mentions_test.dart`, `file_ui_test.dart`, `packet_codec_test.dart`, `migration_test.dart` | Seen-by count; swipe reply in Everyone with the right quote; quote tap scrolls 40 messages back and tints the original; Forward sheet, and a received file forwarded byte-identical over real sockets; delete for everyone online, offline then back, before sending, and refused from anyone but the author; @mention chips, IDs sent, *mentioned you* notification; camera and voice (record, cancel, too short, no microphone, play); voice length kept end to end; schema v3 → v4 |
| Wi-Fi Direct decisions (P13) | `test/core/connection/wifi_direct_controller_test.dart` | On fake time: no support, permission asked and granted, Location and Wi-Fi off; the lowest ID hosts and advertises Android's credentials; others wait, then join (the lowest host if several); a group that never forms is retried after a pause; refusals go back to searching; a lonely host gives way to a lower one or stops after 5 minutes; phones are forgotten after a minute |
| Wi-Fi Direct screens (P13) | `test/features/settings/wifi_direct_ui_test.dart` | Wi-Fi Direct mode unbinds from Wi-Fi and shows *Looking…*, *Joining Rahim…*, *Joined Rahim*; permission asked once, then *Allow*; Location off with its settings; switching back stops Wi-Fi Direct and binds again |
| Platform wrappers | `test/core/platform/platform_wrappers_test.dart` | The Dart side of each Kotlin bridge (network monitor, notifications, background service, file actions) against a stand-in host API; the deferred transfer backend |
| Messaging | `test/features/chat/messaging_service_test.dart` | Two phones on fake time, each with its own database: sent, delivered and read; offline outbox in order; lost ACK resends once stored once; fails after 5 tries and retry; connection lost mid-send; full attempts per connection; app killed mid-send and restarted; READ and DELIVERED queued until reconnect; late receipts; spoofed receipts and misaddressed messages ignored; replies; delete |
| Chat UI | `test/features/chat/chat_ui_test.dart` | Whole app: send from People with ticks, new message badge and notification, reading sends READ, notification explainer, long-press Copy / Reply / Delete, waiting to send, tapping a notification opens the chat; chats and badges after a restart; Storage count, cancel and Clear chat history |
| Transfer engine | `test/features/file_transfer/transfer_engine_test.dart` | Real sockets on loopback: whole file verified and renamed; empty file; reject; already-have; cancel and pause from either side with partial-file rules; resume from the partial size; corruption detected and deleted; dropped connection keeps the partial file; wrong device refused; missing source; the worker isolate; **200 MB with corruption, cancel, pause and resume while memory grows less than 64 MB** |
| Transfer service | `test/features/file_transfer/transfer_service_test.dart` | Real database and files, engine played by a stand-in: preparing (move, sanitise, hash); scheduling when connected with a file port; at most 3 at a time; pause/resume; 3 automatic resumes with backoff, then Failed and Retry; one retry after a checksum mismatch; receiver decisions (invalid, too large, no space and later accepted, duplicates by content and by ID, cancelled); interrupted downloads; restart recovery; Storage actions |
| File messages | `test/features/chat/file_messages_test.dart` | Two phones: a file sent offline is announced on connect, recorded by the receiver, confirmed, then uploaded; names in notifications sanitised; delete removes the file; a reused file ID is ignored |
| Everyone and selected people | `test/features/chat/broadcast_test.dart` | Three phones: Everyone reaches those online, each tracked; only people online at that moment; nobody online; one recipient failing while others succeed, then Retry; a recipient dropping out gets it on return; READ to each sender; selected people as direct messages queued for those away; one hash per file for several people and for Everyone; restart recovery; chat-list preview; one packet per recipient with the same ID |
| 3 phones on loopback | `test/features/chat/broadcast_loopback_test.dart` | **P7 exit:** real sockets and transfer engines; a broadcast text and a 3 MB file reach both phones byte-identical, with "Delivered to 2 of 2" |
| Everyone screens | `test/features/chat/broadcast_ui_test.dart` | Everyone send with summary and per-person sheet; nobody online; an incoming Everyone message in the list, notification and thread; Select people → send |
| Background service | `test/app/background_coordinator_test.dart` | Notification wording for one file, several files and preparing; routes; the service follows a transfer at most once per interval and stops after it; Stay reachable keeps it running |
| Background screens | `test/features/settings/background_ui_test.dart` | Stay reachable offered once on Home; Settings switch and battery link; a transfer in Activity; the service notification's tap opens Transfer Details |
| Fuzzing and limits (P9) | `test/security/codec_fuzz_test.dart`, plus limit and fuzz tests in `connection_manager_test.dart`, `discovery_engine_test.dart`, `transfer_engine_test.dart` | Random, truncated, bit-flipped, wrongly typed and deeply nested input never crashes the codecs; frame buffers stay within limits; random bytes on control and file connections close them and the app keeps working; discovery answers capped per address; half-open connections beyond 8 refused; a packet flood disconnects |
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

**Developer screen.** In a release build, open Settings → About LinkUp, then tap *Version* 7 times. It shows the phone's IP, subnet, broadcast address, whether the app is bound to Wi-Fi, ports, peers with their source (UDP/NSD), packet counters, errors and recent logs. **Copy logs** puts the logs on the clipboard for bug reports.

## 2b. Wi-Fi Direct on two or more phones (P13.1, P13.4)

Wi-Fi Direct needs real phones; the emulator can only show *Looking for phones nearby…*.

1. Install the same build on each phone. Turn Wi-Fi **on** (no network needed). On Android 12 or older, turn Location on too.
2. On each phone: Settings → How you connect → **Wi-Fi Direct** → Save, and allow *Nearby devices* (or location).
3. Keep both on Home. Expected within about 30 s: one phone shows *Waiting for phones to join…*, the other *Joining <name>…*, then both *Wi-Fi Direct connected · 1 nearby*. On Android 9 or older, the hosting phone may ask to accept the connection.
4. Then run R1–R5 (text and files both ways), R12 (Wi-Fi Direct turned off mid-transfer, then back) and R15 with a third phone.
5. If it doesn't connect: Settings → About → tap *Version* 7 times → Developer options → **Wi-Fi Direct** shows the state, phones seen, phones joined and whether this phone is in a group. Note those on both phones, plus the Android versions and models.

## 3. Real-device matrix

From PROJECT_PLAN.md §13.2. Copy this table for each release candidate, name the phones (model, Android version, battery saver) and the router, and fill in one row per test. *Result* is Pass, Fail (with a link to the issue) or N/A.

**Setup:** phones A = … , B = … , C = … ; router … ; build `LINKUP_version-N.apk` ; date … .

| ID | Test | Expected | A / B (/ C) | Build | Result | Notes |
|---|---|---|---|---|---|---|
| R1 | A → B text | Arrives within 1 s; shows ✓✓ | | | | |
| R2 | B → A text | Same | | | | |
| R3 | A → B image | Preview shows; checksum verified | | | | |
| R4 | A → B large file (≥ 1 GB, 2 GB stretch) | Completes; memory flat; UI smooth | | | | |
| R5 | B → A large file | Same | | | | |
| R6 | Router WAN unplugged, Wi-Fi on | R1–R5 still pass | | | | |
| R7 | Mobile data on, Wi-Fi without internet | Traffic stays on Wi-Fi | | | | |
| R8 | Router reboot | Peers back within 60 s, no app restart | | | | |
| R9 | IP change (rejoin or new DHCP lease) | Reconnected within 30 s; pending messages delivered | | | | |
| R10 | Airplane mode on, then Wi-Fi re-enabled | Everything works | | | | |
| R11 | Peer offline → message waiting → peer returns | Delivered automatically | | | | |
| R12 | Wi-Fi off in the middle of a transfer | Resumes from the offset | | | | |
| R13 | Screen off, *Stay reachable* on | Message and file received; progress notification | | | | |
| R14 | Swiped from Recents / force-stopped | Matches plan §5.6 | | | | |
| R15 | Everyone to 3 phones (text and file) | All receive it; per-person status correct | | | | |
| R16 | Two phones choose the same name | The second is refused | | | | |
| R17 | Router with client isolation (guest network) | Isolation hint; no crash | | | | |
| R18 | Local network permission denied (Android 17) | *Local network access is off* with a Settings link | | | | |

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
| 10 Oct 2026 | Android 17 emulator + simulator | version 11 | **P8 exit:** 1 GB from the Mac started with the app open; then Home and screen off: service `connectedDevice` running, notification *Receiving bg_test_1GB.bin — 35%*; finished in 31.7 s (33.8 MB/s), checksum verified; service stopped after. *Stay reachable* on: 90 s of forced Doze (`dumpsys deviceidle force-idle`) without losing the connection; swiped from Recents: process, service and connection stayed; reopened warm in 1.3 s on the same engine. Same file offered again: answered as a duplicate at once. | Pass |
| 11 Oct 2026 | Android 17 emulator + simulator | version 19 → 20 | **P15 on a device.** Updating build 19 (schema v3) to 20 (v4) kept the name and the chat. Voice: *Allow microphone*, recording bar with timer, sent at once, the simulator got a valid AAC file (mono, 22 kHz, 32 kbit/s), played back in the bubble with progress. Camera: the phone's camera app opened from the chat, the photo came back to the review sheet and reached the simulator. | Pass |
| 11 Oct 2026 | Android 17 emulator (has Wi-Fi Direct, no second phone) | version 19 | **P13 on one device:** Wi-Fi Direct selectable in onboarding with its steps; Android's *Nearby devices* dialog shown once; after *Don't allow*, the card shows the reason and **Allow**; after allowing, *Looking for phones nearby…* with no Wi-Fi Direct errors in the system log. Group forming needs two phones (§2b). | Pass |
| 11 Oct 2026 | **Real phones** (user) | version 18 | P6 files, P7 Everyone, P8 background and *Stay reachable* (run by the user). | Pass |
| 10 Oct 2026 | Android 17 emulator + simulator | version 15–17 (release-signed, obfuscated) | **P12 release check.** Fresh install of the signed build; onboarding; notification permission; text both ways with echo, ✓✓ and read receipt; update 15 → 16 over the same key kept chats and identity; People → *Send file* opens the picker. **Bug found and fixed (version 17):** a message that arrived in the same burst as the HELLO was dropped (seen with a 20 MB file from the simulator; on phones, an outbox flushed on connect would have waited 10 s for its resend). After the fix the 20 MB file arrived at once, checksum verified. |  Pass after fix |
| 10 Oct 2026 | Android 17 emulator + simulator | version 10 | New chat → Everyone nearby → *1 online now*; *Hello everyone* reached the Mac marked *(to everyone)*; bubble shows *Delivered to 1 of 1*. | Pass |
| 9 Oct 2026 | Android 17 emulator + simulator with files | version 9 | The 300 MB file queued under version 8 was hashed again after the update, announced, confirmed and sent: **300 MB app → Mac**, SHA-256 identical, 71 s (4.2 MB/s through the emulator's network); memory about 97 MB PSS. App sent to the background for 40 s: reconnected by itself. | Pass |

**Still needed for M2** (plan §11.2): two real phones on a router with the internet unplugged and mobile data on. They should see each other within 10 s, go offline within 20 s of Wi-Fi off, and be rediscovered after a router reboot.
