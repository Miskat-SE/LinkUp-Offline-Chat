# ResQMesh — Project Plan

**Offline messaging and file sharing over a local Wi-Fi network**
Flutter Android app · works with the router's internet switched off · no cloud, no accounts

| | |
|---|---|
| Student | Jannatul Miskat Chowdhury (Roll 2405207), IIT, University of Dhaka |
| Supervisor | Dr. Sumon Ahmed |
| Product name | **LinkUp** (shown to users; ResQMesh stays the project and research name) |
| Plan version | 2.1 · 10 Oct 2026 |
| Source | Build specification, 8 Oct 2026 (`docs/SPEC.md`, from `ResQMesh_prompt.txt`) |
| Window | 1 Oct 2026 (Week 1) → ~17 Feb 2027 (Week 20) |

References written as *spec §n* point to the numbered sections of the build specification.

---

## Status

> Living section. Update every Monday.

| | |
|---|---|
| Week | **2 of 20** (8–14 Oct 2026) |
| Phase | **P9 done: feature complete, `v0.9.0-beta`** · P7 3-phone test, P8 real-phone checks, 2 GB soak (P6.12) and mid-term slides (P6.13) open · P0 inventory and review still open |
| Next milestone | M1 · Plan reviewed, discovery spike done, app foundation (21 Oct) |
| Health | Ahead of schedule: P1–P9 (planned for Weeks 3–14) passed their code gates in Week 2. Text chat was confirmed by the user on **two real phones** on a router with the internet unplugged (9 Oct). Files: 1 GB Mac → emulator and 300 MB emulator → Mac with checksums verified and memory flat; images sent several times both ways on the two real phones (user, 10 Oct); **the 2 GB two-phone soak (M4) is still to do**. |
| Blockers | None recorded |

**This week**
- [ ] Review this plan and the open questions (§16) with the supervisor
- [x] Vet and pin the packages (P0.2); record the results in §5.1
- [ ] Fill in the testbed inventory (§13.4): at least 2 phones, 3 for broadcast tests
- [ ] Install the P1 build on a phone: first launch asks for a name, relaunch skips it (P1 exit)
- [x] Draft `PROTOCOL.md` v0.1 from §7
- [ ] Discovery spike: 2 phones find each other and exchange one TCP message on a router with the internet unplugged (P0.5)

