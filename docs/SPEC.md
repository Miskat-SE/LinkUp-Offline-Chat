# ResQMesh — Build Specification

Source: `ResQMesh_prompt.txt` (8 Oct 2026). This file is the reference that `PROJECT_PLAN.md` cites as *spec §n*. Wording is kept from the original; only Markdown structure was added.

> You are a senior Flutter/Dart engineer, Android networking engineer, UI/UX designer, and software architect.
> Build a complete production-quality Android application using Flutter.
> The app is an offline LAN messenger and file-sharing application.
> The application must work even when the Wi-Fi router has NO INTERNET CONNECTION.
> The only requirement is: multiple Android phones are connected to the SAME Wi-Fi router/local network.
> The phones must be able to discover each other and communicate directly over the local network.

## 1. Core Concept

The application should allow users connected to the same Wi-Fi/LAN network to:

- Register with a unique name
- Automatically discover other users running the app
- See online users
- Send text messages
- Send files, images, videos, documents
- Send multiple files
- Receive files
- Store messages locally
- Store received files locally
- Work completely without Internet
- Continue working when the router has no WAN/Internet connection

There must be: NO cloud backend, NO Firebase, NO external API, NO Internet dependency, NO remote database.
All communication must happen over the local network.

## 2. Technology Stack

Use: Flutter, Dart, Android, Material 3 Expressive design, local SQLite database, local file storage, LAN socket communication, UDP/TCP where appropriate, mDNS/NSD and/or UDP discovery for peer discovery, secure local communication where practical.

Use stable, well-maintained Flutter packages. Before selecting packages, inspect their current compatibility with modern Flutter/Android. Avoid unnecessary dependencies.

## 3. Important Networking Requirement

Do NOT assume that Internet access exists. The following scenario MUST work:

```
Phone A ↓ Wi-Fi Router ↓ Phone B
Router: Internet: OFF, LAN: ON
```

Phone A and Phone B must still communicate.

Do not use: Firebase, Supabase, WebSocket cloud servers, REST APIs hosted remotely, Google services, Internet-based peer discovery.

The app must communicate using private LAN IP addresses.

## 4. Peer Discovery

When the application starts:

1. Detect the current Wi-Fi/LAN connection.
2. Determine the local network interface/IP.
3. Start LAN peer discovery.
4. Advertise the application on the local network.
5. Listen for other app instances.
6. Detect other users automatically.
7. Show discovered users in the application.

Use a robust discovery mechanism. Preferred approach:

- Android NSD / mDNS where practical
- UDP broadcast as fallback
- TCP socket communication for actual data transfer

The discovery system should handle: new users joining, users leaving, IP address changes, Wi-Fi reconnect, app restart, duplicate discovery packets, network changes, devices disappearing.

Each device should have a persistent locally generated device ID. Do NOT use the username as the device identity.

## 5. User Registration

On first launch show: **"Choose your name"**. The user enters a username.

Username requirements: required; minimum 2 characters; maximum 30 characters; trim whitespace; no empty username; unique within the current LAN.

Example: `Yusuf`. If another device already uses `Yusuf`, show: **"This name is already being used on this network."** The user must choose another name.

Important:

- Username uniqueness should be verified against currently active peers on the LAN.
- The app should still allow the user to open the app if there are temporarily no peers available.
- Store the selected username locally.
- The user should not need to register again every time the app opens.

Provide: Settings → Change Name. Changing the name must re-register the device on the LAN.

## 6. Main Screen

Create a modern Material 3 Expressive UI.

Top App Bar: "LAN Chat". Show connection/network status, for example:

- 🟢 Local Network Connected
- 🟠 Searching for devices...
- 🔴 Wi-Fi disconnected

Below: Users / Chats. Each user item should display: avatar, username, online/offline status, last message, last message time, unread message count.

Example: `Yusuf` · "Are you there?" · 8:42 PM · ● Online

## 7. Online Users Screen

Create a screen: **"People Nearby"**. Display all discovered devices.

Each user card should show: avatar, username, online status, device/IP information optionally, last seen.

Actions: Open Chat, Send File. Do NOT expose unnecessary technical information by default.

## 8. One-to-One Chat

Create a modern chat interface. Features: send text, receive text, message timestamps, delivery status, read status where technically possible, reply, copy, delete, retry failed message, file messages, image messages, video messages, document messages.

Message states: Sending, Sent, Delivered, Read, Failed.

Use appropriate Material 3 Expressive UI components. Messages must look polished and modern.

## 9. Local Message Storage

