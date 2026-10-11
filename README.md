# LinkUp

*Project and research name: ResQMesh.*

Offline messaging and file sharing for Android phones on the same Wi-Fi network. No internet, no cloud, no accounts: phones find each other on the local network and talk directly.

> **Status: v1.0.0-rc1, release candidate.** Phones on the same Wi-Fi or hotspot find each other automatically, with no internet, and chat one to one with sent, delivered and read ticks, or message *Everyone* nearby with "Delivered to 2 of 3". They share files of any type and size up to 4 GB (photos, videos, documents, apps) with pause, resume and a SHA-256 check. Transfers keep going with the screen off, and *Stay reachable* keeps LinkUp reachable while it is closed. Chats and files stay on the phone; anything sent to someone offline goes when they come back. Names are unique on the network. Light and dark themes, large text and TalkBack are supported, and wide screens show the chat beside the list. See [`PROJECT_PLAN.md`](PROJECT_PLAN.md) for the schedule and [`TESTING.md`](TESTING.md) for testing.

## Documents

| File | What it covers |
|---|---|
| [`PROJECT_PLAN.md`](PROJECT_PLAN.md) | Scope, decisions, schedule, backlog, risks |
| [`docs/SPEC.md`](docs/SPEC.md) | The build specification the plan cites as *spec §n* |
| [`PROTOCOL.md`](PROTOCOL.md) | LAN protocol v1: framing, packet types, file transfer |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | Code layout, layers, start-up, logging |
| [`TESTING.md`](TESTING.md) | Automated tests, the simulated peer, device test results |
| [`docs/adr/`](docs/adr/README.md) | One record per technical decision |
| [`docs/PLAY_STORE.md`](docs/PLAY_STORE.md) | Publishing on Google Play: decisions, listing text, policy answers, checklist |
| [`docs/PRIVACY_POLICY.md`](docs/PRIVACY_POLICY.md) | The app's privacy policy (to publish at a public URL) |

## Requirements

- Flutter 3.47.6 stable (Dart 3.13.5)
- Android SDK with platform 36; Gradle downloads the NDK and other missing parts on the first build
- JDK 17 or newer
- An Android phone running Android 8.0 (API 26) or newer

## Run

```sh
flutter pub get
flutter run
```

## Check

These must all pass before a phase is closed (plan §15.1):

```sh
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test --timeout 120s
flutter test integration_test -d <device>   # on a phone or emulator
tool/build_apk.sh
```

**Generated code** is committed, so a fresh clone builds as is. After changing the database tables, run `dart run build_runner build`; after a schema version change, also `dart run drift_dev make-migrations` (see ARCHITECTURE.md, *Storage*). After changing `pigeons/platform_api.dart`, run `dart run pigeon --input pigeons/platform_api.dart`.

`test/architecture_test.dart` enforces the layer rules: Material comes from `material_ui`, `core/` never imports `features/`, domain code is pure Dart, and widgets never import `dart:io`.

## Build an APK

```sh
tool/build_apk.sh            # APK
tool/build_apk.sh --bundle   # APK and the Play Store bundle (.aab)
```

Each run raises the build number in `pubspec.yaml` by one, builds an obfuscated release APK that works on every phone, and saves it as `releases/LINKUP_version-N.apk` (with `--bundle`, also `LINKUP_version-N.aab`). The symbols for reading crash stack traces go to `releases/symbols/version-N/`; keep them for every build you hand out. The build number is also Android's version code, so a newer APK installs as an update over an older one. `releases/` is not committed. Publishing: [`docs/PLAY_STORE.md`](docs/PLAY_STORE.md).

**Signing.** Release builds are signed with the key named in `android/key.properties` (git-ignored); the keystore lives outside the repository, in `~/LinkUpKeys/` (its `README.txt` has the details). **Back that folder up:** without it, installed copies can never be updated. Without `key.properties`, builds fall back to the debug key, and such an APK can't update a release-signed install (uninstall first).

```properties
storeFile=/Users/<you>/LinkUpKeys/linkup-release.jks
storePassword=…
keyAlias=linkup
keyPassword=…
```

## Permissions

**Wi-Fi Direct only** (asked when you choose it): *Nearby devices* (`NEARBY_WIFI_DEVICES`, Android 13+, declared so it never gives your location), or on Android 8–12 location (`ACCESS_FINE_LOCATION`), which Android requires for Wi-Fi Direct discovery, with Location turned on. LinkUp never uses or stores your location. `CHANGE_WIFI_STATE` is granted automatically.

LinkUp runs a foreground service (`FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_CONNECTED_DEVICE`, `WAKE_LOCK`) only while files move or *Stay reachable* is on, always with a notification. Runtime permissions: notifications (`POST_NOTIFICATIONS`), asked the first time you open a chat, after a short explanation; and on Android 8–9 only, storage, the first time you use *Save to Downloads*. Opening a received app (APK) hands it to Android's installer, which asks you to allow installs from LinkUp first (`REQUEST_INSTALL_PACKAGES`); nothing is installed without you. The app also declares `INTERNET`, which Android requires for any socket, even to a phone on the same Wi-Fi; the app never contacts the internet. It also declares `ACCESS_NETWORK_STATE`, `ACCESS_WIFI_STATE` and `CHANGE_WIFI_MULTICAST_STATE`, which are granted automatically. If Android asks *"This network has no internet access. Stay connected?"*, answer **Yes**.

## Security and privacy

LinkUp is made for a local network you trust (a home, office or event Wi-Fi, or your own hotspot). There are no accounts and nothing goes to the internet; chats and files stay in the app's private storage. **Messages and files are not encrypted on the network in v1.0**: others on the same Wi-Fi with special tools could read them, and a device could pretend to be another. Every input from the network is validated and limited, files are checked with SHA-256, and logs hold no message text or file names. See `ARCHITECTURE.md` → *Security model* and ADR-0022.

## Router isolation

Some routers, especially guest networks and hotel or office Wi-Fi, block phones from talking to each other. LinkUp can't fix that from the phone. After 30 seconds with nobody found, it shows a hint to check the router. A phone hotspot is a reliable alternative.

## Known limitations (v1.0)

- With *Stay reachable* off, LinkUp is reachable only while it is open or a transfer is running; Android freezes it soon after it goes to the background, and messages to it wait until it is opened.
- Force-stopping the app, restarting the phone, or an aggressive battery saver stops LinkUp until it is opened again (no start on boot). Partial files are kept for resume. If your phone stops LinkUp in the background, allow it in Settings → Battery settings.
- Very large files take a moment to appear in the Send sheet: Android's file picker copies them into the app first.
- Only the sender can pause. Cancelling a file that is still waiting (the other person is offline) isn't announced to them; their card keeps waiting.
- *Everyone* reaches only the people online when you send; there are no replies inside the Everyone thread.
- Wi-Fi Direct is new and still being tested on phones; one group at a time (about 50 m). Bluetooth is *Coming soon* (P14).
- Messages and files are not encrypted on the local network (see *Security and privacy*).
- Android only. iOS, desktop and web are out of scope.
