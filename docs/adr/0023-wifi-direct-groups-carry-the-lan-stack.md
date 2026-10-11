# ADR-0023: Wi-Fi Direct forms a group automatically and carries the existing LAN stack

- **Status:** Accepted (to be confirmed by the P13.1 spike on phones)
- **Date:** 2026-10-11
- **Plan decision:** D20 (connection methods), phase P13

## Context

Wi-Fi Direct (Android `WifiP2pManager`) connects phones without a router or a hotspot. Once a P2P group exists, it is an ordinary IPv4 network: the group owner is `192.168.49.1` on a `p2p-…` interface, and members get addresses from it. Everything above the network in LinkUp (UDP discovery, TCP control connections, file transfer on its own port) only needs a local IPv4 network.

What Wi-Fi Direct adds is forming the group:

- The classic flow (`connect` to a peer's MAC address) shows a system *"Accept invitation?"* dialog on the other phone, and both sides negotiate who becomes owner.
- From Android 10 (API 29), a group can be created with a chosen network name and passphrase (`WifiP2pConfig.Builder`), and another phone can join it with the same credentials **without any dialog**.
- Wi-Fi Direct service discovery (DNS-SD over P2P) lets phones find each other, with a few bytes of text per service, before any group exists.
- The app binds its process to the joined Wi-Fi network (ADR-0007), which would send traffic for `192.168.49.x` the wrong way.
- Permissions: `NEARBY_WIFI_DEVICES` (Android 13+, declared `neverForLocation`), or `ACCESS_FINE_LOCATION` with Location turned on (Android 8–12).

## Decision

1. **Groups form by themselves.** Every phone in Wi-Fi Direct mode advertises a `_linkup._tcp` service with its device ID and name, and, when it hosts, the group's network name and passphrase.
   - A phone that sees a LinkUp host joins it (the host with the lowest device ID if several).
   - A phone that sees only non-hosting LinkUp phones creates a group if its device ID is the lowest among them. One phone hosts, so two phones never create competing groups at the same moment.
   - A host with nobody joined that sees a host with a lower ID gives up its group and joins that one, so separate groups merge.
2. **Joining uses the advertised credentials** on Android 10+, with no dialog. On Android 8–9 the joining phone connects by MAC address and the host sees Android's *Accept* dialog.
3. **The group is just another LAN.** The bridge reports `p2p-…` interfaces as kind `wifiDirect`; discovery, connections and file transfer run over them unchanged. In Wi-Fi Direct mode the process is **not** bound to the joined Wi-Fi, so `192.168.49.x` is reachable through Android's local-network routes.
4. **Permission is asked only when Wi-Fi Direct is chosen**, and the status card explains what is missing (Wi-Fi off, permission, Location off, not supported).
5. The group is removed when the app stops or the user switches to another method.

## Consequences

- No new protocol: PROTOCOL.md is unchanged, and every test of the packet layer still applies.
- The passphrase travels in plain text in the service record. This matches the v1.0 trust model (ADR-0022): anyone nearby running LinkUp may join, as on a shared Wi-Fi.
- Service discovery on Android is known to be unreliable on some phones, so the bridge repeats it while no group exists, and the plan's device tests (P13.4) cover it on the testbed phones.
- The emulator has no Wi-Fi Direct; it shows *not supported*. Real behaviour is checked on phones (P13.1, P13.4).