**How to keep this file current**
- Tick task boxes as you go, and put the task ID in commit messages (§15.3).
- Every Monday: update this block, update the milestone statuses (§12), and review the risks (§14).
- Record each decision as an ADR in `docs/adr/`, then update §3.
- Any change to a date or the scope gets a line in the [Changelog](#changelog) with the reason.

---

## Contents

1. [Goal and deliverables](#1-goal-and-deliverables)
2. [Scope](#2-scope)
3. [Key technical decisions](#3-key-technical-decisions)
4. [Architecture](#4-architecture)
5. [Android engineering](#5-android-engineering)
6. [Discovery, identity and names](#6-discovery-identity-and-names)
7. [Protocol](#7-protocol)
8. [Data and storage](#8-data-and-storage)
9. [Security](#9-security)
10. [Features and screens](#10-features-and-screens)
11. [Schedule and backlog](#11-schedule-and-backlog)
12. [Milestones](#12-milestones)
13. [Testing and verification](#13-testing-and-verification)
14. [Risks](#14-risks)
15. [Working practices](#15-working-practices)
16. [Open questions](#16-open-questions)

---

## 1. Goal and deliverables

> Build a production-quality Android app in Flutter that lets people on the same Wi-Fi network
> find each other, chat, and share files of any size. It needs no internet, no cloud and no accounts.

In one line: *AirDrop + Messenger, but only for people on the same Wi-Fi network.*

| Objective | Means |
|---|---|
| **Find** | Automatic discovery over UDP broadcast and Android NSD (mDNS); one unique name per network; persistent device IDs |
| **Talk** | 1:1 text chat with Sent / Delivered / Read status, reply, copy, delete and retry; broadcast to everyone or to selected people; messages queue while a peer is away |
| **Share** | Files streamed over TCP with progress, speed, time left, cancel, retry, resume and SHA-256 verification |
| **Keep** | SQLite for messages, peers and file metadata; files in app storage; a Storage screen to manage both |
| **Prove** | Unit tests and loopback integration tests with real sockets; a real-device test matrix on 2–3 phones with the router's internet off (§13) |

| Requirement | |
|---|---|
| Internet | ❌ Not required, never contacted |
| Wi-Fi / LAN | ✅ Required (same router, same subnet) |
| Cloud, accounts, analytics | ❌ None |
| Messages and files | ✅ Stored only on the phones |

**Final deliverables** (spec §43)
1. Flutter source code with Android configuration, including the small Kotlin platform bridge (D8)
2. Signed release APK built with `flutter build apk --release`
3. `README.md`, `ARCHITECTURE.md`, `PROTOCOL.md`, `TESTING.md`
4. Unit, loopback and on-device integration tests, plus the device test report in `TESTING.md`
5. Project report or thesis chapter, in the format the supervisor confirms (§16 Q1–Q2)

**Build gate:** `flutter pub get`, `flutter analyze`, `flutter test` and `flutter build apk --release` all succeed on a clean checkout.

---

## 2. Scope

### 2.1 In scope
- Android only: Flutter and Dart, plus a small Kotlin bridge for what plugins don't cover
- One Wi-Fi network (same router or access point, same subnet). Must work with the router's internet off and with mobile data on.
- **The user chooses how to connect** (onboarding and Settings): Wi-Fi network, phone hotspot, Wi-Fi Direct or Bluetooth (D20). Methods not built yet show as *Coming soon*.
  - Phone hotspot: one phone shares a hotspot, the others join; same LAN code, plus detecting the hotspot host's own interface (P2)
  - Wi-Fi Direct: Android `WifiP2pManager`; after the group forms, the same TCP protocol runs over it (P13)
  - Bluetooth: works with Wi-Fi off; for messages, files only small and slow (P14)
- Registration with a name that is unique on the current network; Settings → Change name
- Automatic discovery; People Nearby with online status and last seen
- 1:1 text chat: statuses, reply, copy, delete (on this phone), retry
- Files of any type, one or several at a time; previews for images, videos and documents
- Broadcast to everyone online, and sending to selected people
- Offline queue: pending messages go out when the peer returns; failed transfers can be retried
- Background receiving with a foreground service: always on during transfers, opt-in when idle (§5.6)
- SQLite and app-storage persistence; Storage management screen
- Security hardening; encryption in transit if the P9 spike shows it is stable (D17)
- Hidden developer diagnostics screen; structured local logs
- Material 3 with expressive styling, dynamic colour, light and dark themes

### 2.2 Out of scope
- iOS, desktop and web clients
- Any internet use: cloud, Firebase, Google sign-in, remote APIs, online analytics or crash reporting
- Google Nearby Connections (needs Google Play services, which spec §2–§3 forbid)
- Multi-hop relaying; peers on other subnets or VLANs
- Voice and video calls; voice notes (§16 Q4)
- Group chats with membership (broadcast and multi-select only), delete for everyone, editing messages
- Guaranteed delivery while the app is force-stopped, or swiped away without the background service (§5.6)

---

## 3. Key technical decisions

Confirm by the end of Week 2, then record each one as an ADR in `docs/adr/`.

| # | Decision | Choice | Why |
|---|---|---|---|
| D1 | Framework | Flutter (latest stable at P0) and Dart 3; Android only | Spec §2 |
| D2 | State and DI | Riverpod 3 (`flutter_riverpod`). Providers are the DI container; no global mutable state. | Spec §21. Tests can override any provider. |
| D3 | Persistence | SQLite through drift (`drift_flutter`; `sqlite3` 3.x bundles SQLite itself, so no `sqlite3_flutter_libs`). Identity and settings in `shared_preferences`. | Type-safe queries and migrations; `watch` streams drive the chat UI; in-memory database for `flutter test` |
| D4 | Discovery | UDP broadcast announcements (main liveness signal) **plus** Android NSD `_resqmesh._tcp` via `bonsoir`. A peer counts as online only after a TCP HELLO succeeds. | NSD is unreliable on some phones and routers drop mDNS; some routers drop broadcast instead. Confirming over TCP avoids ghost peers. |
| D5 | Transport | TCP: one long-lived **control** connection per pair of peers, plus one short-lived **data** connection per file transfer | A 2 GB file never blocks chat; TCP backpressure gives flow control for free |
| D6 | Framing | `kind (1 B) · length (4 B, big-endian) · body`. Kind `0x01` = JSON control (≤ 64 KiB); `0x02` = binary file chunk (≤ 256 KiB) | Spec §11: control messages structured, file data binary. Lengths are checked before anything is buffered. |
| D7 | Network binding | The bridge finds the Wi-Fi `Network` (internet capability not required), calls `bindProcessToNetwork`, and holds a `MulticastLock` | When Wi-Fi has no internet, Android may route traffic over mobile data instead (spec §16). No plugin does all of this. |
| D8 | Platform bridge | One Kotlin plugin in `android/app`, with a typed interface generated by `pigeon`. It covers the network (D7), the foreground service, notifications, Wi-Fi and wake locks, video thumbnails, opening and sharing files, and permissions plugins don't handle. | Replaces 4–5 third-party plugins; typed calls instead of string channel names |
| D9 | Background | The `Application` owns a cached `FlutterEngine`. A foreground service of type `connectedDevice` runs during transfers, and while idle only if the user turns on *Stay reachable*. | The same Dart isolate keeps running after the activity closes, with no cross-isolate plumbing. `dataSync` is capped at 6 h a day on Android 15+. |
| D10 | Heavy work off the UI isolate | File reads and writes, hashing and data sockets run in a long-lived transfer worker isolate that posts progress at most 10 times a second | Spec §13, §36: no jank, files never loaded whole |
| D11 | Checksum | SHA-256 (`crypto`), streamed. The sender hashes before the offer (cached by path + size + modified time); the receiver hashes while writing. | Integrity and duplicate detection without holding the file in memory |
| D12 | Identity | Random UUID v4 device ID created on first launch and stored locally. Never derived from the name. | Spec §4, §28 |
| D13 | Name uniqueness | Names compared after trimming, collapsing spaces and ignoring case, against online peers plus a NAME_CHECK broadcast with a 3 s window. If a clash appears later, the earlier claim keeps the name (ties broken by device ID). | Spec §5. Stays deterministic when two networks merge. |
| D14 | File storage | App-internal storage. Files are saved under **our own** `fileId`; incoming names are sanitised and used only for display and export. | Path traversal is impossible by construction (spec §28) |
| D15 | SDK levels | `minSdk 26`; `compileSdk` and `targetSdk` 36, Flutter 3.47's defaults. Move to 37 when Flutter stable does. | Covers older test phones. Android 17 enforces the local network permission only for apps targeting 37+, and Google discourages requesting it earlier (§5.4, ADR-0015). |
| D16 | UI | Flutter's official `material_ui` package (Material moved out of the SDK in Flutter 3.47), with `StyleVariant.material3Expressive` wherever it is supported, plus our own expressive tokens (shape scale, emphasised type, motion), `dynamic_color`, fonts bundled as assets | `material_ui` is where Flutter now ships Material and is adding Expressive; `dynamic_color` and `go_router` already use it. `google_fonts` downloads fonts at runtime, which needs the internet (ADR-0016). |
| D17 | Encryption | Decided by a spike in P9: TLS 1.3 (`dart:io` `SecureSocket`) with a self-signed certificate per device, pinned on first use. Ship it only if stable; otherwise run plaintext on the trusted LAN and document that. | Spec §29: established primitives only, no instability |
| D18 | Navigation | `go_router` | First-party; notification taps can deep-link to a chat or transfer |
| D19 | Packet models | Hand-written sealed classes with strict `fromJson` validation; no code generation for packets | Every field validated (spec §28); exhaustive `switch` over packet types |
| D20 | Connection methods | The user picks one of four methods (`ConnectionMethod`). The framing and packets (§7) are the same on all of them; each method only supplies discovery and a byte stream: LAN and hotspot → UDP/NSD + TCP; Wi-Fi Direct → P2P group + TCP; Bluetooth → its own discovery and stream (D21). | One protocol and one codebase for messages and files, whatever the radio |
| D22 | Database schema (ADR-0020) | Grows with the phases: v1 is `messages` only; `files` (P6), `message_recipients` (P7) and `peers` arrive as tested migrations. Message IDs unique on their own; stored values are fixed text codes; times in UTC microseconds. One repository, tested on in-memory SQLite. | No speculative tables; the migration path is exercised early |
| D23 | File transfer runtime (ADR-0021) | `TransferEngine` runs in a worker isolate with its own file port (28762, announced as `filePort` in HELLO); `TransferService` on the main isolate owns state, database and decisions | ADR-0010 kept without relaying sockets between isolates |
| D21 | Bluetooth design | Decide by spike at the start of P14: BLE advertising for discovery plus L2CAP connection-oriented channels (API 29+, no pairing) **or** classic Bluetooth RFCOMM sockets (pairing, wider support). | Bluetooth is slow (roughly 0.1–2 Mbit/s): the UI warns before large files |

---

## 4. Architecture

```
PRESENTATION   Screens and widgets · Riverpod notifiers (UI state) · go_router
DOMAIN         Entities · use cases (SendText, SendFiles, Broadcast, ChangeName, Retry) · repository interfaces
DATA           Repository implementations · drift DAOs · FileStore (paths, sanitising, free space)
LAN ENGINE     NetworkMonitor · Discovery (UDP + NSD) · PeerRegistry · ConnectionManager (TCP) · Outbox · TransferManager
PROTOCOL       Sealed packet models · JSON codec and validation · frame codec
PLATFORM       Kotlin bridge: Wi-Fi binding, MulticastLock, locks, foreground service, notifications, thumbnails
```

### 4.1 Repository layout

The Flutter project sits at the repository root. Folder names follow spec §20, with additions marked ＋.

```
ResQMesh/
├── android/app/src/main/kotlin/…/resqmesh/
│   ├── ResQMeshApp.kt            # ＋ Application: creates and caches the FlutterEngine
│   ├── MainActivity.kt           #    attaches to the cached engine
│   ├── LanForegroundService.kt   # ＋ transfers and "Stay reachable"
│   └── bridge/                   # ＋ pigeon host API: network, locks, notifications, thumbnails
├── pigeons/platform_api.dart     # ＋ bridge interface definition
├── lib/
│   ├── main.dart
│   ├── app/                      # ＋ bootstrap, router, theme (Material 3 + expressive tokens)
│   ├── core/
│   │   ├── constants/            #    ports, limits, timeouts
│   │   ├── errors/               #    typed failures
│   │   ├── logging/              # ＋ structured logger, ring buffer, rotating files
│   │   ├── network/              #    LanEngine, NetworkMonitor, sockets, ConnectionManager
│   │   │   └── protocol/         # ＋ sealed packets, JSON codec, frame codec, validation
│   │   ├── storage/              #    drift database, DAOs, FileStore, FileNameSanitizer
│   │   └── utils/                #    clock, IDs, checksum, formatters
│   ├── features/
│   │   ├── onboarding/           {data, domain, presentation}
│   │   ├── discovery/            {data, domain, presentation}   # UDP + NSD, PeerRegistry, People Nearby
│   │   ├── chat/                 {data, domain, presentation}   # messages, outbox, broadcast
│   │   ├── file_transfer/        {data, domain, presentation}   # TransferManager, worker isolate, previews
│   │   ├── users/                {data, domain, presentation}
│   │   ├── settings/             {presentation}                 # Change name, Storage, About
│   │   └── developer/            {presentation}                 # ＋ hidden diagnostics
│   └── shared/
│       ├── widgets/
│       └── models/
├── test/                         # mirrors lib/; loopback network tests; protocol fixtures
├── integration_test/             # on-device flows
├── docs/
│   ├── SPEC.md                   # build specification
│   └── adr/
├── README.md · ARCHITECTURE.md · PROTOCOL.md · TESTING.md
└── PROJECT_PLAN.md
```

**Dependency rules**
- `presentation → domain`; `data → domain, core`. `domain` is pure Dart with no Flutter imports.
- `core` never imports `features`. Features register packet handlers with the `LanEngine`; the engine dispatches inbound packets by type.
- Features use each other only through their `domain` layer, never through another feature's `data` layer.
- Widgets never touch sockets, files or SQL.

### 4.2 Core contracts

```dart
/// Every packet on the wire; one final subclass per type (§7.3).
sealed class Packet {
  String get messageId;    // UUID
  String get senderId;     // device ID; must match the connection's HELLO
  String get senderName;
  String get receiverId;   // device ID, or '*' for everyone
  DateTime get timestamp;  // sender's clock, informational only
}

/// The codec never throws past its boundary.
sealed class DecodeResult {}  // Decoded(packet) | Malformed(reason) | UnsupportedVersion(v) | TooLarge(bytes)

abstract interface class PeerConnection {
  String get peerDeviceId;
  Stream<Packet> get inbound;
  Future<void> send(Packet packet);  // throws on timeout or closed connection
  Future<void> close();
}

abstract interface class DiscoveryService {
  Stream<DiscoveryEvent> get events;  // PeerSeen(endpoint) | PeerGone(deviceId), already de-duplicated
  Future<void> start(LocalIdentity self, LanInterface iface);
  Future<void> stop();
}
```

Constructors take `Clock`, socket factories and the bridge as parameters, so tests run on fake time and loopback sockets.

### 4.3 Runtime model

```
Main isolate                          Transfer isolate               Android (Kotlin)
UI · Riverpod · LanEngine             TransferWorker                 Application (cached FlutterEngine)
  ├ Discovery (UDP + NSD)               ├ file read / write          LanForegroundService
  ├ ConnectionManager (control TCP)     ├ SHA-256                    Bridge: Wi-Fi binding, MulticastLock,
  ├ Outbox                              └ data TCP sockets             Wi-Fi/wake locks, notifications,
  └ drift (queries on its own isolate)  ◀── commands / progress ──▶     thumbnails, permissions
```

- The engine starts once a name is set and Wi-Fi is up. It stops when Wi-Fi goes down, and restarts on an IP change: rebind, re-announce, reconnect.
- The worker isolate gets file paths from the main isolate and never calls plugins itself.
- The database is the single source of truth: the engine writes to it, and the UI observes it through drift `watch` streams.

---

## 5. Android engineering

### 5.1 Tech stack and packages

Spec §2 requires checking every package before use. Rule: a release in the last 12 months (first-party `dart.dev` / `flutter.dev` packages with a stable API are exempt), support for Flutter 3.47 and Android Gradle Plugin 9, an acceptable licence and open issues. Exact versions are pinned in the committed `pubspec.lock`.

**P0.2 results (8 Oct 2026, Flutter 3.47.6 / Dart 3.13.5).** Versions are the latest on pub.dev that day.

| Need | Package | Status | Notes |
|---|---|---|---|
| Material UI | `material_ui` 1.6 (flutter.dev) | ✅ Adopted | Official Material library, moved out of the SDK; replaces `package:flutter/material.dart`. Has `StyleVariant.material3Expressive` (ADR-0016). |
| State / DI | `flutter_riverpod` 3.4 | ✅ Adopted | |
| Navigation | `go_router` 18.0 (flutter.dev) | ✅ Adopted | Already built on `material_ui` |
| Database | `drift` 2.35, `drift_flutter` 0.3; dev: `drift_dev`, `build_runner` | ✅ Adopted | `sqlite3_flutter_libs` is end-of-life: `sqlite3` 3.x bundles SQLite through build hooks |
| Settings / identity | `shared_preferences` 2.5 (flutter.dev) | ✅ Adopted | |
| IDs | `uuid` 4.6 | ✅ Adopted | |
| NSD / mDNS | `bonsoir` 7.1 | ✅ Adopted | Queues resolves on older Android; uses the Android 14+ service-info callback where available |
| File picking | `file_picker` 13.1 (Android: `android_file_picker` 2.0) | ✅ Adopted | **Confirmed: copies every picked file into the cache.** We move that copy into `files/sent/` (same partition, no second copy). |
| Paths | `path_provider` 2.1, `path` 1.9 | ✅ Adopted | |
| MIME types | `mime` 2.1 | ✅ Adopted | |
| Hashing | `crypto` 3.0 | ✅ Adopted | |
| Open / share files | `open_filex` 4.7 | ❌ Rejected | Last release March 2025. The bridge does it with intents and a `FileProvider`. |
| Dynamic colour | `dynamic_color` 2.1 | ✅ Adopted | Already built on `material_ui` |
| Runtime permissions | `permission_handler` 13.0 | ⏸ Decide in P2 | At `targetSdk 36` only `POST_NOTIFICATIONS` is requested; the bridge may cover it |
| Bridge codegen | `pigeon` 29.0 (dev) | ✅ Adopted | |
| Time in tests | `clock` 1.1, `fake_async` 1.3 (dev) | ✅ Adopted | |
| Lints | `flutter_lints` 6.0 plus stricter rules | ✅ Adopted | |
| Grapheme counting | `characters` 1.4 | ✅ Adopted | |
| Expressive widgets | Community M3 Expressive packages (`m3e_core`, `material_expressive`) | ❌ Not needed | `material_ui` covers it; the community packages have few users |

**Not used:** `google_fonts` (downloads at runtime), anything Firebase or Google Play services, analytics or crash SDKs, `connectivity_plus` and `network_info_plus` (the bridge covers them), `flutter_local_notifications` (the bridge covers it), `video_thumbnail` (the bridge uses Android's `ThumbnailUtils`), `sqlite3_flutter_libs` (end-of-life).

### 5.2 App architecture rules

1. **No networking, file I/O or SQL in widgets.** Widgets read providers and call notifier methods.
2. **Riverpod is the only DI.** Classes take dependencies in their constructors; no top-level mutable state.
3. **Inject time.** Timeouts, retries and expiry use an injected `Clock` and timers, so tests use `fake_async`.
4. **Every inbound byte goes through the codec.** Malformed input becomes a `DecodeResult`, never an exception in a handler. After 3 bad frames in a row the connection is closed and counted in diagnostics.
5. **Every loop and socket has a timeout and a cleanup path.** Handles are closed in `finally`.
6. **Stream large data.** Use `File.openRead(start)` → chunks → socket, waiting on `flush()`/`addStream` for backpressure. Never call `readAsBytes` on a user file.
7. **The database is the source of truth.** Screens observe drift `watch` queries; the engine writes rows.
8. **Developer mode is hidden, not removed.** Tap the version number in About 7 times. It is on by default in debug builds.

### 5.3 Build modes

| Mode | Use | Settings |
|---|---|---|
| `debug` | Daily development | Developer screen unlocked, verbose logs |
| `profile` | Performance checks (§13.3) | Real AOT performance; DevTools connected |
| `release` | Thesis APK, demos | R8 shrinking, signed, developer screen locked, logs at info level with no content |

Release keys live outside the repository (`android/key.properties` is gitignored). Build with `flutter build apk --release`, and with `--split-per-abi` for smaller APKs to share.

### 5.4 Permissions by API level

| Permission | API | Runtime prompt | Why |
|---|---|---|---|
| `INTERNET` | All | No | Android requires it for **any** socket, LAN included. The app never contacts the internet; README says so. |
| `ACCESS_NETWORK_STATE` | All | No | Detect Wi-Fi and find the Wi-Fi `Network` to bind to |
| `ACCESS_WIFI_STATE` | All | No | Wi-Fi state, Wi-Fi lock |
| `CHANGE_WIFI_MULTICAST_STATE` | All | No | `MulticastLock`, so broadcast and mDNS packets aren't filtered. Also meets the `connectedDevice` service requirement. |
| `ACCESS_LOCAL_NETWORK` | 37+, only once `targetSdk` ≥ 37 | **Not requested while `targetSdk` is 36** (ADR-0015) | Apps below target 37 that declare `INTERNET` get local network access automatically. Once we target 37, it is a runtime permission (Nearby devices group); without it LAN sockets, mDNS and UDP fail with `EPERM`. |
| `POST_NOTIFICATIONS` | 33+ | Yes | Message notifications and transfer progress |
| `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_CONNECTED_DEVICE` | 28+ / 34+ | No | `LanForegroundService` (`foregroundServiceType="connectedDevice"`) |
| `WAKE_LOCK` | All | No | Keep the CPU and Wi-Fi awake during an active transfer only |
| `WRITE_EXTERNAL_STORAGE` (`maxSdkVersion 28`) | 26–28 | Yes, on the first *Save to Downloads* | API 29+ saves through MediaStore with no permission |
| `NEARBY_WIFI_DEVICES` (`neverForLocation`) | 33+ | Yes, when Wi-Fi Direct is chosen (P13) | Wi-Fi Direct discovery and connection |
| `ACCESS_FINE_LOCATION` (`maxSdkVersion 32`) | 26–32 | Yes, when Wi-Fi Direct or Bluetooth is chosen | Older Android requires it for Wi-Fi Direct and Bluetooth scanning |
| `BLUETOOTH_SCAN` (`neverForLocation`), `BLUETOOTH_ADVERTISE`, `BLUETOOTH_CONNECT` | 31+ | Yes, when Bluetooth is chosen (P14) | Find, be found by and connect to nearby phones |
| `BLUETOOTH`, `BLUETOOTH_ADMIN` (`maxSdkVersion 30`) | 26–30 | No | Bluetooth on older Android |

**Requested only for the chosen method:** Wi-Fi Direct and Bluetooth permissions are asked for when the user picks that method, never for Wi-Fi network or hotspot users.

**Not requested:** location on Android 13+ (the app never reads the Wi-Fi name), `READ_MEDIA_*` / storage reads (the system picker grants access per file), camera, microphone.

**Flow** (spec §17): an explainer screen comes before each system prompt ("Find people on this Wi-Fi", "Get notified about messages and transfers").
- If local network access is denied, the status shows *Local network access is off* with a button to Settings.
- If notifications are denied, everything still works, without notifications.

Before writing code, P0.3 checks the details against the [local network permission docs](https://developer.android.com/privacy-and-security/local-network-permission), including the re-request strategy.

### 5.5 LAN networking rules

Apply from P2. These cover the most common LAN failures on Android.

1. **Bind to Wi-Fi.** Request `TRANSPORT_WIFI` with `NET_CAPABILITY_INTERNET` removed and never require `VALIDATED`. Call `bindProcessToNetwork` while Wi-Fi is up; unbind when it goes down; rebind before recreating sockets after a change.
2. **Hold a `MulticastLock`** while discovery runs, and release it when discovery stops.
3. **Take the IPv4 address and prefix from the Wi-Fi `LinkProperties`.** Announce to the subnet broadcast address (e.g. `192.168.0.255`) and to `255.255.255.255`. Ignore your own packets by device ID.
4. **UDP discovery uses one fixed port** (proposed 28760; confirm it is unassigned in P0.4). Bind with `reuseAddress` and broadcast enabled. If the port is taken, report it in diagnostics; NSD still works.
5. **TCP listens on a preferred port** (proposed 28761). If that is busy, use an ephemeral port and advertise the real port in NSD TXT records and UDP announcements.
6. **Never trust an announced address alone.** A peer becomes online only after a TCP HELLO with a matching device ID.
7. **Simultaneous connects.** If two control connections exist between the same pair, keep the one opened by the lower device ID and close the other.
8. **Timeouts:**
   - Connect: 5 s
   - HELLO: 5 s
   - Control connections: PING every 15 s, closed after 2 missed PONGs
   - A data connection with no progress for 30 s is closed
9. **Reconnect** with exponential backoff plus jitter (1 s → 30 s). Reset the backoff when a fresh announcement arrives from that peer.
10. **On an IP change or Wi-Fi reconnect:** close all sockets, rebind, restart UDP and NSD, and announce at once. Peers learn the new address from the announcement.
11. **Caps:**
    - ≤ 32 control connections
    - ≤ 3 outgoing and ≤ 3 incoming transfers at a time
    - A rate limit on new inbound connections per IP
12. **Test on every testbed phone and router from the first spike onward.** If Android asks *"This network has no internet access. Stay connected?"*, answer **Yes** (this goes in the README).

### 5.6 Background behaviour

Spec §18 and §42: say plainly what works, and document what can't be guaranteed.

| App state | Discovery and messages | File transfers | How |
|---|---|---|---|
| In the foreground | Yes | Yes | Normal |
| In the background, transfer active | Yes | Yes, with notification *"Receiving video.mp4 — 62%"* | Foreground service, plus Wi-Fi lock and partial wake lock for that transfer only |
| In the background, idle, *Stay reachable* on | Yes, best effort | Yes | Low-importance ongoing notification *"Reachable on this Wi-Fi"*; switch off in Settings |
| In the background, idle, *Stay reachable* off | Until Android freezes the process (seconds to minutes) | No new transfers | Peers show you offline; their messages stay *Pending* and are delivered when you reopen the app |
| Swiped from Recents | Continues if the service is running (the engine is cached); otherwise stops | Same | |
| Force-stopped, rebooted, or killed by a battery saver | No | No; partial files are kept for resume | Documented limitation. No start on boot. |

- Android 12+ only allows starting a foreground service while the app is visible. The service starts when a transfer begins or when *Stay reachable* is switched on, and stops when neither applies.
- *Stay reachable* is off by default and offered once after onboarding (§16 Q6).
- Doze, standby buckets and OEM battery savers can still delay networking. `TESTING.md` records the behaviour per phone, and Settings links to the system battery page. The app doesn't request the battery-optimisation exemption.

---

## 6. Discovery, identity and names

### 6.1 Identity
- On first launch, generate a UUID v4 `deviceId` and store it. It survives restarts and changes only after *Clear all local data*, after which peers see a new device.
- Also store `username` and `nameClaimedAt`. Chats are keyed by `deviceId`, so renaming never splits a conversation.

### 6.2 Discovery flow

1. `NetworkMonitor` reports Wi-Fi up with an IP and prefix → bind (§5.5 rule 1) → take the `MulticastLock`.
2. **UDP:**
   - Send `DISCOVERY` as a broadcast. Every peer answers with a unicast `DISCOVERY_RESPONSE` after a random 0–300 ms delay.
   - After that, broadcast `HELLO` every 5 s ± 1 s in the foreground, or every 15 s when running under the service.
   - Send `GOODBYE` on a clean stop.
3. **NSD:** register `_resqmesh._tcp` with the **device ID as the instance name** (renames never touch NSD) and TXT records `id` and `v`. Discovered services are resolved and treated as candidate addresses.
4. **Confirm:** `PeerRegistry` merges candidates from both sources by `deviceId`, drops duplicates and updates changed IP/port. `ConnectionManager` opens a control connection, and the peer turns *online* when HELLO completes.

### 6.3 Peer lifecycle

```
discovered ──TCP HELLO ok──▶ online ──no announcement for 20 s and connection lost──▶ offline
     ▲                         │  └──GOODBYE──▶ offline (immediately)
     └──── new announcement ◀──┘
```

| Timer | Value |
|---|---|
| Announcement interval | 5 s foreground, 15 s background |
| Offline after | 20 s without an announcement **and** no live control connection |
| NAME_CHECK wait | 3 s |
| "No nearby devices" hint | 30 s on Wi-Fi with zero peers |

- Offline peers stay in the database with `lastSeen`.
- A known `deviceId` arriving from a new IP updates the address and reconnects.
- If a second address claims a device ID that already has a live connection, the live connection wins and the event is logged. Without encryption this can't be proven either way (§9).

### 6.4 Username rules (spec §5)
- **Normalise:** trim, then collapse runs of whitespace to one space.
- **Valid:** 2–30 characters, counted as graphemes; no control characters or line breaks; any script, Bangla included.
- **Unique:** compared without case on the normalised form.
- **Onboarding check:**
  1. Validate locally.
  2. Broadcast `NAME_CHECK` and check the online peers, showing *"Checking name on this network…"* for up to 3 s.
  3. If the name is taken, show **"This name is already being used on this network."**
  4. Otherwise save the name and send `REGISTER`.
- **No peers or no Wi-Fi:** accept the name (spec §5), mark it *unverified*, and check again on the next connection.
- **Later clash** (two networks merge): the earlier `nameClaimedAt` keeps the name, with ties going to the lower device ID. The other phone shows a persistent banner *"Your name is also used by another device on this network"* with **Change name**. Until it changes, peers show that device as `Yusuf · 3f2a` (short device ID).
- **Change name** (Settings): same validation and check, then `REGISTER` to every peer. Peers update the name; chat history is unchanged.

### 6.5 Network status (spec §6, §16, §31)

| State | App bar shows | Condition |
|---|---|---|
| Connected | 🟢 Local network connected · *N nearby* | Wi-Fi up, bound, ≥ 1 peer online |
| Searching | 🟠 Searching for devices… | Wi-Fi up, no peers yet |
| No Wi-Fi | 🔴 Wi-Fi disconnected | No Wi-Fi network |
| Blocked | 🔴 Local network access is off | `ACCESS_LOCAL_NETWORK` denied, or sockets fail with `EPERM` |

- Each state uses a dot, an icon and text, never colour alone.
- **Internet availability is never checked or shown.** "No internet" is not a state.
- **Isolation hint** after 30 s of *Searching* (spec §31):

  > No nearby devices found.
  > Make sure:
  > • Everyone is connected to the same Wi-Fi
  > • The router allows device-to-device communication
  > • The app is allowed to access the local network

- If a peer is discovered but TCP to it fails, show the stronger hint *"Found Rahim, but couldn't connect. The router may be blocking device-to-device traffic."* One phone can't prove isolation, so the app never says it is broken.

---

## 7. Protocol

Draft; the final version goes in `PROTOCOL.md` (P0.4) with matching JSON fixtures in `test/fixtures/protocol/`.

### 7.1 Framing
- **TCP:** `kind (1 B) · length (4 B, uint32 big-endian) · body`.
  - `0x01` is a JSON control packet, UTF-8, ≤ 64 KiB.
  - `0x02` is a binary file chunk, ≤ 256 KiB, allowed on data connections only.
  - The length is checked before buffering; a violation closes the connection.
- **UDP:** one control packet per datagram: the 4-byte magic `RQM1` followed by JSON, ≤ 1,400 B so it never fragments. Datagrams without the magic are ignored.

### 7.2 Envelope

```json
{
  "protocolVersion": 1,
  "type": "MESSAGE",
  "messageId": "6f1c2a0e-8a4b-4d1e-9a51-2c7f0b3e9d10",
  "senderId": "3f2a9c4e-…",
  "senderName": "Yusuf",
  "receiverId": "b81d07aa-…",
  "timestamp": "2026-10-08T20:42:13.512Z",
  "payload": { "messageType": "text", "audience": "direct", "text": "Hello" }
}
```

- `protocolVersion` must be 1. Later versions advertise a supported range in HELLO.
- `messageId`, `senderId` and `receiverId` are UUIDs; `receiverId` may also be `*`.
- On TCP, `senderId` must equal the device ID from that connection's HELLO.
- `timestamp` is the sender's clock and only informational. **Chats are ordered by local time**, because phone clocks aren't synchronised.
- Unknown `type`: ignore and log, for forward compatibility. Unknown payload fields: ignore. Missing or invalid required fields: drop and count.

### 7.3 Packet types

| Type | Channel | Main payload fields | Purpose |
|---|---|---|---|
| `DISCOVERY` | UDP broadcast | — | "Who is here?" on start and after a network change |
| `DISCOVERY_RESPONSE` | UDP unicast | same as HELLO | Immediate answer to DISCOVERY |
| `HELLO` | UDP broadcast every 5 s; **first frame on every TCP connection** | `name`, `nameClaimedAt`, `tcpPort`, `appVersion`, `minProtocol`, `maxProtocol`, `capabilities` | Identity, liveness, handshake |
| `GOODBYE` | UDP broadcast + TCP | `reason` | Clean exit or Wi-Fi going down |
| `NAME_CHECK` | UDP broadcast | `candidateName` | Ask "is this name taken?" before registering |
| `REGISTER` | TCP control | `name`, `nameClaimedAt` | Claim a name at onboarding or on change |
| `REGISTER_RESPONSE` | UDP unicast or TCP | `result`: `ok` or `nameTaken`, `holderId`, `holderClaimedAt` | Answer to NAME_CHECK (only holders reply) and to REGISTER |
| `MESSAGE` | TCP control | `messageType` (`text`, `file`), `audience` (`direct`, `broadcast`, `multi`), `text`, `replyToId`, `file` {`fileId`, `name`, `size`, `mimeType`, `sha256`} | Chat content; a file message announces the file |
| `MESSAGE_ACK` | TCP control | `ackFor` | Receiver validated and **stored** the message → sender shows **Sent ✓** and stops retrying |
| `MESSAGE_DELIVERED` | TCP control | `messageIds[]` | Shown to the recipient (chat on screen or notification posted) → **Delivered ✓✓** |
| `MESSAGE_READ` | TCP control | `messageIds[]` | Recipient opened the chat → **Read** (✓✓ in accent colour) |
| `FILE_OFFER` | TCP data, first frame | `fileId`, `chatMessageId`, `fileName`, `fileSize`, `mimeType`, `sha256` | Opens a transfer (spec §11's FILE_METADATA) |
| `FILE_ACCEPT` | TCP data | `offset` | Ready; send from `offset` (spec §11's READY; > 0 means resume) |
| `FILE_REJECT` | TCP data | `reason`: `declined`, `noSpace`, `tooLarge`, `invalid` | Refuse the transfer |
| `FILE_CHUNK` | TCP data, binary frame `0x02` | raw bytes | File data; no JSON envelope; the connection identifies the file |
| `FILE_COMPLETE` | TCP data | `sha256` | Receiver verified the checksum and saved the file |
| `FILE_CANCEL` | TCP data (or control if no data connection) | `reason`: `cancelled`, `paused`, `error`, `checksumMismatch` | Stop. The partial file is kept unless the reason is `cancelled`. |
| `PING` / `PONG` | TCP control | `nonce` | Keep-alive; round-trip time for diagnostics |

In Dart, `sealed class Packet` has one final subclass per row, and `PacketCodec` provides `encode(Packet)` and `decode(bytes) → DecodeResult`. Handlers `switch` exhaustively, and raw JSON never leaves the codec (spec §19).

### 7.4 Messages and statuses

```
Sender                                          Receiver
insert row (Sending, or Pending if offline)
MESSAGE ──────────────────────────────────────▶ validate · de-duplicate (senderId, messageId) · insert
◀─────────────────────────────── MESSAGE_ACK    → Sent ✓
                                                 chat on screen or notification posted
◀───────────────────────── MESSAGE_DELIVERED    → Delivered ✓✓
                                                 user opens the chat
◀────────────────────────────── MESSAGE_READ    → Read ✓✓ (accent)
```

| Status | Meaning |
|---|---|
| Pending | Peer is offline; waiting in the outbox |
| Sending | On the wire, waiting for MESSAGE_ACK |
| Sent | Receiver stored it |
| Delivered | Receiver's phone showed it |
| Read | Receiver opened the chat |
| Failed | Rejected by the receiver, or 5 attempts while the peer was online with no ACK. Shows **Retry**. |

- **Retries:** if no ACK arrives within 10 s on a live connection, resend with the **same** `messageId`. If the connection drops, go back to Pending. Pending never expires on its own (spec §15); the user can delete it.
- **De-duplication:** the receiver has a unique index on (`senderDeviceId`, `messageId`). A duplicate is ACKed again but not stored or notified twice.
- **Outbox:** runs when a peer comes online, at app start, after a network change, and on manual retry. It keeps first-in, first-out order per peer. Delivery and read receipts queue in the outbox too, so they survive reconnects.
- **Broadcast and multi-select:**
  - One local message row plus one `message_recipients` row per recipient, each with its own status, summarised as "Delivered to 3 of 5".
  - *Send to everyone* goes to the peers online at that moment (spec §14). Receivers show it in an **Everyone** thread with the sender's name.
  - *Selected people* are queued like 1:1 messages and appear in each recipient's chat with the sender.

### 7.5 File transfer (spec §11–13)

```
Sender                                            Receiver
MESSAGE{messageType: file, file{…}} ── control ─▶ file row: offered → MESSAGE_ACK
open data connection ───────────────────────────▶
HELLO ◀────────────────────────────────────────▶ HELLO
FILE_OFFER{fileId, name, size, mime, sha256} ───▶ check IDs, size, free space, duplicates
◀────────────────────────────── FILE_ACCEPT{offset}  (or FILE_REJECT{reason})
FILE_CHUNK × n (binary, 64–256 KiB) ────────────▶ write <fileId>.part · hash as it arrives
◀────────────────────────────── FILE_COMPLETE{sha256} after checksum ok · fsync · atomic rename
mark completed                                       mark completed
```

- **Accepting:** files are received automatically unless one of these applies:
  - The size exceeds free space minus a 200 MB margin → `noSpace`
  - The size exceeds the *Max file size* setting (default 4 GiB) → `tooLarge`
- **Streaming:** the sender reads 64 KiB at a time from `offset` and waits on socket backpressure; the right chunk size is measured in P6. Memory use stays flat whatever the file size.
- **Progress:** bytes, percentage, speed (moving average over 2 s) and time left. The UI updates at most 10 times a second and the notification once a second.
- **Pause and resume:** pause sends `FILE_CANCEL{paused}` and keeps the `.part` file. Resume opens a new data connection, and `FILE_ACCEPT{offset = .part size}` continues from there. The receiver re-hashes the partial file before continuing.
- **Dropped connections** resume automatically with backoff (3 tries), then the transfer turns *Failed* with **Retry**.
- **Cancel** from either side sends `FILE_CANCEL{cancelled}`; the receiver deletes the `.part` file.
- **Checksum mismatch:** delete the `.part`, send `FILE_CANCEL{checksumMismatch}`, retry once from zero, then *Failed*.
- **Duplicates:**
  - If `fileId` is already complete, the receiver answers `FILE_COMPLETE` at once.
  - If the same sender's `sha256` + size is already stored, the receiver reuses that file and answers `FILE_COMPLETE` without a transfer.
- **Multiple files:** each file gets its own MESSAGE, card and transfer. At most 3 run at a time per direction.
- **Sender's copy:** the picked file is kept under `files/sent/<fileId>` until the user clears it in Storage. A retry after that fails with *"File no longer available"*.

### 7.6 Limits and validation

| Item | Limit |
|---|---|
| Control frame | 64 KiB |
| UDP datagram | 1,400 B |
| File chunk frame | 256 KiB |
| Text message | 16 KiB of UTF-8 |
| Displayed file name | 255 UTF-8 bytes after sanitising |
| File size | ≤ free space − 200 MB, and ≤ *Max file size* (default 4 GiB) |
| `deviceId`, `messageId`, `fileId` | UUID format |
| `protocolVersion` | 1 |
| HELLO handshake | 5 s, then the connection is closed |
| Malformed frames | Connection closed after 3 in a row; counted in diagnostics |

---

## 8. Data and storage

### 8.1 Database schema (drift)

Fields from spec §9, plus additions needed for status, threads and resume. **As built (D22):** schema v1 (P5) has `messages` only, with `messageId` unique on its own, a `peerName` column, `body` for the text, times as UTC microseconds and no `audience`/`messageType`/`fileId` yet. The other tables below arrive as migrations in the phases that use them. The tables here are the target design.

**`peers`**

| Column | Notes |
|---|---|
| `id` | Primary key |
| `deviceId` | Unique |
| `username` | |
| `ipAddress`, `port` | Last known address |
| `status` | `online` or `offline` |
| `lastSeen` | |
| `nameClaimedAt` | |
| `createdAt`, `updatedAt` | |

Indexes: `status`; `lower(username)`.

**`messages`**

| Column | Notes |
|---|---|
| `id` | Primary key |
| `localMessageId` | UUID; also the `messageId` on the wire |
| `conversationId` | The peer's `deviceId`, or `everyone` |
| `direction` | `in` or `out` |
| `senderDeviceId`, `receiverDeviceId` | |
| `audience` | `direct`, `broadcast` or `multi` |
| `messageType` | `text` or `file` |
| `text` | |
| `fileId` | |
| `replyToId` | |
| `timestamp` | Sender's clock |
| `status` | §7.4 |
| `isRead` | |
| `receiptSent` | `none`, `delivered` or `read` |
| `attempts`, `lastAttemptAt` | Outbox state |
| `createdAt` | Local clock; used for ordering |

Indexes: **unique** (`senderDeviceId`, `localMessageId`); (`conversationId`, `createdAt`); (`status`) for the outbox; (`conversationId`, `isRead`) for unread counts.

**`message_recipients`**

| Column | Notes |
|---|---|
| `messageId` | Points to `messages` |
| `recipientDeviceId` | |
| `status` | Per recipient |
| `updatedAt` | |

Primary key: (`messageId`, `recipientDeviceId`). Used for broadcast and multi-select.

**`files`**

| Column | Notes |
|---|---|
| `id` | Primary key |
| `fileId` | Unique |
| `messageId` | |
| `originalName` | As received |
| `displayName` | Sanitised |
| `localPath` | Always `<dir>/<fileId>` |
| `mimeType` | |
| `size`, `bytesTransferred` | |
| `direction` | `in` or `out` |
| `senderDeviceId`, `receiverDeviceId` | |
| `transferStatus` | `offered`, `queued`, `inProgress`, `paused`, `completed`, `failed`, `cancelled`, `rejected` |
| `checksum` | SHA-256 |
| `thumbnailPath` | |
| `createdAt`, `updatedAt` | |

Indexes: **unique** `fileId`; (`checksum`, `size`) for duplicate detection; `transferStatus`.

- The chat list is a query (latest message and unread count per conversation), not a table. Add a table only if profiling shows it is needed.
- No file contents go in SQLite (spec §9).
- Every schema change gets a migration and a drift schema snapshot test.

### 8.2 File storage

```
<applicationSupportDirectory>/files/
├── received/<fileId>        # completed incoming files
├── partial/<fileId>.part    # in-progress or paused incoming files
├── sent/<fileId>            # stable copies of files being sent
└── thumbs/<fileId>.jpg      # image and video thumbnails
```

App-internal storage is private and removed on uninstall. Users get files out with **Open** or **Share** (through `FileProvider`) or **Save to Downloads** (MediaStore).

**`FileNameSanitizer`** (spec §28):
1. Keep only the last path segment, splitting on both `/` and `\`.
2. Remove control characters and `< > : " / \ | ? *`; trim spaces and dots at both ends.
3. Replace empty, `.` or `..` with `file`.
4. Truncate to 255 UTF-8 bytes, keeping the extension.
5. On export, rename collisions to `name (1).ext`.

The path on disk is always built from our own `fileId`. The sanitised name is used only for display and export.

### 8.3 Storage screen (spec §27)

- **Shows:** number of messages; files received (count and size); files sent (count and size); partial files and cache; total.
- **Actions:**
  - *Clear cached files:* sent copies, thumbnails, partial files not in progress
  - *Delete received files:* messages stay, and their cards show "File deleted"
  - *Clear chat history*
  - *Clear all local data:* database, files and identity; the app returns to onboarding
- Each action opens a confirmation dialog that says exactly what will be lost, with the destructive button in the error colour. Actions run in the background and show progress.

---

## 9. Security

| Topic | Design |
|---|---|
| Trust model | Trusted LAN. Anyone on the same Wi-Fi running the app, or a modified copy, can see you and send you messages and files. The README states this plainly. |
| Identity | Random device ID (D12). Without encryption, someone on the LAN can spoof a device ID; this is documented. With D17, each device's certificate is pinned to its ID on first contact, and a changed key raises a warning. |
| Packet validation | Every limit and check in §7.6. Malformed input is dropped and never crashes the app (fuzz tests in P9). |
| Resource limits | Frame, connection and transfer caps; inbound rate limit per IP; handshake and idle timeouts; free-space check before accepting a file |
| Files | Disk path from our own `fileId` (D14); names sanitised; files are never opened automatically. An APK opens only when the user taps it, through the system installer. |
| Logs | No message text or file names at the default level (spec §35). Short device IDs and private LAN IPs are allowed. |
| Data at rest | Android app sandbox only; no extra database encryption (documented) |
| Encryption in transit (D17, P9) | **Decided (ADR-0022): not in v1.0** — spike measured −93% throughput with TLS on loopback and `dart:io` can't pin the sender; documented in README and Settings → Privacy; revisit after v1.0. Original plan: | **Spike:** TLS 1.3 over `dart:io` `SecureSocket` on control and data connections. Each device has a key pair and a self-signed certificate; peers pin the fingerprint per device ID on first use, and Peer details show it for manual comparison. UDP discovery stays plaintext (no content). **Go** if the full device matrix passes and file throughput drops by ≤ 20%. **Otherwise** look for a maintained implementation of an established handshake such as Noise XX; if none passes vetting, ship plaintext and document it. Never a home-made scheme. |

---

## 10. Features and screens

### 10.1 Priorities

| Priority | Features |
|---|---|
| **Must** | Onboarding with a unique name · persistent device ID · discovery and People Nearby · network status · 1:1 text chat with Sending / Sent / Delivered / Pending / Failed · reply, copy, delete, retry · file, image, video and document messages, several at once · streamed transfer with progress, speed, time left, cancel, retry, checksum and duplicate detection · offline queue · broadcast to everyone and to selected people · SQLite and file storage · Storage screen · Change name · foreground service during transfers · permissions with explanations · security hardening · developer screen · structured logs · light and dark themes with dynamic colour · empty, loading and error states · the four documents · release APK |
| **Should** | Read status · pause and resume · *Stay reachable* background mode · encryption (D17) |
| **Could** | Bangla UI · *Connect by IP* in the developer screen · ask before receiving large files · read-receipt switch · voice notes (§16 Q4) |
| **Won't** | Anything using the internet · iOS · BLE or mesh · calls · delete for everyone · group membership |

### 10.2 Screens (spec §23)

| Screen | Contents | Phase |
|---|---|---|
| Splash | Loads identity and database, then opens onboarding or Home. No artificial delay. | P1 |
| Choose your name | Text field, live validation, *Checking name on this network…*, "name taken" error | P1, P2 |
| Permission explainer | Why local network and notifications are needed, then the system prompt | P2 |
| Home (Chats) | Large app bar *LAN Chat* (§16 Q5) with status; search; chat rows with avatar, name, online dot, last message or 📎 file name, time, unread badge; *Everyone* thread; expressive FAB menu (New chat / Broadcast) | P4, P5 |
| People Nearby | Peer cards with avatar, name, online or last seen, **Open chat** and **Send file**. IP/port hidden unless expanded or in developer mode. Multi-select → *Send to selected*; *Send to everyone*. | P2, P7 |
| Chat | Day separators, bubbles, times, status ticks, reply preview; long-press for Reply / Copy / Delete / Retry; file cards with progress; composer with attach, text and send | P4, P6 |
| File Preview | Image (zoomable); video thumbnail + Open; document icon and details; generic card for anything else; **Open**, **Share**, **Save to Downloads**. Never assume a file can be previewed. | P6 |
| File Transfer Details | Name, size, type, peer, progress bar, %, bytes, speed, time left, status; **Pause / Resume / Cancel / Retry** | P6 |
| Activity | Active and recent transfers, peers joining and leaving, failed deliveries; tap for details | P8 |
| Settings | Profile (name, short device ID), Change name, Stay reachable, Notifications, Theme, Storage, About | P1 → P11 |
| Change Username | Same checks as onboarding, then re-registers on the LAN | P2 |
| Storage | §8.3 | P6, P11 |
| About | Version, licences, how the app works offline, router-isolation help; tap the version 7 times for developer mode | P11 |
| Developer (hidden) | Local IP, prefix and broadcast address; UDP/TCP ports; Wi-Fi binding and multicast lock state; peers with source (UDP/NSD), IP, port, last seen and RTT; connection states; active transfers; packets sent and received by type; malformed and error counts; recent logs; **Export logs**; **Re-announce** | P2 onward |

### 10.3 UX states and motion (spec §22, §37)
- **Every state has visible copy:**
  - Searching / No devices found (with the isolation hint) / Connected / Disconnected
  - Pending (*"Will send when Rahim is back"*) / Sending / Sent / Delivered / Read / Failed + Retry
  - Receiving / Completed / Cancelled
  - Empty chat list (*"No chats yet. People on this Wi-Fi appear in People Nearby."*)
  - Skeleton loading and error banners
- **Expressive tokens:**
  - Corner radius scale 8 / 12 / 16 / 28 / full
  - Large collapsing titles and emphasised weights
  - Motion with emphasised easing, 200–500 ms; shared-axis transition between list and chat
  - Dynamic colour on Android 12+, with a seed colour as the fallback
- **Restraint:** no looping animation except the searching indicator. Respect *Remove animations* (`MediaQuery.disableAnimations`).
- **Accessibility:**
  - Text contrast ≥ 4.5:1
  - Touch targets ≥ 48 dp
  - TalkBack labels for status icons ("Delivered", "Read")
  - Usable at 200% text size

---

## 11. Schedule and backlog

Phases P1–P12 follow spec §39. P0 covers this week's planning work.

**Spec §40 applies:** every phase ends with the phase gate (§15.1) before the next one starts.

### 11.1 Week by week

| Wk | Dates | Phase | Focus |
|---|---|---|---|
| 1 | 1–7 Oct | — | Before this plan |
| **2** | **8–14 Oct** | **P0** | **Plan review, decisions, package vetting, protocol v0.1, discovery spike** |
| 3 | 15–21 Oct | P1 | Flutter project, theme, onboarding, identity storage, logger |
| 4 | 22–28 Oct | P2 | Bridge (Wi-Fi binding, multicast lock), network status, UDP discovery |
| 5 | 29 Oct–4 Nov | P2 | NSD, peer registry, unique names, People Nearby, developer screen |
| 6 | 5–11 Nov | P3 | TCP server/client, framing, HELLO, keep-alive, reconnect |
| 7 | 12–18 Nov | P4 | Text messaging, receipts, chat UI |
| 8 | 19–25 Nov | P5 | SQLite (drift), outbox, chat list |
| 9 | 26 Nov–2 Dec | P6 | Picker, transfer isolate, data connection, streaming |
| 10 | 3–9 Dec | P6 | Progress, cancel, retry, resume, duplicates |
| 11 | 10–16 Dec | P6 | Previews, transfer details, 2 GB soak test · **mid-term presentation** |
| 12 | 17–23 Dec | P7 | Broadcast and multi-select |
| 13 | 24–30 Dec | P8 | Foreground service, cached engine, notifications, Activity |
| 14 | 31 Dec–6 Jan | P9 | Security hardening, encryption spike · **feature freeze** |
| 15 | 7–13 Jan | P10 | Test gaps, integration tests |
| 16 | 14–20 Jan | P11 | UI polish, accessibility, remaining screens |
| 17 | 21–27 Jan | P12 | Release signing, APK, full device matrix |
| 18 | 28 Jan–3 Feb | — | Fixes from the matrix, docs final, v1.0.0 |
| 19 | 4–10 Feb | — | Report: results and figures |
| 20 | 11–17 Feb | — | Final report, defense |

**Capacity note:** Victory Day (16 Dec) and the year-end holidays fall in Weeks 11–14. The lighter phases (P7–P9) sit there, so most of P6 must be done by the end of Week 10.

### 11.2 Backlog

Task IDs (`P6.3`) go in branch names and commit messages (§15.3).

#### P0 · Plan, decisions, discovery spike (Week 2, 8–14 Oct)
- [ ] **P0.1** Review this plan with the supervisor; settle the open questions (§16)
- [x] **P0.2** Vet the packages (§5.1), pin versions and fill in the Status column; check the M3 Expressive community packages
- [ ] **P0.3** Confirm platform facts:
  - [x] `ACCESS_LOCAL_NETWORK` rules: enforced only from `targetSdk` 37 (ADR-0015)
  - [x] `connectedDevice` service requirements: `FOREGROUND_SERVICE_CONNECTED_DEVICE` plus a prerequisite permission, met by `CHANGE_WIFI_MULTICAST_STATE`; the service starts only while the app is visible or already running (P8)
  - [x] `file_picker` copies every picked file into the cache (ADR-0014)
  - [x] Flutter 3.47.6 defaults: `compileSdk` 36, `targetSdk` 36, `minSdk` 24
  - [ ] Whether `bindProcessToNetwork` applies to `dart:io` sockets (needs phones; P0.5)
- [x] **P0.4** `PROTOCOL.md` v0.1 from §7; confirm the UDP/TCP port numbers; save the build specification as `docs/SPEC.md`
- [ ] **P0.5** Discovery spike (throwaway app): UDP broadcast, NSD and one TCP message between 2 phones on a router with the internet unplugged and mobile data on; record results per phone and router
- [ ] **P0.6** Testbed inventory (§13.4), including a router with an AP-isolation setting
- [x] **P0.7** ADRs for D1–D19

**Exit:** decisions recorded; the spike shows A ↔ B discovery and one TCP message with the router's internet off, or a documented workaround.

#### P1 · Foundation: project, theme, onboarding (Week 3, 15–21 Oct)
- [x] **P1.1** `git init`; `flutter create` (Android only) at the repository root; `.gitignore`; `analysis_options.yaml`; optional CI (not set up yet)
- [x] **P1.2** Folder layout (§4.1), `ProviderScope`, `go_router`, bootstrap
- [x] **P1.3** Theme: Material 3 plus expressive tokens, dynamic colour with a seed fallback, light and dark, bundled fonts
- [x] **P1.4** Identity: device ID and username persisted (`IdentityRepository`)
- [x] **P1.5** Splash → Choose your name (local rules from §6.4) → Home shell; Settings shell with Change name (local only for now)
- [x] **P1.6** Structured logger (§15.4)
- [x] **P1.7** Android setup: application ID, app name, icon, min/target SDK, release signing config with keys kept outside the repo
- [x] **P1.8** Tests: username validation, identity persistence, onboarding widget test

**Exit:** the app installs; first launch asks for a name; relaunch skips onboarding; format, analyze and test are clean.

*Result (8 Oct):* gate passed — format, analyze, 36 tests and `flutter build apk --release` clean; the onboarding, relaunch and Change name flows pass as whole-app widget tests. Install on a phone still to do.

#### P2 · LAN discovery (Weeks 4–5, 22 Oct–4 Nov)
- [x] **P2.1** Kotlin bridge (pigeon): Wi-Fi network callback, IP and prefix, `bindProcessToNetwork`, `MulticastLock`
- [x] **P2.2** `NetworkMonitor` and status (§6.5). No runtime permission is needed for LAN at targetSdk 36, so the explainer and the `POST_NOTIFICATIONS` request move to P4, when notifications first exist (spec §17: don't ask for permissions you don't use yet)
- [x] **P2.3** Protocol core: frame codec, sealed packets (discovery subset), validation, golden fixtures
- [x] **P2.4** UDP discovery: DISCOVERY, DISCOVERY_RESPONSE, HELLO and GOODBYE; magic; ignoring own packets; de-duplication
- [x] **P2.5** NSD register, discover and resolve; merged with UDP results in `PeerRegistry` by device ID
- [x] **P2.6** Peer lifecycle and timers (§6.3): IP change, Wi-Fi reconnect, app restart
- [x] **P2.7** Unique names: NAME_CHECK and REGISTER_RESPONSE used by onboarding and Change name; HELLO carries renames; banner for later clashes. REGISTER itself travels over TCP from P3.
- [x] **P2.8** People Nearby; "No nearby devices" hint
- [x] **P2.9** Developer screen v1 (network, ports, peers, packet counters, logs)
- [x] **P2.10** Tests: registry de-duplication and expiry on fake time, malformed codec input, name rules, UDP over loopback

**Exit (M2):**
- 2 phones (3 if available) see each other within 10 s with the router's internet unplugged and mobile data on
- Names are unique
- A peer shows offline within 20 s of its Wi-Fi going off
- Peers are rediscovered after a router reboot

P3 then tightens "online" to require a TCP HELLO.

#### P3 · TCP connections (Week 6, 5–11 Nov)
- [x] **P3.1** TCP server (preferred port, ephemeral fallback) and client; frame reader with length limits
- [x] **P3.2** HELLO handshake, version check, sender ID bound to the connection
- [x] **P3.3** `ConnectionManager`: one control connection per peer, tie-break (§5.5 rule 7), PING/PONG, timeouts, reconnect with backoff
- [x] **P3.4** Online = handshake complete; stronger isolation hint when a peer is discovered but unreachable
- [x] **P3.5** Network change handling: close, rebind and restart on an IP change
- [x] **P3.6** Tests: real TCP sockets on loopback covering handshake, tie-break, keep-alive, idle timeout, reconnect, network reset, malformed and oversized frames, wrong device, self-connection (16 tests, stable over repeated runs)

**Exit:** control connections stay up for 30 min idle on 2 phones, and reconnect after a Wi-Fi toggle and a router reboot without restarting the app.

*Result (9 Oct):* gate passed (format, analyze, 138 tests, release build). On the Android 17 emulator the app connected to `tool/lan_peer_sim.py` over TCP, kept the connection alive with PING/PONG, and sent REGISTER on a rename. Two-phone run still needed.

#### P4 · Text messaging (Week 7, 12–18 Nov)
- [x] **P4.1** MESSAGE, MESSAGE_ACK, MESSAGE_DELIVERED and MESSAGE_READ handlers; de-duplication on (`senderId`, `messageId`)
- [x] **P4.2** Send use case and status machine (§7.4); resend when the ACK is missing
- [x] **P4.3** Chat screen: bubbles, day separators, times, status ticks, reply, copy, delete, retry
- [x] **P4.4** Notification for an incoming message when its chat isn't open; `POST_NOTIFICATIONS` asked on the first chat, after a short explainer
- [x] **P4.5** Tests: status transitions, duplicate delivery, receipts arriving out of order, end-to-end text over loopback

Repositories are interfaces from P4 on. P5 replaced the in-memory version with drift; tests use drift on in-memory SQLite (D22).

**Exit:** text works both ways between A and B, with Sent, Delivered and Read.

#### P5 · SQLite persistence (Week 8, 19–25 Nov)
- [x] **P5.1** drift database (§8.1): tables, indexes, schema v1 snapshot (`messages` only, D22)
- [x] **P5.2** Repositories on drift; `watch` queries drive Home and Chat; unread counts
- [x] **P5.3** Outbox: Pending while offline; runs when a peer comes online, at app start and after a network change; queued receipts
- [x] **P5.4** Home chat list (last message, time, unread badge, online dot) and search
- [x] **P5.5** Clear chat history (first Storage action): Settings → Storage with the message count
- [x] **P5.6** Tests: DAOs on an in-memory database, migration test scaffold, outbox after reconnect, app restart with pending messages

**Exit (M3):** messages survive restarts; a message sent to an offline peer is delivered automatically when the peer returns.

#### P6 · File transfer (Weeks 9–11, 26 Nov–16 Dec)
- [x] **P6.1** Picker for one or several files; selection sheet with name, size and type; **Send**; stable copies in `sent/`
- [x] **P6.2** Transfer worker isolate: streamed SHA-256, progress messages, cancellation
- [x] **P6.3** Data connection protocol: FILE_OFFER, ACCEPT, REJECT, CHUNK, COMPLETE and CANCEL with backpressure
- [x] **P6.4** Receiver side: validation (§7.6), free-space check, `.part` writes, hashing as data arrives, fsync and atomic rename
- [x] **P6.5** Progress UI (%, bytes, speed, time left), **Cancel**, **Retry**
- [x] **P6.6** Pause and resume by offset; automatic resume after a dropped connection
- [x] **P6.7** Duplicate detection (by `fileId`, and by `sha256` + size)
- [x] **P6.8** `FileNameSanitizer` and storage layout (§8.2)
- [x] **P6.9** File cards in chat; File Preview (image, video thumbnail via the bridge, document, generic); Open, Share, Save to Downloads
- [x] **P6.10** File Transfer Details screen; Storage screen v1 (§8.3)
- [x] **P6.11** Tests:
  - Sanitiser traversal cases and checksum vectors
  - Transfer state machine
  - Loopback transfer of a generated 200 MB file with cancel, resume and injected corruption, while memory stays flat
- [ ] **P6.12** Device soak test: a 2 GB file in each direction; record throughput and memory (§13.3). *Emulator done (1 GB in, 300 MB out, TESTING.md); two real phones still to do.*
- [ ] **P6.13** Mid-term slides and a live demo

**Exit (M4):**
- A 2 GB file goes A → B and B → A with the checksum verified, memory flat and the UI smooth
- Cancel, retry and resume work
- Mid-term presented

#### P7 · Broadcast and multi-select (Week 12, 17–23 Dec)
- [x] **P7.1** `message_recipients` with per-recipient status; summary UI ("Delivered to 3 of 5")
- [x] **P7.2** *Send to everyone* (peers online at that moment) → *Everyone* thread on the receivers
- [x] **P7.3** Multi-select in People Nearby → send text or files to the selected people (queued for those offline). *As built: each selected person gets their own direct message (one copy and one hash per file); only Everyone uses `message_recipients`.*
- [x] **P7.4** File fan-out with the concurrency cap
- [x] **P7.5** Tests: fan-out statuses, partial failure, 3 nodes over loopback

**Exit:** 3 phones receive a broadcast text and file, with correct per-recipient status. *Shown on loopback with real sockets and engines (test); on 3 real phones still to do.*

#### P8 · Background receiving (Week 13, 24–30 Dec)
- [x] **P8.1** Cached `FlutterEngine` in `Application`; `MainActivity` attaches to it
- [x] **P8.2** `LanForegroundService` (`connectedDevice`): starts with transfers, shows *"Receiving video.mp4 — 62%"*, stops when idle
- [x] **P8.3** *Stay reachable* setting, offered once; low-importance ongoing notification
- [x] **P8.4** Wi-Fi lock and partial wake lock during active transfers only
- [x] **P8.5** Notification taps open the chat or transfer details; Activity screen
- [ ] **P8.6** *(Emulator done: screen off, background, swiped away, Doze; see TESTING.md. Real phones and OEM battery savers still to do.)* Lifecycle checks on devices (screen off, background, swiped away, Doze via `adb shell dumpsys deviceidle force-idle`, OEM battery savers); results in `TESTING.md`, limitations in the README

**Exit:** a 1 GB file is received with the screen off and the app in the background; every row of §5.6 is checked and documented. *Shown on the emulator (1 GB in 32 s, screen off, app in the background); real phones still to do.*

#### P9 · Security hardening (Week 14, 31 Dec–6 Jan)
- [x] **P9.1** Review every inbound path against §7.6 and §9; add any missing checks
- [x] **P9.2** Fuzz tests: random, truncated and oversized frames and JSON into the codec and connections (no crash; connection closed)
- [x] **P9.3** Rate and connection limits; handshake timeout against slow clients
- [x] **P9.4** Log review: no message text or file names at the default level
- [x] **P9.5** Encryption spike (D17): TLS with pinning; measure throughput and stability; go/no-go ADR; if go, negotiate through `capabilities` in HELLO. *No-go for v1.0 (ADR-0022): −93% throughput on loopback, sender can't be pinned with `dart:io`; revisit after v1.0.*
- [x] **P9.6** Security model section for the README and `ARCHITECTURE.md`
- [x] **P9.7** Feature freeze; tag `v0.9.0-beta`

**Exit (M5):** all inbound validation in place and fuzzed; encryption decision recorded; feature complete.

#### P10 · Automated tests (Week 15, 7–13 Jan)
- [x] **P10.1** Fill gaps against §13.1; coverage target ≥ 80% for `core/` and `data/` *(core 82.7%, data 91.1%; platform wrapper tests added)*
- [x] **P10.2** `integration_test` on a device: onboarding, sending text and a file to an in-process test peer *(over the device's Wi-Fi address; 5 MB file, SHA-256 checked)*
- [x] **P10.3** Reconnect, timeout and retry tests with `fake_async` *(already covered in P3–P8; redial backoff curve added)*
- [x] **P10.4** Migration tests from schema v1
- [x] **P10.5** `TESTING.md`: how to run everything; device-matrix template

**Exit:** `flutter test` and the integration tests pass; coverage target met.

#### P11 · UI polish (Week 16, 14–20 Jan)
- [x] **P11.1** Expressive pass: shapes, type, motion, FAB menu, transitions; dark mode review *(Android's predictive-back transition, instant with Remove animations; New chat stays a sheet, which reads better than a FAB menu with three choices)*
- [x] **P11.2** Empty, loading and error states on every screen (§10.3) *(audited; all screens already had them)*
- [x] **P11.3** Accessibility: TalkBack, contrast, 48 dp targets, 200% text, reduced motion *(automated on 11 screens, light and dark)*
- [x] **P11.4** Adaptive layouts: large phones, foldables, landscape (list and detail side by side at ≥ 840 dp)
- [x] **P11.5** About screen; final Storage and Settings
- [x] **P11.6** Performance pass in profile mode (§13.3) *(frame times during a 200 MB send; cold start; see TESTING.md)*

**Exit:** the UI checklist passes on 2 phones in light and dark themes.

#### P12 · Release build (Week 17, 21–27 Jan)
- [x] **P12.1** Release signing, version `1.0.0+1`, R8 keep rules if the bridge needs them, final icon and splash *(upload key in `~/LinkUpKeys/`, outside the repo; version 1.0.0 keeps the running build number so every APK updates the last; obfuscated with symbols kept; the bridges work under R8 without keep rules; adaptive icon final, Play icon and feature graphic drawn from it)*
- [x] **P12.2** `flutter build apk --release` (plus `--split-per-abi`); install on every testbed phone *(one universal APK for sideloading plus the Play bundle (AAB), which Play splits per phone; per-ABI APKs dropped because their version codes would block later universal updates. Installing on the testbed phones is with the user)*
- [ ] **P12.3** Full real-device matrix (§13.2) on the release APK; fix anything blocking
- [x] **P12.4** `README.md`, `ARCHITECTURE.md`, `PROTOCOL.md`, `TESTING.md` complete (§15.5)
- [x] **P12.5** Tag `v1.0.0-rc1`
- [x] **P12.6** Ready for Google Play at any time (user request, 10 Oct): `docs/PLAY_STORE.md` (decisions, listing text, Data safety and permission answers, checklist), `docs/PRIVACY_POLICY.md`, store graphics and screenshots in `store/`, `tool/build_apk.sh --bundle`. Upload is not planned yet.

**Exit (M6):** the release APK passes the full device matrix.

#### UI preview (done 8 Oct, ahead of P11)
- [x] **U.1** Three-step onboarding: welcome (animated illustration), name, *How do you want to connect?*
- [x] **U.2** Connection method picker: four methods, traits, steps; *Coming soon* for Wi-Fi Direct and Bluetooth
- [x] **U.3** Bottom tabs (Chats, People, Settings); Home with greeting and connection card; *New chat* sheet (one person, everyone, selected people; *Coming soon* until P4/P7)
- [x] **U.4** People Nearby shell; Settings → How you connect
- [x] **U.5** Reduce-motion support fixed (zero-duration page and size animations crashed)

#### P13 · Wi-Fi Direct (after v1.0, about 2–3 weeks)
- [ ] **P13.1** Spike on 2 phones: discover, invite, form a group, open TCP between group owner and client *(built into the app instead of a throwaway spike: Settings → Developer options → Wi-Fi Direct shows each step; to run on the testbed phones, TESTING.md §2b)*
- [x] **P13.2** Permissions flow (`NEARBY_WIFI_DEVICES` / location ≤ 32) shown only when Wi-Fi Direct is chosen *(asked once on choosing it; then an Allow / Turn on Location button on the status card)*
- [x] **P13.3** Run the existing control and data connections over the P2P group; group-owner negotiation; reconnect *(ADR-0023: groups form by themselves through service discovery, lowest ID hosts, joins without dialogs on Android 10+; the group is reported as a `wifiDirect` interface and the LAN stack runs unchanged; not bound to Wi-Fi in this mode)*
- [ ] **P13.4** Device tests (§13.2 rows R1–R5, R12, R15 over Wi-Fi Direct)

#### P14 · Bluetooth (after P13, about 3–4 weeks)
- [ ] **P14.1** Spike: BLE + L2CAP versus classic RFCOMM on the testbed phones (D21)
- [ ] **P14.2** Permissions flow (`BLUETOOTH_*`) shown only when Bluetooth is chosen
- [ ] **P14.3** Bluetooth discovery and stream behind the same packet layer; framing unchanged
- [ ] **P14.4** File limits and warnings for slow links; device tests

#### P15 · Chat features from user testing (requested 11 Oct 2026, about 2 weeks)
Reply (long-press) and per-person delivery already exist; these build on them. Suggested order: quick wins first, voice last.
- [x] **P15.1** *Seen by* count on Everyone messages (1, 2, 3 … 1k), tap for who; uses the existing per-person read status *(eye icon and compact count beside the delivery text; TalkBack reads "Seen by N")*
- [x] **P15.2** WhatsApp-style reply: swipe a message to reply, quoted message in the bubble (tap jumps to it); replies in the Everyone thread too *(swipe right to reply; quotes name the right sender in Everyone; tapping a quote scrolls back and tints the original)*
- [x] **P15.3** Forward any message or file to people or Everyone; files go from the local copy *(Forward sheet: Everyone nearby and/or people; files from a temporary copy of this phone's file)*
- [x] **P15.4** Delete for everyone (sender only): new `MESSAGE_DELETE` packet, ignored by older builds; *This message was deleted* on every phone, files removed *(`MESSAGE_DELETE`, repeated to people who come back for 7 days; schema v4 `deletedAt`)*
- [x] **P15.5** @mentions in Everyone: suggestions of people online, highlighted, and the mentioned person is notified (optional `mentions` field in MESSAGE) *(@ chips of people online; optional `mentions` IDs; "Rahim mentioned you" notification)*
- [x] **P15.6** Camera: take a photo inside the chat and send it (Android camera app; no camera permission needed) *(camera button in the composer; the phone's camera app via a FileProvider path)*
- [x] **P15.7** Voice messages: hold to record (`RECORD_AUDIO`, asked on first use), send as an audio file with its length, play inside the bubble *(tap the mic to record, then Send or Cancel, which also works with TalkBack; AAC 32 kbit/s, up to 10 minutes; optional `voiceMs`; player in the bubble)*

**Schedule note:** P13 and P14 add about 5–7 weeks and don't fit inside the 20-week window. They are planned after v1.0 (Week 21 onward) unless the supervisor agrees to swap them for other work (§16 Q3).

#### Wrap-up (Weeks 18–20, 28 Jan–17 Feb)
- [ ] **W.1** Fixes from the matrix; tag `v1.0.0` (M7)
- [ ] **W.2** Report or thesis: design, implementation, test results (§16 Q1)
- [ ] **W.3** Defense demo script: 3 phones and a router with the internet unplugged (M8)

**Write the report as you go:** Design after P3, Implementation notes after each phase, Testing after P12. Only results and the discussion are left for the last two weeks.

---

## 12. Milestones

| ID | Milestone | Due | Status |
|---|---|---|---|
| M1 | Plan reviewed, decisions recorded, discovery spike done, onboarding works | 21 Oct (end of Week 3) | Code done; supervisor review open |
| M2 | LAN discovery on 2+ phones with the router's internet off | 4 Nov (end of Week 5) | Works on 2 phones; offline-in-20 s and router-reboot checks open |
| M3 | Persistent text chat with offline queue | 25 Nov (end of Week 8) | Done (emulator; chat on 2 phones) |
| M4 | Large-file transfer; mid-term presentation | 16 Dec (Week 11) | Code done; 2 GB soak and slides open |
| M5 | Feature complete: broadcast, background, security | 6 Jan (end of Week 14) | Done 10 Oct (`v0.9.0-beta`); real-phone checks for P7/P8 open |
| M6 | Release candidate: tests, polish, release APK passes the device matrix | 27 Jan (end of Week 17) | `v1.0.0-rc1` built and signed (10 Oct); device matrix on phones open |
| M7 | v1.0.0 released with all four documents | 3 Feb (end of Week 18) | Not started |
| M8 | Report submitted, defense | ~17 Feb (Week 20) | Not started |

Tag the repository at each milestone (`m1` … `m8`).

---

## 13. Testing and verification

### 13.1 Automated tests (spec §33)

Networking tests use **real sockets on loopback**. Fakes are allowed only for time and the platform bridge. Mock networking never counts as done.

| Area | What is tested | How |
|---|---|---|
| Username validation | Length, trimming, whitespace, control characters, Bangla, emoji graphemes | Unit |
| Unique names | Clash detection, case-insensitivity, later-clash tie-break, accepted with no peers | Unit with fake registry and time |
| Discovery | De-duplication across UDP and NSD, IP change, expiry, GOODBYE, ignoring own packets | Unit with fake datagrams + UDP over loopback |
| Protocol serialisation | Round trip for every packet type; golden JSON fixtures; unknown type ignored | Unit |
| Messages | Serialisation; duplicate MESSAGE → one row and a repeated ACK | Unit + loopback |
| File metadata | Offer validation, MIME type, size limits | Unit |
| Checksum | Known vectors; streamed hash equals whole-file hash; re-hash on resume | Unit |
| Transfer state | Every transition: cancel, pause, resume, fail, retry | Unit |
| Database | DAOs, unread and chat-list queries, cascading deletes, migrations | drift in-memory |
| Reconnect | Connection dropped mid-chat and mid-transfer → reconnect and resume | Loopback + `fake_async` |
| Timeout and retry | Handshake timeout, ACK timeout, backoff schedule | `fake_async` |
| Malformed packets | Random bytes, truncated frames, huge lengths, wrong JSON types | Unit / fuzz |
| Path sanitising | `../`, absolute paths, `\`, NUL, reserved characters, long and Unicode names | Unit |
| End to end | 2–3 real `LanEngine`s over 127.0.0.1: chat, file, broadcast | `flutter test` |
| UI | Onboarding, sending a chat message, file card states | Widget + `integration_test` |

### 13.2 Real-device matrix (spec §41)

Run on the release APK with at least 2 phones (3 for R15), with the router's internet unplugged unless a row says otherwise. Record every run in `TESTING.md` with the date, phones, Android versions, router, result and notes.

| ID | Test | Pass when |
|---|---|---|
| R1 | A → B text | Arrives within 1 s; shows ✓✓ |
| R2 | B → A text | Same |
| R3 | A → B image | Preview shows; checksum verified |
| R4 | A → B large file (≥ 1 GB, 2 GB stretch) | Completes; memory flat; UI smooth |
| R5 | B → A large file | Same |
| R6 | Router WAN unplugged, Wi-Fi on | R1–R5 still pass |
| R7 | Mobile data on, Wi-Fi without internet | Traffic stays on Wi-Fi (binding works) |
| R8 | Router reboot | Peers rediscovered within 60 s of Wi-Fi returning, without restarting the app |
| R9 | IP change (rejoin network or change DHCP lease) | Reconnected within 30 s; pending messages delivered |
| R10 | Airplane mode on, then Wi-Fi re-enabled | Everything works |
| R11 | Peer offline → message Pending → peer returns | Delivered automatically |
| R12 | Wi-Fi off in the middle of a transfer | Resumes from the offset when Wi-Fi returns |
| R13 | Screen off, *Stay reachable* on | Message and file received; progress notification shown |
| R14 | Swiped from Recents / force-stopped | Behaviour matches §5.6 |
| R15 | Broadcast to 3 phones (text and file) | All receive it; per-recipient status correct |
| R16 | Two phones choose the same name | The second is refused with the spec message |
| R17 | Router with client isolation (e.g. guest network) | Isolation hint shown; no crash |
| R18 | Local network permission denied (Android 17) | *Local network access is off* status with a Settings link |

### 13.3 Performance targets (spec §13, §36)

| Measure | Target |
|---|---|
| New peer visible | ≤ 10 s (usually ≤ 2 s thanks to DISCOVERY) |
| Peer marked offline | ≤ 20 s; immediate with GOODBYE |
| Text send → Sent | 95th percentile ≤ 500 ms on an idle LAN |
| Memory during a 2 GB transfer | Grows by ≤ 50 MB |
| UI during a transfer | No transfer-related frames over 16 ms in profile mode |
| File throughput | Recorded per phone pair and router (it depends on the Wi-Fi standard, so no fixed target) |
| Cold start to Home | ≤ 2 s on a mid-range phone |
| Battery, *Stay reachable* idle for 1 h | Measured and reported in `TESTING.md` |

### 13.4 Testbed inventory (fill in during Week 2)

| Slot | Model | Android (API) | RAM | Owner / source | Notes |
|---|---|---|---|---|---|
| A | | | | | |
| B | | | | | |
| C | | | | | |
| Dev | | | | | |

| Router | Model | Wi-Fi standard | AP-isolation setting? | Notes |
|---|---|---|---|---|
| R-main | | | | |
| R-alt | | | | |

---

## 14. Risks

| Risk | Likelihood | Impact | Mitigation / fallback |
|---|---|---|---|
| Router blocks device-to-device traffic (AP isolation, guest networks) | Medium | High | Hint in the app (§6.5), README explanation, test R17; suggest another router or a phone hotspot |
| Android routes LAN traffic over mobile data when Wi-Fi has no internet | Medium | High | Process binding (D7), checked in the spike and in R7 |
| Local network permission (Android 17, target 37) denied or mishandled | Medium | High | Explainer screen, `EPERM` detection, *Blocked* state with a Settings link; rules confirmed in P0.3 |
| NSD unreliable (OEM bugs, one resolve at a time, stale entries) | High | Medium | UDP is the main liveness signal; NSD only adds candidates; TCP HELLO confirms |
| Broadcast or mDNS packets dropped (power save, router settings) | Medium | Medium | `MulticastLock`; both mechanisms; regular announcements; keep-alives on live connections |
| Background limits and OEM battery savers stop the app | High | Medium | Foreground service during transfers, opt-in *Stay reachable*; the outbox recovers; documented (§5.6) |
| Large transfers cause jank or memory growth | Medium | High | Worker isolate, streaming, backpressure; 2 GB soak test (P6.12) |
| `file_picker` copies large files into the cache | Certain (confirmed in P0.3) | Medium | Free-space check before sending; the cache copy is moved into `sent/` (no second copy); a native picker stream through the bridge if picking 2 GB files proves too slow |
| Packages fall behind Flutter or Android Gradle Plugin releases | Medium | Medium | Vet and pin in P0.2; the bridge replaces several plugins; no young packages on core paths |
| Flutter lacks Material 3 Expressive components | High | Low | Own expressive tokens (D16) |
| Name clashes when networks merge | Medium | Low | Deterministic tie-break (§6.4) |
| Encryption destabilises transfers | Medium | Medium | Spike with a go/no-go (D17); first item to cut |
| Phone clocks differ and mis-order chats | High | Low | Order by local time; sender time is informational |
| P6 runs over into the holidays | Medium | High | Three weeks allotted, lighter phases after; descoping order below |
| Wi-Fi Direct behaves differently across phone brands (group-owner choice, invitation prompts) | High | Medium | Spike first (P13.1); Wi-Fi network and hotspot remain the main methods |
| Bluetooth too slow or unreliable for files | High | Low | Messages first; warn and cap file size on Bluetooth (D21) |
| P13–P14 push past the 20-week window | High | Medium | Scheduled after v1.0; shown as *Coming soon* until then (§16 Q3) |
| Fewer than 3 phones | Low | Medium | 2 phones cover everything except R15; borrow a third for test days |

### Descoping order (if more than 1 week behind)
1. Encryption (D17) → plaintext on the trusted LAN, documented
2. Resume → a retry starts from zero, and Pause acts as Cancel
3. Read status → stop at Delivered
4. *Stay reachable* → background only during transfers
5. Large-screen layouts → phone layout only
6. Activity screen → transfers list only

**Never cut** (spec §45): discovery without internet, unique names, text chat with persistence and the offline queue, streamed file transfer with checksums, broadcast, a release APK that passes the device matrix, and the four documents.

---

## 15. Working practices

### 15.1 Phase gate (spec §40), at the end of every phase
- [ ] `dart format --set-exit-if-changed .` passes
- [ ] `flutter analyze` reports no issues
- [ ] `flutter test` passes
- [ ] `flutter build apk --release` succeeds (catches R8 and signing problems early)
- [ ] Architecture review: no networking, SQL or file I/O in widgets; dependency rules (§4.1) hold
- [ ] Feature tried on at least 2 physical phones on the test router with the internet unplugged
- [ ] `PROTOCOL.md`, `ARCHITECTURE.md` or an ADR updated if behaviour or the protocol changed
- [ ] Task boxes ticked; Status block updated

**Never leave `main` in a state that doesn't build.**

### 15.2 Definition of done (every task)
- [ ] Tests added and passing
- [ ] Loading, empty and error states handled where the task touches UI
- [ ] Logs the right events, with no message text or file names
- [ ] Accessibility labels on new interactive elements
- [ ] Commit references the task ID

### 15.3 Git conventions
- Branches: `feat/P6.3-data-connection`, `fix/P3.3-reconnect-loop`
- Commits follow Conventional Commits and end with the task ID: `feat(transfer): stream chunks with backpressure [P6.3]`
- Tags: `m1` … `m8` for milestones; `v0.9.0-beta`, `v1.0.0-rc1`, `v1.0.0` for builds
- CI (GitHub Actions, optional): format, analyze, test and `flutter build apk` on every push

### 15.4 Logging (spec §35)
- **Format:** `2026-10-08T20:42:13.512 I [DISCOVERY] Peer found device=3f2a`
- **Levels:** `D`, `I`, `W`, `E` (debug builds log from D, release builds from I)
- **Tags:** `APP`, `DISCOVERY`, `NETWORK`, `MESSAGE`, `FILE`, `DB`, `SERVICE`
- **Where:** a ring buffer of the last 2,000 entries in memory, plus rotating files (2 × 1 MB) in app storage. Viewable in the developer screen; **Export logs** goes through the share sheet.
- **Content:** none by default. Message text and file names never appear; a debug-only switch can include them for troubleshooting.

### 15.5 Documentation
| File | Contents | Started | Final |
|---|---|---|---|
| `PROTOCOL.md` | Framing, envelope, every packet type with a JSON example, message and file flows, limits, versioning | P0 | P12 |
| `ARCHITECTURE.md` | Layers, folders, runtime model, LAN engine, persistence, background model, security model | P1 | P12 |
| `TESTING.md` | Running unit, loopback and integration tests; device matrix and results; per-phone background behaviour | P2 | P12 |
| `README.md` | Overview, architecture, network architecture, discovery, protocol and file-transfer summaries, schema, security model, permissions, how to run, how to build the APK, how to test with two phones, known limitations, router isolation | P1 | P12 |

### 15.6 Weekly routine
- Monday: update the Status block, milestone statuses and risks.
- Send the supervisor an update: done, blockers, next week, any plan changes.
- After every device test session, add the results to `TESTING.md`.

---

## 16. Open questions

**For the supervisor**
1. What evaluation does the report need? Suggested: the device matrix (§13.2) plus the measurements in §13.3.
2. What is the exact report format and submission date within Weeks 19–20?
3. Wi-Fi Direct and Bluetooth (P13–P14) add 5–7 weeks. Build them after v1.0, or swap them for other work inside the window?

**For the product** (planned answer in brackets; change it here if needed)

4. The chat mockup in spec §25 shows a 🎤 button, but voice notes aren't in the feature list. *(Send button only; voice notes are Could and would need `RECORD_AUDIO`.)*
5. ~~Home title~~ **Decided 9 Oct:** the product is called **LinkUp**; it is the launcher name and the Home title. Check the Play Store and trademarks before launch: other apps called LinkUp/Link Up exist.
6. Should *Stay reachable* be on by default? *(Off; offered once after onboarding, because it keeps a notification and the service running.)*
7. Is Bangla needed for v1.0? *(Could; all strings go in ARB files from P1.)*
8. Largest file received automatically? *(4 GiB, adjustable in Settings.)*
9. **Before the first Play Store upload:** choose the final app ID. *(Kept as `com.resqmesh.resqmesh` for now, user's decision on 9 Oct: no store upload yet. It can't change after the first upload; changing it before then means testers reinstall once.)*

---

## Changelog

| Version | Date | Change |
|---|---|---|
| 1.0 | 8 Oct 2026 | Baseline plan from the build specification (`ResQMesh_prompt.txt`). |
| 1.1 | 8 Oct 2026 | P0 results: Material now comes from Flutter's official `material_ui` package (D16); `targetSdk` stays at 36 until Flutter stable targets 37, so `ACCESS_LOCAL_NETWORK` isn't requested yet (D15); `sqlite3_flutter_libs` dropped (D3); `open_filex` rejected, the bridge opens and shares files (D8); `file_picker` cache copy confirmed; FILE_OFFER field renamed `chatMessageId`. Logging levels and tags aligned with the code. P1 done a week early; no dates changed. |
| 1.2 | 8 Oct 2026 | Connection methods back in scope at the user's request: users choose Wi-Fi network, phone hotspot, Wi-Fi Direct or Bluetooth (D20–D21, §2.1); Google Nearby stays out. New phases P13 (Wi-Fi Direct) and P14 (Bluetooth) after v1.0; permissions, risks and §16 Q3 added. UI preview done ahead of P11 (U.1–U.5). Example name in the spec changed from Tanim to Yusuf. |
| 1.3 | 8 Oct 2026 | P2 done: Kotlin bridge (Wi-Fi binding, hotspot detection, multicast lock), protocol codec and framing, UDP + NSD discovery engine, network-wide unique names, live status, People Nearby, developer screen; 112 tests; `tool/lan_peer_sim.py` for one-phone testing; `TESTING.md` started. `POST_NOTIFICATIONS` request moved to P4. |
| 1.4 | 9 Oct 2026 | Product renamed **LinkUp** (user's choice; non-technical, single word). Name kept in one constant (`Brand.name`); internal identifiers unchanged. APKs now `LINKUP_version-N.apk`. |
| 1.5 | 9 Oct 2026 | P3 done: control connections (HELLO handshake, PING/PONG, idle timeout, framing limits), connection manager (lower ID dials, grace period, duplicate tie-break, backoff, network reset, port fallback), REGISTER over TCP, "Online" now means connected, new "Found X, but couldn't connect" state. Simulator speaks TCP. |
| 1.6 | 9 Oct 2026 | P4 done: direct text messages with ACK, delivered and read receipts; resend with the same ID after 10 s, failed after 5 tries, tap to retry; duplicates stored once; outbox sent when the person connects; chat screen (day separators, ticks, reply, copy, delete, retry); unread badges; notifications through the Kotlin bridge, with `POST_NOTIFICATIONS` asked on the first chat. Messages are in memory until P5. 169 tests. Simulator answers messages (`--echo`). |
| 1.7 | 9 Oct 2026 | P5 done: SQLite through drift (schema v1, `messages` only; D22 and ADR-0020); chats, unread counts and the outbox survive restarts; interrupted sends wait again at start; delivery and read receipts queue until the sender reconnects; each connection gets a full 5 attempts; Settings → Storage with *Clear chat history*; migration test scaffold. 189 tests. The release APK grows by about 7 MB (SQLite for three CPU types; a Play Store bundle splits it). The simulator keeps one device ID per name. |
| 1.8 | 9 Oct 2026 | P6 done (code): file transfer in a worker isolate on its own port (D23, ADR-0021; `filePort` in HELLO), FILE_* packets, schema v2 with the `files` table, resume by offset, 3 automatic resumes then Retry, one retry after a checksum mismatch, duplicates by file ID and by content, at most 3 uploads at a time, 4 GiB and free-space checks. Attach sheet, file cards, File Preview (Open, Share, Save to Downloads), Transfer Details, Storage v1 with all four actions (Clear all local data restarts at onboarding). Kotlin `FileBridge` (FileProvider with hard links, MediaStore, thumbnails, free space); `REQUEST_INSTALL_PACKAGES` so received APKs open in the system installer. Discovery now reopens its UDP socket after Android cuts a backgrounded app's network. Simulator sends and receives files. 261 tests. |
| 1.9 | 10 Oct 2026 | P7 done (code): Everyone thread (one message to the people online at that moment, `message_recipients` with per-person status, "Delivered to 2 of 3", per-person retry and receipts, sender names, notifications "Rahim · Everyone"); selected people as one direct message each, queued for anyone offline; files fanned out with one copy and one hash. Schema v3 (`audience`, `senderId`, `message_recipients`). New chat options and People Nearby → Select people. 3-phone loopback test with real sockets. Milestone table updated. 284 tests. |
| 2.0 | 10 Oct 2026 | P8 done (code): the `Application` owns a cached FlutterEngine and the bridges (screen-independent); `LanForegroundService` (`connectedDevice`) runs while files move ("Receiving video.mp4 — 62%", updated at most once a second) or with *Stay reachable* on, with Wi-Fi and partial wake locks during transfers only; *Stay reachable* in Settings, offered once on Home; battery settings link; notification taps carry an app route (chat, transfer details, Activity); Activity screen; HELLO every 15 s in the background. Emulator: 1 GB received with the screen off, Doze, swipe-away. 292 tests. |
| 2.1 | 10 Oct 2026 | P9 done: inputs reviewed and documented (Security model); fuzz tests for codecs, frames and live connections; limits on discovery answers, half-open and per-address connections, and packet floods; logs reviewed; encryption spike (`tool/tls_spike.dart`) and decision ADR-0022 (plaintext v1.0, user's choice); Settings → Privacy; feature freeze and `v0.9.0-beta`. 302 tests. |
| 2.2 | 10 Oct 2026 | P10 done: coverage core 82.7% and data 91.1%; on-device integration test (onboarding, text both ways, 5 MB file verified against a peer inside the test); redial backoff test; `TESTING.md` with run commands and the full device-matrix template. |
| 2.3 | 10 Oct 2026 | P11 done (code): accessibility audit as tests (touch targets, labels, contrast in light and dark, 200% text) with one overflow fixed; navigation rail from 600 dp and chat list beside the chat from 840 dp; About screen (version, how it works, privacy, licences; 7 taps on the version unlock developer options); transitions instant with Remove animations; profile-mode frame times during a 200 MB send and cold start recorded. Exit check (UI checklist on 2 phones, light and dark) is with the user. |
| 2.4 | 10 Oct 2026 | P12 done except the phone matrix: release signing with an upload key outside the repository; obfuscated builds with symbols; Play bundle (`--bundle`); `v1.0.0-rc1`. The release check found and fixed a dropped-message bug (a packet in the same burst as the HELLO), and a leftover *File sharing is coming* placeholder in People (now *Send file*). Play Store readiness added at the user's request (P12.6); upload not planned yet. |
| 2.5 | 11 Oct 2026 | P13 code done (ADR-0023): Wi-Fi Direct is selectable; phones form a group by themselves (service discovery, lowest ID hosts, joins without dialogs on Android 10+) and the existing LAN stack runs over it; permission flow and status card states; developer view. Phone tests (P13.1, P13.4) are with the user. User testing passed P6–P8 on phones; their feature requests added as P15. |
| 2.6 | 11 Oct 2026 | P15 done (code): seen-by count, swipe replies (also in Everyone), forward, delete for everyone (`MESSAGE_DELETE`), @mentions, camera photos, voice messages. Schema v4 (`deletedAt`, `mentions`, `voiceMs`) with a migration test, and checked on the emulator by updating build 19 to 20 with a chat kept. New protocol fields are optional, so older builds keep working. |
