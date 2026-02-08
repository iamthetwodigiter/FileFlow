<div align="center">

# 📁 FileFlow

### Secure Peer-to-Peer File Transfer Made Simple

[![Flutter](https://img.shields.io/badge/Flutter-3.38.6+-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.10.7+-0175C2?logo=dart)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Linux%20%7C%20macOS%20%7C%20Windows-grey)](https://flutter.dev)
[![Downloads](https://img.shields.io/github/downloads/iamthetwodigiter/FileFlow/total?color=success)](https://github.com/iamthetwodigiter/FileFlow/releases)

*Cross-platform file transfer with TLS encryption and automatic peer discovery.*

[Features](#-features) • [Architecture](#-architecture) • [Security](#-security) • [Installation](#-installation) • [Usage](#-usage) • [Documentation](#-documentation)

</div>

---

## 📖 Table of Contents

- [Overview](#-overview)
- [Key Features](#-features)
- [Technical Architecture](#-architecture)
- [Security Implementation](#-security)
- [Problem-Solution Approach](#-problem--solution)
- [Installation](#-installation)
- [Usage Guide](#-usage)
- [Project Structure](#-project-structure)
- [Dependencies](#-dependencies)
- [Platform Support](#-platform-support)
- [Development](#-development)
- [Documentation](#-documentation)
- [Roadmap](#-roadmap)
- [Contributing](#-contributing)
- [License](#-license)

---

## 🎯 Overview

FileFlow is a peer-to-peer file transfer application for local networks. Built with Flutter, it provides secure file sharing between devices without cloud services.

**Key Benefits:**
- No cloud storage or third-party servers
- TLS encryption with RSA-2048 + SHA-256
- Automatic peer discovery via UDP multicast
- Cross-platform (Android, iOS, Linux, macOS, Windows)
- State persistence and transfer resume

---

## ✨ Features

### Core Capabilities

#### 🔍 **Automatic Peer Discovery**
- **UDP Multicast Discovery**: Zero-configuration network discovery on multicast group 239.255.12.34:26841
- **Cross-Platform Compatible**: Works seamlessly across Android, iOS, Linux, macOS, and Windows
- **Real-Time Updates**: Live peer list updates as devices join or leave the network (10-second timeout)
- **Device Metadata**: Broadcast and receive device name, model, OS, version, and PIN requirement status
- **Smart Filtering**: Automatically excludes self from peer list to prevent self-connections
- **Peer Timeout**: Stale peers automatically removed after 10 seconds of inactivity

#### 🔐 **Advanced Security**
- **TLS Encryption**: All data transmitted over encrypted TLS 1.3 channels
- **Self-Signed Certificates**: Dynamically generated X.509 v3 certificates with RSA-2048 keys
- **PIN Authentication**: Optional 6-digit PIN verification for connection establishment
- **Certificate Caching**: Session-based certificate reuse for consistent device identity
- **Secure Random Generation**: Cryptographically secure random number generator for key material

#### 🚀 **High-Performance Transfer**
- **Chunked Transfer Protocol**: Efficient 64KB chunk-based streaming for optimal throughput
- **Real-Time Progress**: Live transfer speed (KB/s, MB/s, GB/s) and progress percentage
- **Pause & Resume**: Interrupt and resume transfers from exact byte position
- **Batch Transfers**: Send multiple files or entire folders in a single session
- **Background Service**: Android foreground service keeps transfers alive when app is minimized

#### 📊 **Transfer Management**
- **Queue System**: Visualize pending, active, and completed transfers in the queue
- **Transfer History**: Persistent Hive database tracks all sent/received files with timestamps
- **Speed Calculation**: Real-time transfer speed with exponential moving average smoothing
- **State Recovery**: Resume interrupted transfers after app restart or crash
- **Cancellation**: Cancel transfers from either sender or receiver side with cleanup

#### 🔔 **Smart Notifications**
- **Connection Events**: Notifications for connection requests, acceptance, and rejection
- **Transfer Requests**: High-priority notifications for incoming file requests
- **Progress Updates**: Real-time progress notifications with percentage and speed
- **Completion Alerts**: Success or failure notifications with file details
- **Pause/Resume Events**: Notifications when transfers are paused or resumed

#### 📱 **User Experience**
- **Intuitive UI**: Clean Material Design 3 interface with Google Fonts
- **QR Code Sharing**: Generate QR codes for connection info (IP, Port, PIN)
- **QR Scanner**: Scan peer QR codes for quick connection without manual entry
- **Drag & Drop**: Desktop support for dragging files directly into the app
- **Share Intent**: Receive files from other apps via Android Share Intent
- **Clipboard Sharing**: Send text from clipboard to connected peers

#### 🛡️ **Reliability & Error Handling**
- **Comprehensive Exception Handling**: Custom exception hierarchy for all error types
- **Automatic Retry**: Configurable retry logic for transient network failures
- **Graceful Degradation**: Partial transfer recovery without restarting from zero
- **Resource Cleanup**: Proper socket, file, and stream cleanup on errors
- **User Notifications**: Clear error messages with actionable guidance

---

## 🏗️ Architecture

FileFlow follows **Clean Architecture** principles with clear separation of concerns:

```
lib/
├── core/                      # Shared utilities and services
│   ├── services/
│   │   ├── certificate_service.dart    # X.509 certificate generation
│   │   ├── pin_auth_service.dart       # PIN generation & verification
│   │   ├── notification_service.dart   # Platform notifications
│   │   └── background_transfer_service.dart  # Foreground service
│   ├── models/                # Shared data models
│   ├── exceptions/            # Custom exception classes
│   ├── utils/                 # Helper functions
│   └── theme/                 # App theming
│
├── features/                  # Feature modules
│   ├── discovery/            # Peer discovery
│   │   ├── model/           # Peer data model
│   │   ├── repository/      # UDP multicast discovery
│   │   ├── viewmodel/       # Business logic
│   │   └── view/            # UI components
│   │
│   ├── transfer/            # File transfer
│   │   ├── model/          # Transfer events & states
│   │   ├── repository/     # Socket connection & file I/O
│   │   ├── viewmodel/      # Transfer orchestration
│   │   └── view/           # Transfer UI
│   │
│   ├── history/            # Transfer history
│   ├── settings/           # App settings
│   └── home/              # Main screen
│
└── main.dart              # App entry point
```

### Architecture Patterns

#### **1. Repository Pattern**
Abstracts data sources (network, database, file system) behind clean interfaces:
- `DiscoveryRepository`: Manages UDP multicast broadcasting and peer discovery
- `ConnectionRepository`: Handles socket connections and data transfer
- `HistoryRepository`: Persists transfer history with Hive
- `SettingsRepository`: Manages app preferences
- `TransferStateRepository`: Stores partial transfer states for recovery

#### **2. State Management (Riverpod)**
Uses `flutter_riverpod` for reactive state management:
- **StateNotifier**: Immutable state updates with change notifications
- **Provider**: Dependency injection and lifecycle management
- **StreamProvider**: Real-time data streams from repositories

#### **3. Event-Driven Communication**
Decouples UI from business logic using event streams:
```dart
Stream<TransferEvent> eventStream;  // Repository events
Stream<double> progressStream;       // Transfer progress
Stream<double> speedStream;          // Transfer speed
```

#### **4. Isolate-Based Computation**
CPU-intensive operations run in background isolates to prevent UI blocking:
- **Certificate Generation**: RSA-2048 key pair generation (~500ms)
- **File Hashing**: SHA-256 checksums for integrity verification
- **Data Encoding**: ASN.1 DER encoding for X.509 structures

---

## 🔒 Security

FileFlow implements a **defense-in-depth** security model:

### Encryption Stack

#### **1. Transport Layer Security (TLS)**
```
Application Data
       ↓
TLS Record Layer (encryption, MAC)
       ↓
TCP Socket
       ↓
Network
```

- **Protocol**: TLS 1.2+ (supports TLS 1.3 where available)
- **Cipher Suites**: Platform-specific secure defaults
- **Forward Secrecy**: Ephemeral Diffie-Hellman key exchange
- **Message Authentication**: HMAC-SHA256 for integrity verification

#### **2. Certificate Infrastructure**

**Self-Signed X.509 v3 Certificates:**
```
Certificate Structure:
├─ Version: 3
├─ Serial Number: Random 32-bit integer
├─ Signature Algorithm: SHA256withRSA (OID: 1.2.840.113549.1.1.11)
├─ Issuer DN: CN=FileFlow
├─ Validity: 365 days from generation
├─ Subject DN: CN=FileFlow (self-signed)
├─ Public Key:
│   ├─ Algorithm: RSA Encryption (OID: 1.2.840.113549.1.1.1)
│   ├─ Modulus: 2048 bits (~617 decimal digits)
│   └─ Exponent: 65537 (standard)
└─ Signature: 256 bytes (RSA-2048)
```

**Why Self-Signed?**
- No dependency on Certificate Authorities (CAs)
- Perfect for LAN-only communication
- Regenerated per session for enhanced security
- Verified via out-of-band PIN authentication

**Generation Process:**
1. **Entropy Collection**: 32 bytes from `Random.secure()`
2. **PRNG Seeding**: Fortuna random with cryptographic seed
3. **Key Generation**: RSA KeyPairGenerator with 2048-bit modulus
4. **Certificate Encoding**: ASN.1 DER encoding per X.509 standard
5. **PEM Conversion**: Base64 encoding with line breaks
6. **Signature**: SHA-256 hash + PKCS#1 v1.5 padding

I had the most fun and learnings coding [CertificateService class](lib/core/services/certificate_service.dart) — it's a complete implementation of X.509 certificate generation from scratch using low-level ASN.1 DER encoding, RSA cryptography, and PEM formatting. This was a deep dive into public key infrastructure (PKI) internals.

#### **3. PIN Authentication**
- **Length**: 6 digits (1,000,000 combinations)
- **Generation**: Cryptographically secure random
- **Verification**: Constant-time comparison to prevent timing attacks
- **Session-Based**: New PIN per connection session
- **Optional**: User-configurable requirement

### Threat Mitigation

| Threat | Mitigation Strategy |
|--------|---------------------|
| **Eavesdropping** | TLS 1.2+ encryption with AES-128/256-GCM |
| **Man-in-the-Middle** | PIN-based out-of-band verification |
| **Packet Tampering** | HMAC-SHA256 integrity checks |
| **Replay Attacks** | Transfer ID validation + timestamp verification |
| **Certificate Spoofing** | PIN authentication on initial handshake |
| **Brute Force** | Connection rate limiting + session timeouts |
| **Data Exfiltration** | No cloud storage, LAN-only operation |

### Security Properties

✅ **Confidentiality**: All data encrypted in transit via TLS  
✅ **Integrity**: Message authentication codes prevent tampering  
✅ **Authentication**: PIN verification for device identity  
✅ **Non-Repudiation**: Transfer history with timestamps  
✅ **Forward Secrecy**: Ephemeral key exchange in TLS layer  

❌ **Not Provided** (by design for LAN use-case):  
- Certificate pinning (session-based certificates)
- Certificate chain validation (no CA infrastructure)
- Revocation checking (single-session certificates)

---

## 💡 Problem → Solution

### Problem 1: **Slow Cloud Uploads/Downloads**
**Scenario**: Transferring large files (videos, backups) to nearby devices via cloud services is slow due to upload → server → download path.

**FileFlow Solution**: Direct peer-to-peer transfer over LAN achieves:
- **Speed**: 10-100 MB/s on local WiFi (vs. 1-5 MB/s cloud)
- **No Data Caps**: No internet bandwidth consumption
- **Instant**: No upload wait time

---

### Problem 2: **Privacy Concerns with Cloud Storage**
**Scenario**: Users don't want personal files (documents, photos) stored on third-party servers.

**FileFlow Solution**:
- **Zero Cloud Storage**: Files never leave local network
- **End-to-End Encryption**: Even if intercepted, data is encrypted
- **No Tracking**: No user accounts, analytics, or metadata collection

---

### Problem 3: **Complex Network Configuration**
**Scenario**: Traditional P2P apps require manual IP entry, port forwarding, and firewall rules.

**FileFlow Solution**:
- **UDP Multicast**: Automatic peer discovery without configuration, cross-platform compatible
- **Single Port**: Uses port 4000 with no port forwarding needed (LAN)
- **QR Code**: Scan to connect without typing IP addresses

---

### Problem 4: **Unreliable Transfers**
**Scenario**: Large file transfers fail when connection drops, requiring restart from zero.

**FileFlow Solution**:
- **Pause & Resume**: Resume from exact byte position after interruption
- **State Persistence**: Save transfer state to Hive database
- **Auto-Recovery**: Detect partial transfers on app restart
- **Graceful Cancellation**: Clean up resources properly

---

### Problem 5: **Poor Mobile UX**
**Scenario**: Background transfers fail when app is minimized on mobile.

**FileFlow Solution**:
- **Foreground Service**: Android service keeps transfers alive
- **Progress Notifications**: See transfer status from notification bar
- **Background Persistence**: Transfers continue when app is backgrounded

---

## 📥 Installation

### Prerequisites

- **Flutter SDK**: 3.38.6 or higher
- **Dart SDK**: 3.10.7 or higher
- **Platform-Specific Requirements**:
  - **Android**: Android Studio with API level 21+ (Android 5.0 Lollipop)
  - **iOS**: Xcode 14+ with iOS 12+
  - **Linux**: GTK 3.0, Clang
  - **macOS**: Xcode 14+
  - **Windows**: Visual Studio 2022 with C++ desktop development

### Build from Source

```bash
# Clone the repository
git clone https://github.com/iamthetwodigiter/FileFlow.git
cd FileFlow

# Install dependencies
flutter pub get

# Run code generation (for Hive adapters)
flutter pub run build_runner build --delete-conflicting-outputs

# Run on your platform
flutter run                    # Debug mode
flutter run --release          # Release mode
```

### Platform-Specific Builds

#### Android APK/Bundle
```bash
flutter build apk --release           # APK for sideloading
flutter build appbundle --release     # AAB for Play Store
```

#### iOS IPA
```bash
flutter build ios --release
# Open Xcode for archiving and distribution
```

#### Linux
```bash
flutter build linux --release
```

#### macOS
```bash
flutter build macos --release
```

#### Windows
```bash
flutter build windows --release
```

### Install APK (Android)
```bash
# Install to connected device
flutter install

# Or manually install APK
adb install build/app/outputs/flutter-apk/app-release.apk
```

---

## 🚀 Usage

### Quick Start Guide

#### 1. **Start Discovery**
   - Open FileFlow on both devices
   - App automatically broadcasts presence via UDP multicast every 3 seconds
   - Peer list populates with nearby devices

#### 2. **Connect to Peer**
   - **Option A**: Tap peer in discovery list
   - **Option B**: Scan QR code from peer's screen
   - **Option C**: Enter IP and port manually
   - If PIN required, enter 6-digit PIN displayed on receiver

#### 3. **Send Files**
   - Tap **"Send Files"** and select files
   - Or tap **"Send Folder"** to send entire directory
   - Or use **"Share to FileFlow"** from other apps
   - Receiver accepts or rejects transfer request

#### 4. **Monitor Transfer**
   - View real-time progress, speed, and ETA
   - Pause/resume transfer as needed
   - Cancel if required

#### 5. **View History**
   - Check **History** tab for all transfers
   - Filter by sent/received
   - View timestamps, file sizes, and peer info

### Advanced Features

#### **QR Code Connection**
1. Go to **Settings** → **Show QR Code**
2. Peer scans QR code with **Discovery** → **Scan QR**
3. Connection established instantly

#### **PIN Protection**
1. Enable in **Settings** → **Require PIN**
2. 6-digit PIN displayed when peer connects
3. Connecting peer must enter PIN to proceed

#### **Clipboard Sharing**
1. Connect to peer
2. Copy text to clipboard
3. Tap **"Send Clipboard"** on Transfer screen
4. Peer receives text instantly

#### **Drag & Drop (Desktop)**
1. Connect to peer
2. Drag files from file explorer into FileFlow window
3. Files automatically queued for transfer

---

## 📂 Project Structure

```
FileFlow/
├── android/                   # Android native code
│   └── app/src/main/kotlin/
│       └── TransferService.kt # Foreground service
├── ios/                       # iOS native code
├── lib/
│   ├── core/
│   │   ├── app/
│   │   │   └── fileflow_app.dart
│   │   ├── constants/
│   │   │   └── app_constants.dart
│   │   ├── exceptions/
│   │   │   └── app_exceptions.dart
│   │   ├── models/
│   │   │   └── device_info.dart
│   │   ├── providers/
│   │   │   └── providers.dart
│   │   ├── services/
│   │   │   ├── background_transfer_service.dart
│   │   │   ├── certificate_service.dart  # ⭐ Core security
│   │   │   ├── notification_service.dart
│   │   │   └── pin_auth_service.dart
│   │   ├── theme/
│   │   │   └── app_theme.dart
│   │   └── utils/
│   │       ├── get_device_info.dart
│   │       └── packet_reader.dart
│   │
│   ├── features/
│   │   ├── discovery/
│   │   │   ├── model/peer.dart
│   │   │   ├── repository/discovery_repository.dart
│   │   │   ├── viewmodel/discovery_viewmodel.dart
│   │   │   ├── view/discovery_screen.dart
│   │   │   └── provider/discovery_provider.dart
│   │   │
│   │   ├── transfer/
│   │   │   ├── model/
│   │   │   │   ├── transfer_event.dart
│   │   │   │   ├── transfer_item.dart
│   │   │   │   └── transfer_state.dart
│   │   │   ├── repository/
│   │   │   │   ├── connection_repository.dart  # ⭐ Core transfer logic
│   │   │   │   └── transfer_state_repository.dart
│   │   │   ├── viewmodel/connection_viewmodel.dart
│   │   │   ├── view/transfer_screen.dart
│   │   │   └── provider/transfer_provider.dart
│   │   │
│   │   ├── history/
│   │   │   ├── model/history_item.dart
│   │   │   ├── repository/history_repository.dart
│   │   │   ├── viewmodel/history_viewmodel.dart
│   │   │   └── view/history_screen.dart
│   │   │
│   │   ├── settings/
│   │   │   ├── repository/settings_repository.dart
│   │   │   ├── viewmodel/settings_viewmodel.dart
│   │   │   └── view/settings_screen.dart
│   │   │
│   │   └── home/
│   │       └── view/home_screen.dart
│   │
│   └── main.dart
│
├── docs/
│   ├── CERTIFICATE_SERVICE_DOCUMENTATION.md  # Detailed crypto docs
│   ├── IMPLEMENTATION_GUIDE.md              # Feature implementation
│   └── SECURITY_AND_FUNCTIONALITY_VERIFICATION.md
│
├── pubspec.yaml               # Dependencies
└── README.md                  # This file
```

---

## 📦 Dependencies

### Core Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_riverpod` | ^3.2.0 | State management |
| `hive_flutter` | ^1.1.0 | Local database |
| ~~`nsd`~~ | ~~^4.1.0~~ | ~~Removed~~ (migrated to UDP multicast for Linux support) |
| `pointycastle` | ^4.0.0 | Cryptography (RSA, SHA-256) |
| `shelf` | ^1.4.2 | HTTP server (for QR endpoints) |
| `file_picker` | ^10.3.10 | File selection |
| `permission_handler` | ^12.0.1 | Runtime permissions |
| `qr_flutter` | ^4.1.0 | QR code generation |
| `mobile_scanner` | ^7.1.4 | QR code scanning |
| `desktop_drop` | ^0.7.0 | Drag & drop (desktop) |
| `receive_sharing_intent` | ^1.8.1 | Share intent (mobile) |
| `network_info_plus` | ^7.0.0 | Network information |
| `device_info_plus` | ^12.3.0 | Device details |
| `path_provider` | ^2.1.5 | File system paths |
| `google_fonts` | ^8.0.1 | Typography |

### Dev Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `build_runner` | ^2.4.13 | Code generation |
| `hive_generator` | ^2.0.1 | Hive type adapters |
| `flutter_lints` | ^6.0.0 | Linting rules |

---

## 🖥️ Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| **Android** | ✅ Fully Supported | API 21+ (Android 5.0+) |
| **iOS** | ℹ️ To be Tested Soon | iOS 12+ |
| **Linux** | ℹ️ To be Tested Soon | Ubuntu 20.04+ |
| **macOS** | ℹ️ To be Tested Soon | macOS 10.14+ |
| **Windows** | ℹ️ To be Tested Soon | Windows 10+ |
| **Web** | ⚠️ Limited | UDP multicast not supported in browsers |

### Platform-Specific Features

- **Android**: Foreground service, share intent, notification actions
- **iOS**: Background fetch, CallKit integration (planned)
- **Desktop**: Drag & drop, system tray (planned)
- **Web**: WebRTC fallback (planned)

---

## 🛠️ Development

### Running Tests
```bash
flutter test                   # Unit tests
flutter test --coverage        # With coverage report
```

### Code Generation
```bash
# Regenerate Hive adapters after model changes
flutter pub run build_runner build --delete-conflicting-outputs

# Watch mode for continuous generation
flutter pub run build_runner watch
```

### Debugging

#### Enable Verbose Logging
All debug prints use Flutter's `debugPrint()` with emoji prefixes:
- 🚀 Network events
- 📁 File operations
- 🔐 Security events
- ⏸️ Transfer pauses
- ▶️ Transfer resumes
- ✅ Success operations
- ❌ Errors

#### Debug TLS Handshake
```dart
// In connection_repository.dart
_socket = await SecureSocket.connect(
  ip,
  port,
  context: context,
  onBadCertificate: (cert) {
    debugPrint('Certificate: ${cert.pem}');
    return true;  // Accept self-signed
  },
);
```

#### Monitor Transfer State
```dart
// Watch transfer state changes
ref.listen(connectionViewModelProvider, (previous, next) {
  debugPrint('Status: ${previous?.status} → ${next.status}');
});
```

### Performance Profiling

```bash
# Run with performance overlay
flutter run --profile

# Generate timeline trace
flutter run --profile --trace-startup --verbose
```

---

## 📚 Documentation

Detailed technical documentation in the `docs/` directory:

- **[ARCHITECTURE.md](docs/ARCHITECTURE.md)** - Clean Architecture patterns, layer structure, and design decisions
- **[IMPLEMENTATION_GUIDE.md](docs/IMPLEMENTATION_GUIDE.md)** - Feature implementation flows for connections, transfers, and notifications
- **[SECURITY_AND_FUNCTIONALITY_VERIFICATION.md](docs/SECURITY_AND_FUNCTIONALITY_VERIFICATION.md)** - Security verification and testing scenarios

---

## 🗺️ Roadmap

### Version 1.1 (Next Release)
- [ ] WebRTC support for cross-network transfers
- [ ] End-to-end file encryption option
- [ ] Transfer compression (gzip/brotli)
- [ ] System tray integration (desktop)
- [ ] Multi-peer broadcasting

### Version 1.2
- [ ] Video/audio streaming
- [ ] LAN chat messaging

---

## 🤝 Contributing

Contributions are welcome! Please read the following guidelines:

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Commit** with conventional commits (`git commit -m 'feat: add amazing feature'`)
4. **Push** to the branch (`git push origin feature/amazing-feature`)
5. **Open** a Pull Request

### Commit Convention
```
feat: New feature
fix: Bug fix
docs: Documentation changes
style: Code style changes (formatting)
refactor: Code refactoring
perf: Performance improvements
test: Test additions or updates
chore: Build process or tooling changes
```

---

## 📞 Contact & Support

- **Issues**: [GitHub Issues](https://github.com/iamthetwodigiter/FileFlow/issues)
- **Discussions**: [GitHub Discussions](https://github.com/iamthetwodigiter/FileFlow/discussions)

---

## 🙏 Acknowledgments

- **Flutter Team**: For the amazing cross-platform framework
- **Pointy Castle**: For pure-Dart cryptography implementation
- **Flutter Community**: For comprehensive cross-platform support and packages
- **Riverpod**: For elegant state management
- **Open Source Community**: For countless libraries and inspiration

---

<div align="center">

### ⭐ Star this repo if you find it helpful!

**Built with ❤️ using Flutter by [thetwodigiter](https://github.com/iamthetwodigiter)**

[Report Bug](https://github.com/iamthetwodigiter/FileFlow/issues) · [Request Feature](https://github.com/iamthetwodigiter/FileFlow/issues) · [Documentation](docs/)

</div>