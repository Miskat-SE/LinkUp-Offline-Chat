# Publishing LinkUp on Google Play

Everything needed for the first upload is prepared. This page is the checklist for the day you publish, plus the text and answers to paste into Play Console.

## 1. Decide before the first upload (permanent)

| Item | Now | Note |
|---|---|---|
| Application ID | `com.resqmesh.resqmesh` | Can never change after the first upload. A brand-matching ID (for example `com.<developer>.linkup`) must be set in `android/app/build.gradle.kts` **before** uploading. Phones with a sideloaded copy would then need a fresh install once. |
| App name on Play | LinkUp | Search Play for apps with the same name first; add a subtitle if needed, e.g. *LinkUp: Offline Chat*. |
| Upload key | `~/LinkUpKeys/linkup-release.jks` | Back up the folder in two places. Enrol in **Play App Signing** at the first upload: Google keeps the app-signing key, and this keystore becomes the upload key. |
| Support email and privacy policy URL | not set | Fill the contact line in [`PRIVACY_POLICY.md`](PRIVACY_POLICY.md) and publish it at a public URL (GitHub Pages from a public repository, or Google Sites). The code repository is private, so a link into it does not work. |

## 2. Build the bundle

```sh
FLUTTER=$HOME/development/flutter/bin/flutter tool/build_apk.sh --bundle
```

This saves `releases/LINKUP_version-N.aab` (upload this to Play) next to the APK, both signed with the upload key, obfuscated, with symbols in `releases/symbols/version-N/`. Keep the symbols for every uploaded build: they turn crash stack traces back into readable ones (`flutter symbolize`).

Version: `versionName` 1.0.0, `versionCode` = the build number N, which only goes up. Play rejects an upload whose versionCode is not higher than the last one.

## 3. Play Console account

- A new **personal** developer account must run a **closed test with at least 12 testers for 14 days** before production access is granted. Plan this into the timeline: upload to the closed testing track first and invite testers by email.
- An organisation account (needs a D-U-N-S number) skips that requirement.

## 4. Store listing

**Category:** Communication. **Tags:** messaging, file transfer.

**Short description** (80 characters max):

> Chat and share files with people nearby. Works without internet or mobile data.

**Full description:**

> LinkUp lets you message and share files with people around you, even when there is no internet.
>
> Join the same Wi-Fi network, or turn on one phone's hotspot, and everyone nearby who opens LinkUp appears automatically. No sign-up, no phone number, no internet connection, no cloud.
>
> • Chat one to one, with sent, delivered and read ticks
> • Message everyone nearby at once, and see who received it
> • Send photos, videos, documents and apps of any size, up to 4 GB each
> • Pause and resume large files; every file is checked when it arrives
> • Messages to someone who is away are sent when they are back
> • Keeps working with the screen off; optionally stay reachable when LinkUp is closed
> • Reply, forward, delete for everyone, and @mention people in group messages
> • Voice messages, and photos straight from the camera
> • Light and dark theme, large text, TalkBack support
>
> Great for classrooms, offices, events, travel, and places where the internet is down.
>
> Your chats and files stay on your phone. LinkUp has no servers and never connects to the internet. Note: in this version, messages are not encrypted on the local network, so use networks you trust or your own hotspot.

**Graphics** (in [`store/`](../store)):

| Asset | File | Play requirement |
|---|---|---|
| App icon | `icon-512.png` | 512 × 512 PNG |
| Feature graphic | `feature-graphic.png` | 1024 × 500 |
| Phone screenshots | `screenshot-1-home.png` … `screenshot-4-settings.png` | 2–8, 1080 × 2400 |

Regenerate the icon and feature graphic with `FLUTTER_ROOT=$HOME/development/flutter flutter test tool/store_assets/store_assets_test.dart`.

## 5. App content answers

**Data safety:**
- Does the app collect or share user data? **No.** (Data that stays on the device, or goes directly to another user's device at the user's request, is not "collected".)
- Is data encrypted in transit? **No** (plaintext on the local network in v1.0, ADR-0022).
- Can users request deletion? Data is only on the device: Settings → Storage → *Clear all local data*, or uninstall.

**Content rating questionnaire:** Communication app; users can interact and exchange content (messages, files); no user location shared; no purchases; no ads.

**Target audience:** 13 and over. Not designed for children, so the Families policy does not apply.

**Ads:** none.

**Permission declarations Play will ask for:**

| Permission | Declaration |
|---|---|
| `REQUEST_INSTALL_PACKAGES` | Core use: file sharing. Users receive apps (APKs) from people nearby, and LinkUp hands a received APK to Android's installer only when the user taps *Open*. Play reviews this declaration; if it is refused, remove the permission and the *Open* action for APKs, and users can still *Save to Downloads*. |
| `BLUETOOTH_SCAN` (`neverForLocation`), `BLUETOOTH_ADVERTISE`, `BLUETOOTH_CONNECT` | Bluetooth mode: find nearby LinkUp phones and connect without pairing. Not used for location. |
| `RECORD_AUDIO` | Voice messages, recorded only after the user taps the mic. In Data safety: **Audio → Voice or sound recordings** is *not collected* (it goes directly to the people the user chooses, never to the developer). |
| `ACCESS_FINE_LOCATION` (Android 12 and older only, `maxSdkVersion` 32) and `NEARBY_WIFI_DEVICES` (`neverForLocation`) | Needed by Android for Wi-Fi Direct discovery. In Data safety, location is **not collected**: the app never reads a location. If Play asks about background location: not requested. |
| Foreground service, type `connectedDevice` | Transfers files to and keeps connections with other phones on the local network while the app is in the background, always with a notification; *Stay reachable* is off unless the user turns it on. Play asks for a short video: record a file transfer continuing with the screen off, showing the notification. |

## 6. Before pressing *Publish*

- [ ] Application ID decided (section 1)
- [ ] Privacy policy online, contact email filled in
- [ ] Device matrix in `TESTING.md` §3 passed on the build being uploaded
- [ ] `tool/build_apk.sh --bundle`; symbols for that build kept
- [ ] Listing, graphics, Data safety, content rating, permission declarations, foreground-service video
- [ ] Closed test (12 testers, 14 days) done, if the account requires it
