## Current Implementation: TCP Sockets with TLS

FileFlow uses **SecureSocket** (TLS over TCP) for the following reasons:

### 1. **LAN-Only Scope**
The app is designed for **local network transfers only** using UDP multicast for peer discovery. Devices must be on the same network, so there's no need for NAT traversal or STUN/TURN servers that WebRTC provides.

### 2. **Simplicity**
- Direct socket connections are simpler to implement and debug
- No need for signaling servers or ICE candidate exchange
- Less overhead - just TLS handshake and direct data transfer
- Easier error handling with straightforward connection states

### 3. **Reliable Ordered Delivery**
- TCP guarantees ordered, reliable delivery of chunks
- Perfect for file transfers where integrity matters
- No need to handle packet loss or reordering that UDP (WebRTC data channels) would require

### 4. **Lower Latency for LAN**
- On local networks, TCP has minimal overhead
- No STUN/TURN server round trips
- Direct peer-to-peer without signaling complexity

### 5. **Resource Efficiency**
- Smaller library footprint (built-in Dart sockets vs WebRTC dependencies)
- Lower battery consumption on mobile devices
- No media stack overhead (WebRTC is optimized for audio/video)

## WebRTC is Planned for Future

[README.md](/README.md)
> **WebRTC is planned for v1.1**:
> - [ ] WebRTC support for cross-network transfers

[ARCHITECTURE.md](/docs/ARCHITECTURE.md)
> 1. **WebRTC for internet transfers**
>    - Punch through NAT  
>    - Peer-to-peer over internet

So WebRTC would be added to enable transfers **across different networks** (internet), while keeping sockets for fast, simple LAN transfers.