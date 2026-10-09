# ResQMesh LAN Protocol

Version **1** · document v0.1 (8 Oct 2026, phase P0)

This document is the contract between two ResQMesh devices on the same Wi-Fi network. The Dart implementation lives in `lib/core/network/protocol/`, and the JSON examples below are kept as test fixtures in `test/fixtures/protocol/`. If the code and this document disagree, that is a bug in one of them.

---

## 1. Overview

| Channel | Transport | Port | Used for |
|---|---|---|---|
| Discovery | UDP broadcast / unicast | **28760** (fixed) | DISCOVERY, DISCOVERY_RESPONSE, HELLO, GOODBYE, NAME_CHECK, REGISTER_RESPONSE (to a NAME_CHECK) |
| NSD (mDNS) | Android `NsdManager` | — | Service type `_resqmesh._tcp`, instance name = device ID, TXT `id`, `v` |
| Control | TCP, one long-lived connection per pair of peers | **28761** preferred, otherwise ephemeral (advertised) | HELLO, REGISTER, REGISTER_RESPONSE, MESSAGE*, PING/PONG, GOODBYE |
| Data | TCP, one short-lived connection per file transfer | **28762** preferred, otherwise ephemeral; advertised as `filePort` in HELLO | HELLO, FILE_* and binary FILE_CHUNK frames |

Ports 28760–28762 are in an unassigned IANA block and below Android's ephemeral range (32768+). Data connections have their own port because the receiving side runs in a separate worker isolate (ADR-0010, ADR-0021); a device without `filePort` can't receive files.

---

## 2. Framing

### 2.1 TCP frames

```
+--------+----------------------+------------------------+
| kind   | length               | body                   |
| 1 byte | 4 bytes, uint32 BE   | `length` bytes         |
+--------+----------------------+------------------------+
```

| kind | Body | Max body | Allowed on |
|---|---|---|---|
| `0x01` | Control packet: UTF-8 JSON (§3) | 64 KiB | Control and data connections |
| `0x02` | File chunk: raw bytes | 256 KiB | Data connections, after FILE_ACCEPT |

- The receiver checks `kind` and `length` **before** buffering the body. An unknown kind or an over-limit length closes the connection.
- A zero-length body is invalid for both kinds.

### 2.2 UDP datagrams

```
+-----------------+------------------------+
| magic "RQM1"    | UTF-8 JSON (§3)         |
| 4 bytes ASCII   | ≤ 1,396 bytes           |
+-----------------+------------------------+
```

- The whole datagram is ≤ 1,400 bytes, so it never fragments on Ethernet or Wi-Fi.
- Datagrams without the magic are ignored silently.
- Datagrams whose `senderId` equals the receiver's own device ID are ignored (own broadcasts loop back).

---

## 3. Control packet envelope

```json
{
  "protocolVersion": 1,
  "type": "MESSAGE",
  "messageId": "6f1c2a0e-8a4b-4d1e-9a51-2c7f0b3e9d10",
  "senderId": "3f2a9c4e-1b7d-4c55-8e0a-6d2f9b1c7a33",
  "senderName": "Yusuf",
  "receiverId": "b81d07aa-5c3e-4f19-9d26-0e7c4a8b2f61",
  "timestamp": "2026-10-08T20:42:13.512Z",
  "payload": { "messageType": "text", "audience": "direct", "text": "Hello" }
}
```

| Field | Type | Rules |
|---|---|---|
| `protocolVersion` | int | Must be `1` |
| `type` | string | One of §4. Unknown types are ignored and logged (forward compatibility). |
| `messageId` | string | UUID. Unique per packet, **except** that a resent MESSAGE keeps its original ID so the receiver can de-duplicate it. |
| `senderId` | string | UUID device ID. On TCP it must equal the device ID from that connection's HELLO. |
| `senderName` | string | Normalised name, 2–30 graphemes, no control characters. May be empty only in DISCOVERY and NAME_CHECK (sent before the device has a name). |
| `receiverId` | string | UUID device ID, or `"*"` for everyone |
| `timestamp` | string | ISO 8601 UTC with milliseconds. The sender's clock; **informational only**. Receivers order chats by their own clock. |
| `payload` | object | Type-specific (§4). Unknown payload fields are ignored. |

A packet with a missing or wrongly typed required field is dropped and counted as malformed. It never throws out of the codec.

---

## 4. Packet types

### 4.1 Discovery and identity

#### DISCOVERY — UDP broadcast
"Who is here?" Sent at start-up and after every network change. `receiverId` is `"*"`. Payload: `{}`.

#### DISCOVERY_RESPONSE — UDP unicast to the asker
Sent after a random 0–300 ms delay. Payload is the same as HELLO.

#### HELLO — UDP broadcast every 5 s (15 s in background); first frame on every TCP connection

