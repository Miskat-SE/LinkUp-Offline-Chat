# ResQMesh Architecture

Describes the code as it is now (end of phase P2). The target design is in [`PROJECT_PLAN.md`](PROJECT_PLAN.md) §4; sections below grow as each phase lands.

## Layers

```
PRESENTATION   Screens and widgets · Riverpod notifiers · go_router
DOMAIN         Pure Dart rules and models (no Flutter imports)
DATA           Repositories over storage
CORE           Bootstrap · identity · key-value storage · logging
```

Still to come: TCP connections (P3), the drift database (P5), the transfer isolate (P6) and the foreground service (P8).

**Rules** (checked by `test/architecture_test.dart`):
- Material widgets come from `package:material_ui` (Flutter's decoupled Material library), never `package:flutter/material.dart` (ADR-0016).
- `lib/core` never imports `lib/app` or `lib/features`.
- `domain/` folders import no Flutter, Material or Riverpod code.
- Presentation code and shared widgets never import `dart:io`.
- A feature uses another feature only through its `domain/` folder.

## Folders

```
lib/
├── main.dart                     runApp(ProviderScope(ResQMeshApp))
├── app/
│   ├── app.dart                  MaterialApp.router, dynamic colour, theme mode
│   ├── app_shell.dart            bottom tabs: Chats, People, Settings
│   ├── router.dart               routes, LaunchState, redirect rules
│   └── theme/                    AppTheme (Material 3 + expressive tokens), tokens.dart
├── core/
│   ├── bootstrap/core_services.dart   start-up: storage, log file, device ID
│   ├── connection/               ConnectionMethod (Wi-Fi, hotspot, Wi-Fi Direct, Bluetooth), chosen-method provider
│   ├── identity/                 Username rules, LocalIdentity, IdentityRepository, providers
│   ├── logging/                  AppLogger, FileLogSink, DebugPrintSink
│   └── storage/key_value_store.dart   KeyValueStore over SharedPreferencesWithCache
├── features/
│   ├── onboarding/presentation/  Splash; onboarding (welcome → name → how to connect)
│   ├── chat/presentation/        Home (greeting, connection card, chat list shell), New chat sheet
│   ├── users/presentation/       People Nearby shell
│   └── settings/presentation/    Settings, Change name, How you connect, theme mode
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

## Testing

| Area | File |
|---|---|
| Username rules (graphemes, Bangla, control characters, case) | `test/core/identity/username_test.dart` |
| Device ID and name persistence, claim time | `test/core/identity/identity_repository_test.dart` |
| Logger levels, ring buffer, file rotation | `test/core/logging/app_logger_test.dart` |
| Router redirects | `test/app/router_test.dart` |
| Onboarding, relaunch, Change name, theme (whole app) | `test/features/onboarding/onboarding_flow_test.dart` |
| Layer rules | `test/architecture_test.dart` |

Tests use `MemoryKeyValueStore` in place of SharedPreferences; everything else is the real code.
