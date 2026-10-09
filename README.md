# LinkUp

*Project and research name: ResQMesh.*

Offline messaging and file sharing for Android phones on the same Wi-Fi network. No internet, no cloud, no accounts: phones find each other on the local network and talk directly.

> **Status: phase P8 done (background receiving).** Transfers keep going with the screen off or the app in the background, with a progress notification; *Stay reachable* (Settings) keeps LinkUp reachable while it is closed. Phase P7: Send one message or file to *Everyone* online, with "Delivered to 2 of 3", or to selected people, each in their own chat. Earlier: Phones on the same Wi-Fi or hotspot find each other automatically, with no internet, and chat one to one with sent, delivered and read ticks. They share files of any type and size up to 4 GB: photos, videos, documents, apps. Progress, pause, resume and cancel are shown, and every file is checked with SHA-256. Chats and files are saved on the phone, and anything sent to someone offline goes when they come back. Names are unique on the network. See [`PROJECT_PLAN.md`](PROJECT_PLAN.md) for the schedule and [`TESTING.md`](TESTING.md) for how to test with one or two phones.

## Documents

| File | What it covers |
|---|---|
| [`PROJECT_PLAN.md`](PROJECT_PLAN.md) | Scope, decisions, schedule, backlog, risks |
| [`docs/SPEC.md`](docs/SPEC.md) | The build specification the plan cites as *spec §n* |
| [`PROTOCOL.md`](PROTOCOL.md) | LAN protocol v1: framing, packet types, file transfer |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | Code layout, layers, start-up, logging |
| [`TESTING.md`](TESTING.md) | Automated tests, the simulated peer, device test results |
| [`docs/adr/`](docs/adr/README.md) | One record per technical decision |

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
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --release
```

**Generated code** is committed, so a fresh clone builds as is. After changing the database tables, run `dart run build_runner build`; after a schema version change, also `dart run drift_dev make-migrations` (see ARCHITECTURE.md, *Storage*). After changing `pigeons/platform_api.dart`, run `dart run pigeon --input pigeons/platform_api.dart`.

`test/architecture_test.dart` enforces the layer rules: Material comes from `material_ui`, `core/` never imports `features/`, domain code is pure Dart, and widgets never import `dart:io`.

## Build an APK

```sh
tool/build_apk.sh
```

Each run raises the build number in `pubspec.yaml` by one, builds a release APK that works on every phone, and saves it as `releases/LINKUP_version-N.apk` (for example `LINKUP_version-4.apk`). The build number is also Android's version code, so a newer APK installs as an update over an older one. `releases/` is not committed.

For smaller per-CPU APKs: `flutter build apk --release --split-per-abi` (written to `build/app/outputs/flutter-apk/`).

**Signing.** Without `android/key.properties`, release builds are signed with the debug key so they can be installed for testing. For a real release, create a keystore outside the repository and add `android/key.properties` (it is gitignored):

```properties
storeFile=/absolute/path/to/resqmesh-release.jks
storePassword=…
keyAlias=resqmesh
keyPassword=…
```

## Permissions

LinkUp runs a foreground service (`FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_CONNECTED_DEVICE`, `WAKE_LOCK`) only while files move or *Stay reachable* is on, always with a notification. Runtime permissions: notifications (`POST_NOTIFICATIONS`), asked the first time you open a chat, after a short explanation; and on Android 8–9 only, storage, the first time you use *Save to Downloads*. Opening a received app (APK) hands it to Android's installer, which asks you to allow installs from LinkUp first (`REQUEST_INSTALL_PACKAGES`); nothing is installed without you. The app also declares `INTERNET`, which Android requires for any socket, even to a phone on the same Wi-Fi; the app never contacts the internet. It also declares `ACCESS_NETWORK_STATE`, `ACCESS_WIFI_STATE` and `CHANGE_WIFI_MULTICAST_STATE`, which are granted automatically. If Android asks *"This network has no internet access. Stay connected?"*, answer **Yes**.

## Router isolation

Some routers, especially guest networks and hotel or office Wi-Fi, block phones from talking to each other. ResQMesh can't fix that from the phone. After 30 seconds with nobody found, it shows a hint to check the router. A phone hotspot is a reliable alternative.

## Known limitations (so far)

- With *Stay reachable* off, LinkUp is reachable only while it is open or a transfer is running; Android freezes it soon after it goes to the background, and messages to it wait until it is opened.
- Force-stopping the app, restarting the phone, or an aggressive battery saver stops LinkUp until it is opened again (no start on boot). Partial files are kept for resume. If your phone stops LinkUp in the background, allow it in Settings → Battery settings.
- Very large files take a moment to appear in the Send sheet: Android's file picker copies them into the app first.
- Only the sender can pause. Cancelling a file that is still waiting (the other person is offline) isn't announced to them; their card keeps waiting.
- *Everyone* reaches only the people online when you send; there are no replies inside the Everyone thread.
- Wi-Fi Direct and Bluetooth are shown as *Coming soon* (P13–P14).
- Discovery and messages work while the app is open; background reachability arrives in P8.
- Android only. iOS, desktop and web are out of scope.