```json
"payload": {
  "tcpPort": 28761,
  "appVersion": "1.0.0+1",
  "minProtocol": 1,
  "maxProtocol": 1,
  "nameClaimedAt": "2026-10-08T19:02:44.120Z",
  "capabilities": [],
  "filePort": 28762
}
```

| Field | Rules |
|---|---|
| `tcpPort` | 1–65535; the port the sender actually listens on |
| `filePort` | Optional, 1–65535: where the sender accepts file data connections (§4.4). Absent: it can't receive files. |
| `appVersion` | ≤ 32 characters |
| `minProtocol`, `maxProtocol` | ints, `1 ≤ min ≤ max` |
| `nameClaimedAt` | ISO 8601 UTC; when the sender claimed its current name |
| `capabilities` | Array of strings (≤ 16 items, each ≤ 32 characters). Reserved for future features such as `tls1`. |

On TCP, both sides send HELLO as their first frame within 5 s of connecting, or the connection is closed. A device may send HELLO again on an open control connection when its announcement changes (for example, its file port after a network change); the receiver replaces the earlier one. The sender ID must stay the same.

#### GOODBYE — UDP broadcast and TCP
The sender is leaving: the app is stopping or Wi-Fi is going down. Receivers mark it offline at once.

```json
"payload": { "reason": "appStopped" }
```
`reason`: `appStopped`, `networkLost`, or any other string ≤ 64 characters (informational).

### 4.2 Names

#### NAME_CHECK — UDP broadcast
Sent during onboarding and Change name, before the name is claimed. `senderName` may be empty.

```json
"payload": { "candidateName": "Yusuf" }
```

Only a peer whose own name matches the candidate (normalised, case-insensitive) answers, with REGISTER_RESPONSE `nameTaken`. Silence for 3 s means the name is free.

#### REGISTER — TCP control
Claims a name after onboarding or a rename. Sent to every connected peer.

```json
"payload": { "name": "Yusuf", "nameClaimedAt": "2026-10-08T19:02:44.120Z" }
```

#### REGISTER_RESPONSE — UDP unicast (answer to NAME_CHECK) or TCP (answer to REGISTER)

```json
"payload": {
  "result": "nameTaken",
  "name": "Yusuf",
  "holderId": "b81d07aa-5c3e-4f19-9d26-0e7c4a8b2f61",
  "holderClaimedAt": "2026-10-07T08:11:02.000Z"
}
```

| Field | Rules |
|---|---|
| `result` | `ok` or `nameTaken` |
| `name` | The name being answered about |
| `holderId`, `holderClaimedAt` | Required when `result` is `nameTaken` |

**Clash rule:** if two devices hold the same name, the one with the earlier `nameClaimedAt` keeps it; a tie goes to the lower device ID (string compare). The other device must rename.

### 4.3 Messages

#### MESSAGE — TCP control
The envelope `messageId` is the chat message ID.

```json
"payload": {
  "messageType": "text",
  "audience": "direct",
  "text": "Are you coming?",
  "replyToId": null
}
```

```json
"payload": {
  "messageType": "file",
  "audience": "broadcast",
  "text": null,
  "replyToId": null,
  "file": {
    "fileId": "0a4e6c1d-2b8f-4e57-a3c9-5d1f7e2b9c80",
    "name": "project.zip",
    "size": 25794560,
    "mimeType": "application/zip",
    "sha256": "9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08"
  }
}
```

| Field | Rules |
|---|---|
| `messageType` | `text` or `file` |
| `audience` | `direct`, `broadcast` (sent to everyone online) or `multi` (sent to selected people). A `broadcast` message is sent as one MESSAGE per recipient, each with that recipient's `receiverId` and the **same** `messageId`; receipts come back from each recipient. Receivers show it in their Everyone thread. Messages to selected people are sent as ordinary `direct` messages, one per person. |
| `text` | Required for `text`, ≤ 16 KiB UTF-8; optional caption for `file` |
| `replyToId` | UUID or null |
| `file` | Required for `file`. `fileId` UUID; `name` ≤ 255 UTF-8 bytes (sanitised before use); `size` ≥ 0; `mimeType` ≤ 127 characters; `sha256` 64 lowercase hex characters |

#### MESSAGE_ACK — TCP control
The receiver validated and **stored** the message. The sender marks it **Sent** and stops resending it.

```json
"payload": { "ackFor": "6f1c2a0e-8a4b-4d1e-9a51-2c7f0b3e9d10" }
```

A duplicate MESSAGE is ACKed again but not stored or notified twice.

#### MESSAGE_DELIVERED — TCP control
The messages were shown to the recipient (chat on screen, or notification posted). The sender marks them **Delivered**.

```json
"payload": { "messageIds": ["6f1c2a0e-8a4b-4d1e-9a51-2c7f0b3e9d10"] }
```

#### MESSAGE_READ — TCP control
The recipient opened the chat. The sender marks the messages **Read**.

```json
"payload": { "messageIds": ["6f1c2a0e-8a4b-4d1e-9a51-2c7f0b3e9d10"] }
```