Every message must be stored locally. Use SQLite. Suggested entities:

**User / Peer** — id, deviceId, username, ipAddress, port, status, lastSeen, createdAt, updatedAt

**Message** — id, localMessageId, senderDeviceId, receiverDeviceId, messageType, text, fileId, timestamp, status, isRead, createdAt

**File** — id, fileId, originalName, localPath, mimeType, size, senderDeviceId, receiverDeviceId, transferStatus, checksum, createdAt

Use proper indexes. Do not store large binary files directly inside SQLite. Store files in the Android app's local storage and store only metadata/path in SQLite.

## 10. File Sharing

Users must be able to share files directly over LAN. Supported examples: JPG, PNG, WEBP, MP4, PDF, DOCX, XLSX, ZIP, TXT, APK — any reasonable file type.

Use Android file picker. When selecting a file show: file name, file size, file type. Then: Send.

## 11. File Transfer Architecture

Do NOT send large files through JSON. Use:

- Control messages → JSON/structured protocol
- File data → binary TCP stream

For example:

1. Connection established
2. Client sends `FILE_METADATA { fileId, fileName, fileSize, mimeType, checksum }`
3. Receiver responds `READY`
4. Sender streams binary file data
5. Receiver writes the incoming data directly to local storage
6. After completion the receiver calculates the checksum
7. Receiver sends `FILE_COMPLETE`
8. Sender marks the transfer as completed

## 12. File Transfer Requirements

Implement: progress percentage, transfer speed, remaining time, pause if technically possible, cancel transfer, retry failed transfer, checksum verification, duplicate detection, resume support if practical.

UI example:

```
Sending photo.jpg
████████████░░░░ 76%
8.2 MB / 10.7 MB
2.1 MB/s
Cancel
```

## 13. Large File Handling

The application must NOT load an entire large file into RAM. Use streaming.

- BAD: read entire 2 GB file into memory
- GOOD: open file stream → read chunks → send chunks → update progress → continue

Use appropriate buffer sizes. Make this architecture capable of handling large files.

## 14. Group / Broadcast Messaging

Add a "Broadcast" feature. The user can select "Send to Everyone". Then the message should be delivered to all currently available peers on the LAN.

Example: Yusuf: "Meeting at 10 PM" — all connected users receive the message.

Also support: select multiple users; send message/file to selected users.

## 15. Offline Behavior

If the recipient is temporarily unavailable: message status Pending; store the message locally. When that peer comes back online: attempt delivery automatically.

For files: keep transfer metadata locally and allow retry. Do not upload anything to the Internet.

## 16. Network Changes

Handle: Wi-Fi connected, Wi-Fi disconnected, Wi-Fi changed, router reboot, IP address changed, airplane mode, mobile data active, Wi-Fi without Internet.

Important: the application should determine whether LAN communication is available independently of Internet availability. Do NOT consider "No Internet" as "No network". If Wi-Fi LAN is available, the application should continue working.

## 17. Android Permissions

Implement all required modern Android permissions correctly. Handle runtime permissions gracefully.

Depending on Android version, consider: nearby Wi-Fi devices, local network access, notification permission, storage/file access requirements, network state, Wi-Fi state.

Do NOT request unnecessary permissions. Explain why a permission is needed before requesting it.

## 18. Background Behavior

Investigate Android background restrictions. Implement reasonable background behavior for receiving messages/files.

If a foreground service is required for reliable file transfers: implement it properly. Show an appropriate notification during active file transfers, e.g. "Receiving video.mp4 — 62%".

Do not keep unnecessary background services running.

## 19. Message Protocol

Create a clean internal LAN protocol. Example packet:

```json
{
  "protocolVersion": 1,
  "type": "message",
  "messageId": "...",
  "senderId": "...",
  "senderName": "...",
  "receiverId": "...",
  "timestamp": "...",
  "payload": { "text": "Hello" }
}
```

Other packet types: HELLO, DISCOVERY, DISCOVERY_RESPONSE, REGISTER, REGISTER_RESPONSE, NAME_CHECK, MESSAGE, MESSAGE_ACK, MESSAGE_DELIVERED, MESSAGE_READ, FILE_OFFER, FILE_ACCEPT, FILE_REJECT, FILE_CHUNK, FILE_COMPLETE, FILE_CANCEL, PING, PONG, GOODBYE.

Create strongly typed Dart models for these messages. Do not scatter raw JSON strings throughout the application.

## 20. Architecture

Use a clean scalable architecture. Recommended structure:

