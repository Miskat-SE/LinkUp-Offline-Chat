# ADR-0024: Bluetooth LE finds phones; L2CAP channels carry the usual connections

- **Status:** Accepted (to be confirmed on the testbed phones, P14.4)
- **Date:** 2026-10-15
- **Plan decision:** D21, phase P14 (user's choice: automatic, no pairing)

## Context

Bluetooth is for when Wi-Fi is off. The user wanted it to work like Wi-Fi Direct: open LinkUp and nearby phones connect by themselves, with no pairing and no Android settings. Bluetooth isn't an IP network, so the LAN stack can't run over it as is. But everything above the socket (framing, HELLO, keep-alive, limits, messaging, file transfer) only needs a two-way byte stream.

Options considered: Bluetooth tethering (PAN) gives an IP network and needs no code, but users must pair phones and turn on tethering by hand. Classic RFCOMM needs the other phone to be discoverable (a system prompt, two minutes at a time). BLE advertising works in the background without prompts, and since Android 10 insecure L2CAP channels (`listenUsingInsecureL2capChannel`) open without pairing.

## Decision

1. **Finding:** each phone advertises a LinkUp service UUID; the scan response carries its device ID (16 bytes) and control channel (2 bytes, manufacturer data ID 0xFFFF). Phones scan for the UUID and hand what they find to the connection manager as endpoints (Bluetooth address and channel).
2. **Links:** a `ByteLink`/`LinkTransport` abstraction sits under `PeerConnection`, `ConnectionManager`, `DataConnection` and `TransferEngine`. TCP is `TcpTransport`; Bluetooth is `BluetoothTransport` over the Kotlin bridge (one L2CAP server for control, one for file data, the "ports" being channels). The protocol and every rule above it are unchanged.
3. **Files** use the same engine on the file channel, run in the main isolate (Bluetooth is slow enough not to matter), with 16 KB chunks and write acknowledgements as backpressure. The send sheet warns when files will take minutes (about 80 KB/s).
4. **Android 10+**; permissions (Nearby devices on 12+, location on 10–11) asked only when Bluetooth is chosen; the server opens again once allowed and Bluetooth is on.

## Consequences

- No protocol change; all connection, messaging and transfer tests apply to Bluetooth through a fake radio.
- Range about 10 m; speed tens to a few hundred KB/s depending on the phones.
- Manufacturer ID 0xFFFF is for testing; a registered ID or a 128-bit service-data layout can replace it before a store release.
- The emulator can advertise and scan but has no second phone; real behaviour is checked on phones.