`messageIds`: 1–100 UUIDs. Receipts are idempotent; they are queued and resent after a reconnect if needed.

### 4.4 File transfer (data connection)

A transfer runs on its own TCP connection, opened by the sender to the receiver's `filePort` after the file MESSAGE was confirmed (any of MESSAGE_ACK, MESSAGE_DELIVERED or MESSAGE_READ). The receiver only accepts an offer for a file it was told about in a MESSAGE from the same sender, with the same size and SHA-256. The data connection's HELLO uses the same identity as the control connection; the sender checks that the expected device answered.

- **Flow control:** the receiver stops reading while it writes to disk, so TCP slows the sender; the sender waits for its socket every 1 MiB. Neither side holds more than a few chunks in memory.
- **Resume:** the receiver answers FILE_ACCEPT with the size of its partial file, after hashing that partial file again.
- **At most 3** files are sent at a time per device; the others wait in order.
- A data connection is closed after 2 minutes without any frame.

```
Sender                                            Receiver
HELLO ─────────────────────────────────────────▶ HELLO (both directions)
FILE_OFFER ────────────────────────────────────▶ validate
◀─────────────────────── FILE_ACCEPT{offset}  or  FILE_REJECT{reason}
FILE_CHUNK × n (kind 0x02) ────────────────────▶ write <fileId>.part, hash as it arrives
◀─────────────────────── FILE_COMPLETE{sha256}   after verify · fsync · rename
```

#### FILE_OFFER — first control frame after HELLO
Called FILE_METADATA in spec §11.

```json
"payload": {
  "fileId": "0a4e6c1d-2b8f-4e57-a3c9-5d1f7e2b9c80",
  "chatMessageId": "6f1c2a0e-8a4b-4d1e-9a51-2c7f0b3e9d10",
  "fileName": "project.zip",
  "fileSize": 25794560,
  "mimeType": "application/zip",
  "sha256": "9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08"
}
```

#### FILE_ACCEPT — receiver → sender
Called READY in spec §11. `offset` > 0 resumes a partial transfer.

```json
"payload": { "fileId": "0a4e6c1d-2b8f-4e57-a3c9-5d1f7e2b9c80", "offset": 0 }
```

#### FILE_REJECT — receiver → sender

```json
"payload": { "fileId": "0a4e6c1d-2b8f-4e57-a3c9-5d1f7e2b9c80", "reason": "noSpace" }
```
`reason`: `declined`, `noSpace`, `tooLarge`, `invalid`.

#### FILE_CHUNK — binary frame `kind 0x02`
Raw file bytes in order, starting at the accepted offset. There is no JSON envelope; the data connection identifies the file. The sender sends 64 KiB chunks (tunable, ≤ 256 KiB) and waits on socket backpressure.

#### FILE_COMPLETE — receiver → sender
Sent after the last byte arrives, the SHA-256 matches, the file is synced to disk and renamed into place. A FILE_OFFER for a file that is already complete, or whose content the receiver already has from the same sender, is answered with FILE_COMPLETE straight away.

```json
"payload": { "fileId": "0a4e6c1d-2b8f-4e57-a3c9-5d1f7e2b9c80", "sha256": "9f86d081…" }
```

#### FILE_CANCEL — either side

```json
"payload": { "fileId": "0a4e6c1d-2b8f-4e57-a3c9-5d1f7e2b9c80", "reason": "paused" }
```

| `reason` | Effect |
|---|---|
| `cancelled` | Transfer ends; receiver deletes the partial file |
| `paused` | Transfer ends; partial file kept for resume |
| `error` | Transfer ends; partial file kept; sender may retry |
| `checksumMismatch` | Receiver deleted the partial file; sender retries once from zero |

### 4.5 Keep-alive

#### PING / PONG — TCP control
Sent on idle control connections every 15 s. After 2 missed PONGs the connection is closed. The round-trip time is shown in developer diagnostics.

```json
"payload": { "nonce": 42 }
```

---

## 5. Limits and validation

| Item | Limit |
|---|---|
| Control frame body | 64 KiB |
| UDP datagram | 1,400 B including magic |
| File chunk frame body | 256 KiB |
| Message text | 16 KiB UTF-8 |
| File name | 255 UTF-8 bytes after sanitising |
| File size | ≤ free space − 200 MB and ≤ *Max file size* (default 4 GiB) |
| IDs | UUID (8-4-4-4-12 hex, case-insensitive) |
| `protocolVersion` | 1 |
| HELLO on a new TCP connection | within 5 s |
| Malformed frames | connection closed after 3 in a row |

---

## 6. Versioning

- `protocolVersion` in every envelope is the version that packet is written in.
- HELLO advertises `minProtocol` and `maxProtocol`. Two peers talk only if their ranges overlap; v1 peers accept exactly version 1.
- New optional payload fields may be added within a version; receivers ignore fields they don't know.
- New packet types may be added within a version only if old peers can safely ignore them.