```
lib/
  core/
    constants/
    errors/
    network/
    storage/
    utils/
  features/
    onboarding/     data/ domain/ presentation/
    discovery/      data/ domain/ presentation/
    chat/           data/ domain/ presentation/
    file_transfer/  data/ domain/ presentation/
    users/          data/ domain/ presentation/
    settings/       presentation/
  shared/
    widgets/
    models/
  main.dart
```

Use clear separation between UI, business logic, networking, persistence, file system and models. Do not put networking code inside widgets.

## 21. State Management

Choose one modern Flutter state-management solution. Prefer Riverpod, or another clean, lightweight solution if there is a strong reason. Use dependency injection appropriately. Avoid global mutable state.

## 22. Material 3 Expressive UI

The UI must feel like a modern Android application. Use Material 3 and Material 3 Expressive design principles:

dynamic color where supported, large expressive typography, rounded surfaces, modern cards, smooth transitions, Material icons, floating action buttons, bottom sheets, adaptive layouts, proper dark mode, light mode, accessible contrast, touch-friendly controls, empty states, loading states, error states.

Do not make the UI look like an old Flutter demo.

## 23. Screens

Splash · First-time username setup · Home · People Nearby · Chat · File Preview · File Transfer Details · Notifications / Activity · Settings · Change Username · Storage · About

## 24. Home UI

```
LAN Chat
🟢 Local Network
[ Search ]
Chats
┌──────────────────────────┐
│ 👤 Rahim                 │
│ Are you coming?          │
│ 8:42 PM               2  │
└──────────────────────────┘
┌──────────────────────────┐
│ 👤 Karim                 │
│ 📎 project.zip           │
│ 8:20 PM                  │
└──────────────────────────┘
                         ＋
```

The actual UI should be more polished than this example.

## 25. Chat UI

```
Rahim
Today
        Hello! 👋
        8:41 PM
Are you coming?
8:42 PM ✓✓
        Yes, I'm coming.
        8:43 PM
[ + ] [ Type a message... ] [ 🎤 ]
```

For files:

```
📎 project.zip
24.6 MB
[Download / Open]
```

## 26. File Preview

Images: show image preview. Videos: show video thumbnail. Documents: show file icon and metadata. Unsupported files: show generic file card. Never assume that a file can be previewed.

## 27. Storage Management

Create Settings → Storage. Show: messages, files received, files sent, total storage used.

Allow: clear cached files, delete received files, clear chat history, clear all local data. Before destructive operations show a confirmation dialog.

## 28. Security

Although this application works on a trusted LAN, implement reasonable security.

Each device should have a persistent device ID. Do not rely only on username. Validate incoming packets. Prevent malformed packets from crashing the app. Limit packet sizes for control messages.

Validate: sender ID, message ID, file size, checksum, protocol version.

Avoid arbitrary file path injection. Never trust incoming filenames directly. Sanitize filenames before writing to disk. Prevent `../` path traversal.

## 29. Optional Encryption

If practical, implement encrypted peer communication. Possible approach: each device generates a local key pair; during initial peer connection exchange public keys, establish a shared secret, encrypt message/file-transfer traffic.

However: do not compromise stability for experimental cryptography. If implementing encryption, use well-established libraries/primitives. Never invent your own cryptographic algorithm. Document the security model clearly.

## 30. Reliability

Gracefully handle: peer suddenly disconnecting, partial file transfer, duplicate packets, duplicate messages, network timeout, invalid packet, port unavailable, router isolation, Android process termination, app restart, IP changes.

Implement: timeouts, retries, connection cleanup, duplicate detection, proper error handling.

## 31. Router Client Isolation

Some Wi-Fi routers prevent devices from communicating with each other. Detect this situation when possible. If peer discovery fails show:

> No nearby devices found.
> Make sure:
> • Everyone is connected to the same Wi-Fi
> • The router allows device-to-device communication
> • The app is allowed to access the local network

Do not incorrectly claim that the app is broken.

## 32. No Internet Dependency

The application should NEVER require: Firebase, Google Sign-In, Supabase, Cloudinary, AWS, remote REST API, remote WebSocket server, analytics requiring Internet.

The app must remain functional when Internet = OFF and Wi-Fi LAN = ON.

## 33. Testing

Create automated tests for: username validation, unique username logic, peer discovery, protocol serialization, message serialization, message deduplication, file metadata, checksum, file transfer state, database operations, network reconnect, timeout, retry, malformed packets, file path sanitization.

Also create integration tests where practical.

## 34. Manual Testing Tools

