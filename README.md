# LinkUp

*Project and research name: ResQMesh.*

Offline messaging and file sharing for Android phones on the same Wi-Fi network. No internet, no cloud, no accounts: phones find each other on the local network and talk directly.

> **Status: phase P3 done (connections).** Phones on the same Wi-Fi or hotspot find each other automatically, with no internet, and keep a live connection to each other. Names are unique on the network. People Nearby shows who is online, and a hidden developer screen shows the network details. Chat and file transfer arrive in phases P4–P6. See [`PROJECT_PLAN.md`](PROJECT_PLAN.md) for the schedule and [`TESTING.md`](TESTING.md) for how to test with one or two phones.

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

The app asks for no runtime permissions yet. It declares `INTERNET`, which Android requires for any socket, even to a phone on the same Wi-Fi; the app never contacts the internet. It also declares `ACCESS_NETWORK_STATE`, `ACCESS_WIFI_STATE` and `CHANGE_WIFI_MULTICAST_STATE`, which are granted automatically. If Android asks *"This network has no internet access. Stay connected?"*, answer **Yes**.

## Router isolation

Some routers, especially guest networks and hotel or office Wi-Fi, block phones from talking to each other. ResQMesh can't fix that from the phone. After 30 seconds with nobody found, it shows a hint to check the router. A phone hotspot is a reliable alternative.

## Known limitations (so far)

- Discovery only; chat (P4) and file sharing (P6) are not built yet.
- Wi-Fi Direct and Bluetooth are shown as *Coming soon* (P13–P14).
- Discovery runs while the app is open; background reachability arrives in P8.
- Android only. iOS, desktop and web are out of scope.
