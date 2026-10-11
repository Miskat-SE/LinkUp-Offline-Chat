# ResQMesh Architecture

Describes the code as it is now (end of phase P3). The target design is in [`PROJECT_PLAN.md`](PROJECT_PLAN.md) §4; sections below grow as each phase lands.

## Layers

```
PRESENTATION   Screens and widgets · Riverpod notifiers · go_router
DOMAIN         Pure Dart rules and models (no Flutter imports)
DATA           Repositories over storage
CORE           Bootstrap · identity · key-value storage · logging
```

Still to come: messages (P4), the drift database (P5), the transfer isolate (P6) and the foreground service (P8).

**Rules** (checked by `test/architecture_test.dart`):
- Material widgets come from `package:material_ui` (Flutter's decoupled Material library), never `package:flutter/material.dart` (ADR-0016).
- `lib/core` never imports `lib/app` or `lib/features`.
- `domain/` folders import no Flutter, Material or Riverpod code.
- Presentation code and shared widgets never import `dart:io`.
- A feature uses another feature only through its `domain/` folder.

## Folders

```
lib/
├── main.dart                     runApp(RestartableApp(ProviderScope(ResQMeshApp)))
├── app/
│   ├── app.dart                  MaterialApp.router, dynamic colour, theme mode
│   ├── app_shell.dart            bottom tabs: Chats, People, Settings
│   ├── router.dart               routes, LaunchState, redirect rules
│   ├── restartable_app.dart      starts the app over after Clear all local data
│   └── theme/                    AppTheme (Material 3 + expressive tokens), tokens.dart
├── core/
│   ├── bootstrap/core_services.dart   start-up: storage, log file, device ID
│   ├── connection/               ConnectionMethod (Wi-Fi, hotspot, Wi-Fi Direct, Bluetooth), chosen-method provider
│   ├── identity/                 Username rules, LocalIdentity, IdentityRepository, providers
│   ├── logging/                  AppLogger, FileLogSink, DebugPrintSink
│   ├── platform/                 pigeon bridge: notifications, FileActions (open, share, save, thumbnails, free space)
│   └── storage/                  KeyValueStore; AppDatabase (drift); StorageManager; FileStore; FileNameSanitizer
├── features/
│   ├── onboarding/presentation/  Splash; onboarding (welcome → name → how to connect)
│   ├── chat/domain/              ChatMessage, MessageStatus, ConversationSummary, MessageRepository
│   ├── chat/data/                DriftMessageRepository, MessagingService, chat providers
│   ├── chat/presentation/        Home (chat list), Chat screen, message bubbles, New chat sheet
│   ├── file_transfer/domain/     FileTransfer, TransferStatus, FileKind, TransferProgress, repository
│   ├── file_transfer/data/       TransferService; engine/ (TransferEngine, DataConnection, worker isolate);
│   │                             DriftFileTransferRepository; file picker; stored images and thumbnails
│   ├── file_transfer/presentation/  file card, Send files sheet, File Preview, Transfer Details
│   ├── users/presentation/       People Nearby shell
│   └── settings/presentation/    Settings, Change name, How you connect, Storage, theme mode
└── shared/widgets/               AppMark, UserAvatar, EmptyState, NameForm, MeshIllustration,
                                  ConnectionMethodPicker/Info, ConnectionStatusCard
```

## Start-up

1. `main()` runs the app immediately; the router opens on `/splash`.
2. `coreServicesProvider` (a `FutureProvider`) opens `SharedPreferencesWithCache`, finds the app-support directory, attaches the log file sink, and creates the device ID on first launch.
3. `launchStateProvider` turns that into `loading`, `failed`, `needsOnboarding` (no name or no connection method yet) or `ready`. The router's `redirect` (`redirectFor`, a pure function) sends the user to Splash, onboarding, or Home. There is no artificial delay.
4. If start-up fails, Splash shows **Try again**, which re-runs `coreServicesProvider`.

Providers that need storage (`keyValueStoreProvider`, `identityProvider`) read the finished `coreServicesProvider`; the redirect guarantees no such screen is shown before then.

## Identity

- `IdentityRepository` stores a UUID v4 device ID (created once) plus the username and the time it was claimed (`identity.*` keys).
- `Username` holds the rules shared by onboarding, Change name and, later, the protocol:
  - Trim the name and collapse whitespace.
  - Count length in graphemes, so emoji and Bangla conjuncts count as one; allow 2–30.
  - Reject control characters and line breaks.
  - Compare names without case.
- The claim time changes only when the name really changes, because it decides name clashes later (PROTOCOL.md §4.2).

## Logging

`AppLogger` writes structured lines, for example `2026-10-08T20:42:13.512 I [APP] Name chosen device=3f2a`. Levels are D/I/W/E; tags are APP, DISCOVERY, NETWORK, MESSAGE, FILE, DB and SERVICE.

| Sink | When | Details |
|---|---|---|
| In-memory ring buffer | Always | Last 2,000 entries, for the future developer screen |
| `FileLogSink` | Once storage is ready | `<app support>/logs/resqmesh.log`, batched writes, rotated to one `.1.log` at 1 MB |
| `DebugPrintSink` | Debug builds only | Console |

Callers pass IDs and sizes, never message text or file names (spec §35). Debug builds log from level D; release builds from level I.

## Theme

`AppTheme` builds light and dark `ThemeData` from a seed colour, or from the wallpaper colours on Android 12+ through `dynamic_color`. It uses the expressive variant for icon buttons, stadium buttons, 28 dp card corners, heavier headline and title weights, and emphasised easing (`tokens.dart`). Fonts are the platform default; nothing is downloaded.

Page transitions are Android's own (with predictive back), and become instant when *Remove animations* is on, like every other animation (`AppMotion.of`).

**Layouts (P11.4).** Below 600 dp wide: a bottom navigation bar. From 600 dp (landscape phones, foldables): a navigation rail. From 840 dp (Material's *expanded* window class, `twoPaneWidth`): the chat list and the open chat side by side; the open chat is `selectedChatProvider`, and narrower windows push the chat as a full screen instead.

## LAN discovery (P2)

```
Kotlin LanBridge ──pigeon──▶ PlatformNetworkMonitor ──▶ DiscoveryEngine ◀── NsdServiceDiscovery (bonsoir)
 Wi-Fi callback (no internet needed)    NetworkSnapshot          │  UDP 28760 (RawDatagramSocket)
 bindProcessToNetwork(Wi-Fi)                                     ├─ PeerRegistry (merge by device ID, 20 s expiry)
 own-hotspot interfaces (polled 5 s)                             ├─ name checks and clash detection
 MulticastLock                                                   └─▶ DiscoverySnapshot ──▶ Riverpod ──▶ UI
```

- **Bridge** (`android/.../bridge/LanBridge.kt`, typed by `pigeons/platform_api.dart`). It watches Wi-Fi with the internet capability removed from the request, so a router without internet still counts. It binds the whole process to that Wi-Fi network, which keeps dart:io sockets off mobile data. It also polls the interface list for this phone's own hotspot, holds the multicast lock, and reports the app version.
- **Protocol** (`lib/core/network/protocol/`). Sealed packet classes; `PacketCodec` validates every field and returns a `DecodeResult` instead of throwing; `DatagramCodec` adds the `RQM1` magic; `FrameDecoder` is ready for TCP in P3.
- **Engine** (`lib/core/network/discovery/discovery_engine.dart`):
  - On start and on every network change, it rebinds UDP, sends DISCOVERY and announces HELLO every 5 s ± 1 s.
  - It answers DISCOVERY after a random 0–300 ms, and NAME_CHECK if it holds that name.
  - NSD results are only hints: the engine asks that address directly over UDP.
  - A phone without a chosen connection method listens but does not announce, as during onboarding.
  - Network changes run one at a time (`_serial`).
- **State for the UI.** `discoveryProvider` streams a `DiscoverySnapshot`: status (`noNetwork`, `searching`, `connected`, `blocked`), network, peers, isolation hint, name clash, counters.
- **Swappable parts.** `NetworkMonitor`, `DatagramTransport` and `ServiceDiscovery` are interfaces, so tests run the real engine on an in-memory LAN.

## Connections (P3)

```
DiscoveryEngine ──online peers──▶ ConnectionManager (PeerLinks) ──▶ LinksSnapshot ─┐
      ▲  setTcpPort / applyRename        │  ServerSocket :28761 (or ephemeral)     ├─▶ NearbySnapshot ──▶ UI
      └──────── RegisterHandler ◀────────┤  PeerConnection per device             │   (Online = connected)
                                         └─ packets (P4 uses these)  DiscoverySnapshot ┘
```

- **`PeerConnection`** (`lib/core/network/connection/peer_connection.dart`) is one TCP control connection:
  - Both sides send HELLO first, within 5 s. Anything else first, our own ID, an unexpected device ID or an incompatible protocol closes it.
  - After the handshake, every packet's sender must match the HELLO.
  - Packets are buffered until the connection manager listens, so a message sent in the same burst as the HELLO (an outbox flushed on connect) is not lost.
  - PING every 15 s; 45 s of silence closes it.
  - 3 malformed frames in a row, a bad frame kind or an oversized length close it at once.
- **`ConnectionManager`**:
  - Listens on 28761, or an ephemeral port if that is taken, and announces the real port.
  - The lower device ID dials straight away. The higher one dials after a 3 s grace period, for when only one side discovered the other.
  - If both connections still happen, it keeps the one opened by the lower ID.
  - Lost connections are redialled with backoff (1 s up to 30 s). A device that fails twice is marked unreachable.
  - On any network change it drops everything and listens again.
- **`RegisterHandler`** sends REGISTER to every connection when the name changes. It applies renames from others, and answers `nameTaken` if this device holds the name under the clash rule.
- **`NearbySnapshot`** combines discovery and connections. *Online* means a live connection. Other people show as *Connecting…*, *Can't connect*, or *Last seen*. A device that connected to us but was never discovered still appears.
- **`PeerLinks`** is an interface: widget tests use a stand-in, while `ConnectionManager` is tested on real loopback sockets.

## Messaging (P4)

```
ChatScreen ─sendText─▶ MessagingService ─MESSAGE─▶ PeerLinks ──▶ other phone
     ▲                   │  ▲                                        │
     │ watchConversation │  └──── ACK · DELIVERED · READ ◀───────────┘
     └──── MessageRepository ── SQLite (drift), the single source of truth
```

- **`MessagingService`** (`lib/features/chat/data/messaging_service.dart`) owns the status machine:
  - Every message is stored first as *pending*, then sent if the person is connected (*sending*).
  - ACK → *sent*, DELIVERED → *delivered*, READ → *read*. Status never moves backwards, so late receipts are harmless.
  - No ACK within 10 s: resend with the same message ID. After 5 attempts: *failed*, and the user can tap to retry.
  - Losing the connection puts *sending* messages back to *pending* with their attempts reset, so every connection gets a full 5 tries. When a person connects, their pending messages go out in the order they were written, followed by any receipts still owed to them.
  - Incoming messages must be addressed to this device. Duplicates are stored once and answered with ACK and DELIVERED again (and READ if already read), so a sender whose receipts were lost catches up.
  - Receipts only count when they come from the message's recipient.
- **`MessageRepository`** is an interface, implemented by `DriftMessageRepository`.
- **Outbox (P5).** At start, messages left *sending* by a killed app go back to *pending*, then anyone already connected is served. A network change drops every connection and redials, so it triggers the same path. Each incoming message records the last receipt sent back (`receiptSent`); DELIVERED and READ that couldn't be sent go out when the sender reconnects.

- **Notifications** go through `NotificationBridge.kt` (channel *Messages*, one notification per chat). `messageAlertsProvider` skips the chat that is open while the app is in the foreground. Tapping a notification opens that chat, whether the app was running or not. `POST_NOTIFICATIONS` is asked on the first chat, after an explainer sheet.

## Security model (P9)

**Trust model.** LinkUp is for a local network you trust. There are no accounts and no servers. Anyone on the same Wi-Fi running LinkUp (or a modified copy) can see you, message you and send you files. **v1.0 does not encrypt traffic** (ADR-0022): someone on the same Wi-Fi with capture tools can read messages and files, and a device can claim another device's ID. Files and chats are stored only in the app's private storage.

**Every input from the network, and its checks** (P9.1):

| Input | Checks |
|---|---|
| UDP datagram (discovery) | ≤ 1,400 bytes; `RQM1` magic; strict JSON decode (never throws); every field typed and bounded; own packets ignored; DISCOVERY and NAME_CHECK answered at most 10 times per 10 s per address (no amplification of spoofed requests) |
| TCP connection (control) | At most 8 still in the handshake and 20 new per minute per address; HELLO within 5 s or closed; the sender ID is bound to the connection; 32 connections at most |
| TCP frame | Kind and length checked before buffering (control ≤ 64 KiB, chunk ≤ 256 KiB); 3 malformed frames in a row close the connection; file chunks refused on control connections |
| Packets on a connection | More than a burst of 2,000 or 200 a second on average closes the connection; idle for 45 s closes it |
| MESSAGE | Addressed to this device; text ≤ 16 KiB; duplicates stored once; file IDs that belong to something else are refused; names sanitised for display |
| Receipts | Applied only to messages sent to the device the receipt came from; never move a status back |
| File data connection | At most 8 in handshake/offer and 30 new per minute per address; HELLO within 5 s, offer within 10 s; the offer must match a file announced by the same device (ID, size, SHA-256); size ≤ 4 GiB and free space − 200 MB; bytes beyond the offered size refused; SHA-256 verified before the file is kept; written under our own file ID (no path from the network); idle 2 min closes it |
| File names | Last path segment only, control and direction-override characters removed, reserved names fixed, ≤ 255 UTF-8 bytes; used only for display, Open, Share and Save |
| Opening files | Only when the user taps; APKs go to Android's installer, which asks first |

**Logs.** At the default level, logs contain no message text and no file names: only short device IDs, LAN addresses, counts and error types (P9.4).

**Fuzzing** (P9.2). Random, truncated, bit-flipped and wrongly typed input goes into the packet codec, the datagram codec and the frame decoder, and random bytes go into live control and file connections. The app never crashes, refuses the input, and keeps working (`test/security/`, connection and engine tests).

## Chat features (P15)

- **Seen by:** `DeliverySummary.seen` counts recipients at *read*; the bubble shows it with an eye icon (`compactCount`: 1k, 1.2M).
- **Replies:** `_SwipeToReply` around each bubble; Everyone messages carry `replyToId` too. A quote's tap scrolls the list (building it as it goes) to the original and tints it.
- **Forward:** `MessagingService.forward` sends text again, or a file from `TransferService.copyForSending` (a temporary copy in `forward/`, moved into `sent/` by sending, then cleaned up).
- **Delete for everyone:** `messages.deletedAt`; the outbox skips deleted messages; `MESSAGE_DELETE` goes to everyone who got it and is repeated on reconnect for 7 days; receivers apply it only from the author and `discard` the file.
- **@mentions:** `mentions.dart` finds the @word at the cursor and splits text for highlighting; IDs travel in `MESSAGE.mentions` and are stored comma-separated.
- **Camera and voice:** `FileBridge.takePhoto` (camera app, no permission) and `VoiceBridge` (MediaRecorder AAC 32 kbit/s; MediaPlayer with progress every 200 ms) behind `FilePickerService.takePhoto` and `Voice`. A voice message is a file message with `voiceMs`.

## Wi-Fi Direct (P13)

ADR-0023. `WifiDirectController` (`lib/core/connection/`) runs only while Wi-Fi Direct is the chosen method; `wifiDirectControllerProvider` starts and stops it, and turns off the Wi-Fi binding (`NetworkMonitor.setBindToWifi`).

- **Finding phones:** `WifiDirectBridge.kt` advertises a `_linkup._tcp` Wi-Fi Direct service (device ID, name, and the short IDs of the phones it has seen) and repeats service discovery every 10 s while it has no group, or hosts one nobody joined.
- **Deciding**, every 3 s, with phones seen in the last 2 minutes: only *mutual* phones (each has seen the other) count. The lowest mutual ID hosts; the others join it. A group owner can't be found by service discovery, so joining uses `groupCredentials(hostId)` (network name and passphrase worked out from the host's ID) and needs no discovery. A join that hasn't formed in 20 s is retried; a lonely host gives way to a lower mutual phone and stops after 5 minutes alone. Android 10+ only.
- **After that, nothing is special:** `LanBridge` reports the `p2p-…` interface as `wifiDirect`, and discovery, connections and files use it like any LAN.
- **States for the card:** unsupported, Wi-Fi off, permission needed, Location off (Android 8–12), searching, connecting, hosting, joined.

## Background (P8)

```
ResQMeshApp (Application) ── cached FlutterEngine ── Dart: discovery, messages, transfers
   └ bridges: LanBridge · NotificationBridge · FileBridge · BackgroundBridge
MainActivity ── attaches to the cached engine; doesn't destroy it
BackgroundCoordinator (Dart) ── BackgroundState ──▶ LanForegroundService (connectedDevice)
                                                     ├ while files move: progress notification + Wi-Fi/wake locks
                                                     └ Stay reachable, idle: quiet "reachable" notification
```

- The engine and bridges belong to the process, not the screen: closing or swiping away the screen leaves the Dart code running if the service runs.
- `BackgroundCoordinator` (app layer) listens to `TransferService.changes` and sends the service at most one update a second: one file ("Receiving video.mp4 — 62%", opens its details) or several ("Sending 2 files · receiving 1", opens Activity). With nothing moving and *Stay reachable* off, the service stops.
- Android 12+ only allows starting the service while the app is visible; it starts when a transfer begins (the app is open then) or when *Stay reachable* is switched on.
- Notification taps carry an app route. `NotificationBridge` keeps it until Dart takes it (`takeOpenedRoute`), so a tap is never lost or handled twice even though the Dart code starts before the screen.
- Discovery sends HELLO every 15 s while the app is in the background (§6.2).

## Everyone and selected people (P7)

- **Everyone:** `MessagingService.sendToEveryone` takes the people connected at that moment, stores one message (conversation `everyone`) plus one `message_recipients` row per person, and sends each their own MESSAGE (same ID). Each recipient has its own retries (10 s, 5 tries), receipts and outbox entry, exactly like a direct message. The bubble shows a `DeliverySummary` ("Delivered to 2 of 3"); tapping it lists each person.
- **Receiving:** a `broadcast` MESSAGE is stored in the Everyone thread with `senderId`; READ receipts from that thread go to each message's sender.
- **Selected people:** `sendToPeople` sends one direct message per person, so each appears in that person's chat and waits for them if they are offline.
- **Files:** the first copy is moved and hashed; the others are `TransferService.shareOutgoing` rows on the same stored copy. When the hash is done, every sharing transfer becomes ready. The usual limit of 3 uploads at a time applies.

## Storage (P5)

```
lib/core/storage/
├── app_database.dart        AppDatabase (drift), Messages table, UtcMicros
├── database_providers.dart  appDatabaseProvider, storageManagerProvider, messageCountProvider
└── storage_manager.dart     message count, Clear chat history (Storage screen)
lib/features/chat/data/drift_message_repository.dart   chat queries and text-code mapping
```

- One SQLite file, `resqmesh.sqlite`, in app-internal storage (`getApplicationSupportDirectory`). `drift_flutter` runs queries on a background isolate and opens the file on first use, so start-up doesn't wait for it.
- Screens watch queries: the chat list is one query (latest message and unread count per chat), and a chat is its messages in local-time order, with the row ID breaking ties.
- Stored values are fixed text codes mapped by the repository, never Dart enum names (ADR-0020). Times are UTC microseconds.
- **Schema changes:** bump `schemaVersion`, run `dart run drift_dev make-migrations` (it writes `drift_schemas/` and the test helpers), write the step in `AppDatabase.migration`, and add a test in `test/drift/app_database/migration_test.dart`.
- The Storage screen lives in Settings. It shows messages, received files, copies of sent files, unfinished downloads and thumbnails, and offers four actions, each confirmed first: *Clear cached files* and *Delete received files* (through `TransferService`, which keeps anything a running transfer needs), *Clear chat history*, and *Clear all local data* (database, files and identity, then `RestartableApp` starts over at onboarding).
- Schema v2 (P6) added the `files` table and `kind`/`fileId` on messages.

## File transfer (P6)

```
Main isolate                                          Transfer worker isolate (ADR-0010, ADR-0021)
MessagingService ─ file MESSAGE ─▶ control connection   TransferEngine
      │  prepare / registerIncoming / accepted           ├ ServerSocket :28762 (filePort in HELLO)
      ▼                                                  ├ DataConnection per file: HELLO, FILE_*, chunks
TransferService ── upload · answer · stop ─────────────▶ ├ read 64 KiB at a time, flush every 1 MiB
  state machine, decisions, files table ◀── events ───── ├ write .part, SHA-256 as bytes arrive, fsync, rename
  progress (≤10/s), retries, ≤3 uploads                  └ hashFile for preparing
```

- **Sending:** the picked cache copy is moved into `files/sent/<fileId>` (no second copy), recorded as *Preparing* and hashed in the worker. Then its file MESSAGE goes out like a text message. Any receipt for that message (ACK, DELIVERED or READ) makes the file *Queued*. When the person is connected and announced a `filePort`, it is sent; at most 3 files at a time.
- **Receiving:** a file MESSAGE records the file as *Offered* before it is ACKed. The worker asks `TransferService` about each FILE_OFFER:
  - It is refused as `invalid` unless it matches what was announced by the same sender.
  - It is refused as `tooLarge` over 4 GiB, or `noSpace` if it would leave less than 200 MB free.
  - It is answered with FILE_COMPLETE at once if this file, or the same content from the same person, is already here (a duplicate reuses the stored copy).
  - Otherwise it is accepted into `partial/<fileId>.part`, continuing from the partial file's size.
- **When things go wrong:** a dropped connection resumes by itself 3 times (2, 4, 8 s), then *Failed* with **Retry**; reconnecting gives a fresh set of tries. A checksum mismatch deletes the partial file and retries once from zero. Pause (sender) keeps the partial file; Cancel (either side) deletes it. After a restart, sends wait to be scheduled again, receives wait for the sender, and unfinished hashing starts over.
- **UI:** each file message is a card with preview (images, video thumbnails), size, type, live status (`%`, speed averaged over 2 s, time left) and one action. Tapping opens File Preview (Open, Share, Save to Downloads) or Transfer Details.
- **Getting files out:** `FileBridge.kt` gives other apps a hard link named like the file under `files/shared/` through a FileProvider (no copy), saves to Downloads through MediaStore (Android 10+) or with the storage permission (8–9), and makes video thumbnails with `ThumbnailUtils`. Received APKs open only in Android's installer, when the user taps them.
- **Discovery after a network cut:** Android stops network access for a backgrounded app; the discovery socket is reopened 2 s after it fails, so the app finds people again by itself.

## Testing

| Area | File |
|---|---|
| Username rules (graphemes, Bangla, control characters, case) | `test/core/identity/username_test.dart` |
| Device ID and name persistence, claim time | `test/core/identity/identity_repository_test.dart` |
| Logger levels, ring buffer, file rotation | `test/core/logging/app_logger_test.dart` |
| Router redirects | `test/app/router_test.dart` |
| Onboarding, relaunch, Change name, theme (whole app) | `test/features/onboarding/onboarding_flow_test.dart` |
| Layer rules | `test/architecture_test.dart` |
| Transfer engine on loopback (200 MB, cancel, resume, corruption, memory) | `test/features/file_transfer/transfer_engine_test.dart` |
| Transfer state machine and decisions | `test/features/file_transfer/transfer_service_test.dart` |
| File screens (whole app) | `test/features/file_transfer/file_ui_test.dart` |
| File messages between two phones | `test/features/chat/file_messages_test.dart` |
| Background service wording, throttling, start/stop | `test/app/background_coordinator_test.dart` |
| Stay reachable, battery link, Activity, notification routes | `test/features/settings/background_ui_test.dart` |
| Everyone and selected people (3 phones) | `test/features/chat/broadcast_test.dart`, `broadcast_loopback_test.dart`, `broadcast_ui_test.dart` |
| File names, storage paths, SHA-256 vectors | `test/core/storage/file_name_sanitizer_test.dart` |
| Schema snapshots and migrations | `test/drift/app_database/migration_test.dart` |

Tests use `MemoryKeyValueStore` in place of SharedPreferences and the real database schema on in-memory SQLite; everything else is the real code.