Add a developer/debug mode. The developer screen should show: local IP, subnet, listening port, discovered peers, connection status, active transfers, packets sent, packets received, network errors.

This screen should be hidden from normal users.

## 35. Logging

Implement structured local logging. Example:

```
[DISCOVERY] Peer found: device_123
[NETWORK] Connected: 192.168.0.105
[MESSAGE] Received: msg_123
[FILE] Transfer started
[FILE] Transfer completed
[ERROR] Connection timeout
```

Do not log sensitive message contents by default.

## 36. Performance

The application should remain responsive while discovering peers, sending messages, receiving messages, sending large files and receiving large files.

Networking and file operations must not block the Flutter UI thread. Use asynchronous APIs properly.

## 37. UX Requirements

Every operation should have clear states. Examples: Searching for devices..., No devices found, Connected, Disconnected, Sending..., Sent, Delivered, Failed, Retry, Receiving..., Completed, Cancelled.

Use expressive animations carefully. Do not over-animate.

## 38. Project Documentation

Create `README.md` including: project overview, architecture, network architecture, discovery mechanism, message protocol, file transfer protocol, database schema, security model, Android permissions, how to run, how to build APK, how to test two phones, known limitations, router isolation explanation.

Also create `ARCHITECTURE.md`, `PROTOCOL.md`, `TESTING.md`.

## 39. Development Strategy

Do NOT try to generate the entire project blindly in one step. Build incrementally.

| Phase | Work |
|---|---|
| 1 | Create Flutter project. Implement Material 3 Expressive theme. Implement onboarding. Implement username storage. |
| 2 | Implement LAN discovery. Test Phone A ↔ Phone B without Internet. |
| 3 | Implement TCP connection. |
| 4 | Implement text messaging. |
| 5 | Implement SQLite persistence. |
| 6 | Implement file transfer. |
| 7 | Implement group/broadcast. |
| 8 | Implement background receiving. |
| 9 | Implement security hardening. |
| 10 | Implement automated tests. |
| 11 | UI polish. |
| 12 | APK release build. |

## 40. Critical Development Rule

After completing each phase: run static analysis, run formatter, run unit tests, fix all compilation errors, review architecture, test the feature. Only then move to the next phase.

Never leave the repository in a broken compilation state.

## 41. Real Device Testing

The final app MUST be tested on at least two physical Android devices connected to the same Wi-Fi router. Test:

- Phone A → Phone B: text
- Phone B → Phone A: text
- Phone A → Phone B: image
- Phone A → Phone B: large file
- Phone B → Phone A: large file
- Disconnect Wi-Fi Internet while keeping Wi-Fi connected; verify communication still works
- Restart router; verify peer discovery recovers
- Change IP; verify reconnection works

## 42. Important Android Limitation

Do not assume Android will allow unrestricted background networking. Research the current Android version restrictions and implement the correct approach for modern Android.

If some behavior cannot be guaranteed while the app is completely killed, document the limitation rather than pretending it works.

## 43. Final Deliverables

Complete Flutter source code · Android configuration · SQLite database layer · LAN discovery implementation · TCP communication layer · messaging system · file transfer system · local storage · Material 3 Expressive UI · dark/light theme · settings · developer diagnostics · unit tests · integration tests where practical · `README.md` · `ARCHITECTURE.md` · `PROTOCOL.md` · `TESTING.md`.

The project must build successfully with:

```
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

## 44. Development Behavior

You are working directly inside the project repository. Before writing code: inspect the repository; determine whether a Flutter project already exists; inspect existing files; do not overwrite existing work unnecessarily; create a clear implementation plan; start implementing incrementally.

When you encounter an architectural decision: prefer the simplest reliable solution. Do not add dependencies without a reason. Do not create fake implementations. Do not create mock networking and call the project complete. The actual LAN networking must work.

## 45. Final Goal

The final product should feel like: *"AirDrop + Messenger, but only for people connected to the same Wi-Fi network."*

However, this is NOT an Internet application. It is a **Local Network Messenger + File Sharing App** with:

| | |
|---|---|
| Internet | ❌ Not required |
| Wi-Fi/LAN | ✅ Required |
| Cloud | ❌ |
| Local messages | ✅ |
| Local files | ✅ |
| Peer-to-peer/LAN communication | ✅ |
| Unique usernames | ✅ |
| Text chat | ✅ |
| File sharing | ✅ |
| Group/broadcast | ✅ |
| Modern Material 3 Expressive UI | ✅ |

Build the application step-by-step and keep the code production-quality.
