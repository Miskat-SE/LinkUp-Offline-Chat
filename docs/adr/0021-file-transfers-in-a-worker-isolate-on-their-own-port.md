# ADR-0021: File transfers in a worker isolate, on their own port

- **Status:** Accepted
- **Date:** 2026-10-09
- **Plan decision:** D23

## Context

ADR-0010 puts file reads and writes, hashing and data sockets in a transfer worker isolate, so the UI never stutters during a 2 GB transfer. PROTOCOL.md v0.1 sent data connections to the control port. Dart can't hand a socket from one isolate to another, so an incoming data connection accepted on the main isolate's control port would have to be relayed byte by byte to the worker.

## Decision

- The worker isolate (`IsolateTransferBackend` running `TransferEngine`) listens on its own **file port**, 28762 preferred, otherwise ephemeral. Every device announces it as `filePort` in HELLO (optional field, protocol version 1). A device sends HELLO again on an open control connection if the port changes.
- The worker does no database or plugin work. It reports events (offer received, started, progress at most 10 a second, ended with an outcome) and asks the app how to answer each offer. `TransferService` on the main isolate owns the state machine, the database and the decisions: is the file expected, does it fit, is it a duplicate.
- Chat owns file messages; file sharing owns the bytes. `chat → file_transfer` and `settings → file_transfer` are the only allowed cross-feature dependencies on another feature's data layer (architecture test).

## Consequences

- The main isolate never touches file bytes. On loopback, a 200 MB transfer with cancel, resume and corruption keeps memory growth under 64 MB. On the emulator, receiving 1 GB left the app at about 80 MB.
- One more port to listen on, which is harmless on a LAN.
- Older v1 builds (P1–P5) announce no `filePort` and therefore can't receive files; they ignore the field.
