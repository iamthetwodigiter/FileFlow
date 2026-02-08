# FileFlow Architecture Deep Dive

This document explains how FileFlow is structured and why certain design decisions were made.

---

## Overview

FileFlow uses **Clean Architecture** with feature-based organization. This means:
- Features are self-contained modules
- Business logic is separated from UI
- Data sources are abstracted behind repositories
- Dependencies point inward (views depend on viewmodels, viewmodels depend on repositories)

---

## Layer Structure

```
┌─────────────────────────────────────────┐
│           Presentation Layer            │  ← UI (Views)
│   (Flutter Widgets, Screens)            │
└──────────────┬──────────────────────────┘
               │ depends on
┌──────────────▼──────────────────────────┐
│         Business Logic Layer            │  ← ViewModels
│   (StateNotifiers, Use Cases)           │
└──────────────┬──────────────────────────┘
               │ depends on
┌──────────────▼──────────────────────────┐
│            Data Layer                   │  ← Repositories
│   (Repositories, Services)              │
└──────────────┬──────────────────────────┘
               │ uses
┌──────────────▼──────────────────────────┐
│         External Systems                │  ← Network, Database, File System
│   (Sockets, Hive, File I/O)             │
└─────────────────────────────────────────┘
```

---

## Core Patterns

### 1. Repository Pattern

**Purpose**: Abstract data sources

**Example**: `ConnectionRepository`
```dart
class ConnectionRepository {
  // Network operations
  Future<void> connect(String ip, int port) { }
  Future<void> sendFile(File file) { }
  
  // Event streams
  Stream<TransferEvent> get eventStream;
  Stream<double> get progressStream;
}
```

**Benefits**:
- ViewModel doesn't care if data comes from socket, database, or file
- Easy to swap implementations (testing, different backends)
- Single source of truth for data operations

### 2. State Management (Riverpod + StateNotifier)

**Purpose**: Reactive state updates

**Flow**:
```
View                   ViewModel              Repository
  │                        │                       │
  ├──watch(provider)───────►                       │
  │                        │                       │
  │                        ├──call method──────────►
  │                        │                       │
  │                        │◄──data/events─────────┤
  │                        │                       │
  │                        ├─state = newState      │
  │                        │                       │
  │◄──rebuild────────state changed                 │
  │                        │                       │
```

**Example**:
```dart
// View
final state = ref.watch(connectionViewModelProvider);

// ViewModel
class ConnectionViewModel extends StateNotifier<ConnectionState> {
  void sendFiles(List<File> files) {
    state = state.copyWith(status: ConnectionStatus.transferring);
    _repo.sendFiles(files);
  }
}
```

**Benefits**:
- Immutable state (easier to debug)
- Automatic UI rebuilds when state changes
- Clear dependency graph
- Easy to test (no UI coupling)

### 3. Event-Driven Communication

**Purpose**: Decouple repository from viewmodel

**How it works**:
```dart
// Repository publishes events
_eventController.add(TransferEvent(
  type: TransferEventType.transferComplete,
  data: {'fileName': fileName}
));

// ViewModel subscribes
_repo.eventStream.listen((event) {
  if (event.type == TransferEventType.transferComplete) {
    state = state.copyWith(status: ConnectionStatus.connected);
  }
});
```

**Benefits**:
- Repository doesn't need reference to viewmodel
- Multiple listeners possible
- Asynchronous by nature (fits network operations)
- Clear event types (self-documenting)

### 4. Dependency Injection (Riverpod Providers)

**Purpose**: Manage object lifecycle and dependencies

**Setup**:
```dart
// Define providers
final connectionRepositoryProvider = Provider((ref) {
  return ConnectionRepository(ref.read(settingsRepositoryProvider));
});

final connectionViewModelProvider = StateNotifierProvider((ref) {
  return ConnectionViewModel(ref.read(connectionRepositoryProvider));
});

// Use in view
final viewModel = ref.read(connectionViewModelProvider.notifier);
```

**Benefits**:
- No manual object creation
- Automatic disposal
- Easy to override for testing
- Compile-time safety

---

## Feature Module Structure

Each feature (discovery, transfer, history, settings) follows the same pattern:

```
feature_name/
├── model/              # Data classes
│   └── my_data.dart   # Plain Dart classes with fromMap/toMap
│
├── repository/         # Data access
│   └── my_repository.dart  # Talks to external systems
│
├── viewmodel/          # Business logic
│   └── my_viewmodel.dart   # StateNotifier with state class
│
├── view/               # UI
│   └── my_screen.dart  # ConsumerWidget or StatelessWidget
│
└── provider/           # Riverpod glue
    └── my_provider.dart    # Provider definitions
```

### Example: Transfer Feature

```
transfer/
├── model/
│   ├── transfer_event.dart      # Events from repository
│   ├── transfer_state.dart      # Persistent state for resume
│   └── transfer_item.dart       # Queue item
│
├── repository/
│   ├── connection_repository.dart       # Socket I/O, TLS
│   └── transfer_state_repository.dart   # Hive storage
│
├── viewmodel/
│   └── connection_viewmodel.dart  # Orchestrates everything
│
├── view/
│   └── transfer_screen.dart       # UI
│
└── provider/
    └── transfer_provider.dart     # Providers
```

---

## Data Flow Examples

### Discovery Flow

```
User opens app
    ↓
DiscoveryScreen builds
    ↓
Watches peerListProvider
    ↓
DiscoveryViewModel.init()
    ↓
DiscoveryRepository.registerService() → Broadcasts via UDP multicast
DiscoveryRepository.startScanning() → Listens for UDP packets
    ↓
Receives UDP broadcasts → Parses device info → Stream emits
    ↓
ViewModel updates state
    ↓
View rebuilds with peer list
```

### File Transfer Flow

```
User selects files
    ↓
ConnectionViewModel.sendFiles(files)
    ↓
State = awaitingTransferAcceptance
    ↓
ConnectionRepository.requestTransfer()
    ↓
Send TransferEvent.transferRequested over socket
    ↓
Receiver gets event → UI shows dialog
    ↓
User accepts
    ↓
ConnectionViewModel.acceptTransfer()
    ↓
ConnectionRepository.sendTransferResponse(true)
    ↓
Send TransferEvent.transferAccepted over socket
    ↓
Sender receives acceptance
    ↓
ConnectionRepository._processTransferQueue()
    ↓
For each file:
  - Send metadata
  - Send chunks (64KB each)
  - Update progress stream
    ↓
Progress stream → ViewModel → State update → View shows progress
    ↓
All files sent
    ↓
Send TransferEvent.transferComplete
    ↓
Both sides save to history
```

---

## Key Components Explained

### 1. Certificate Service

**What**: Generates self-signed X.509 certificates for TLS

**Why**: Encrypted connections without certificate authority

**How**:
- Runs in isolate (doesn't block UI)
- Uses PointyCastle for RSA-2048
- Caches certificate for session
- Provides SecurityContext for sockets

**Code**: `lib/core/services/certificate_service.dart`

### 2. Connection Repository

**What**: Manages network connections and file transfers

**Why**: Separates socket I/O from business logic

**Responsibilities**:
- Start TLS server
- Connect to peers
- Send/receive files
- Handle pause/resume
- Track progress

**Code**: `lib/features/transfer/repository/connection_repository.dart`

### 3. Notification Service

**What**: Shows Android/iOS notifications

**Why**: Keep user informed, especially when app backgrounded

**Types**:
- Connection events
- Transfer requests
- Progress updates
- Completion/errors

**Code**: `lib/core/services/notification_service.dart`

### 4. Hive Databases

**What**: Local NoSQL database

**Why**: Fast, no SQL needed, works offline

**Usage**:
- Settings (device name, PIN preference)
- History (past transfers)
- Transfer state (for resume)

**Models need TypeAdapters**: Generated with `build_runner`

---

## Security Architecture

```
Application Data
    ↓
JSON/Binary Encoding
    ↓
TLS Record Layer (AES-128/256-GCM encryption)
    ↓
TCP Socket
    ↓
Network
```

### TLS Handshake

```
Client                          Server
  │                               │
  ├──ClientHello─────────────────►│
  │                               │
  │◄────────────────ServerHello──┤
  │◄─────────────Certificate──────┤ (self-signed)
  │◄──────ServerHelloDone─────────┤
  │                               │
  ├──ClientKeyExchange──────────►│
  ├──ChangeCipherSpec───────────►│
  ├──Finished───────────────────►│
  │                               │
  │◄─────ChangeCipherSpec─────────┤
  │◄───────────Finished───────────┤
  │                               │
  ├──Encrypted Application Data─►│
  │◄─Encrypted Application Data──┤
```

### PIN Authentication

```
Server                          Client
  │                               │
  │◄─────ConnectionRequest────────┤ (includes PIN if required)
  │                               │
  ├─Verify PIN                    │
  │                               │
  │──ConnectionAccepted─────────►│ (if valid)
  │──ConnectionRejected─────────►│ (if invalid)
```

---

## Performance Considerations

### Isolate Usage

Heavy CPU operations run in isolates to prevent UI jank:

```dart
// Certificate generation (500ms)
await compute(_generateCertInIsolate, 'params');

// File hashing (if implemented)
await compute(_hashFile, file.path);
```

### Chunked Transfer

Files sent in 64KB chunks:
- Prevents memory overflow for large files
- Allows progress tracking
- Enables pause/resume

### Stream-Based Progress

```dart
// Repository emits progress
_progressController.add(bytesTransferred / totalBytes);

// ViewModel listens
_repo.progressStream.listen((progress) {
  state = state.copyWith(transferProgress: progress);
});

// View watches
final progress = state.transferProgress;
```

### Caching

- **Certificates**: Cached for app session
- **Device Info**: Fetched once at startup
- **Discovered Peers**: Cached until scan refresh

---

## Error Handling Strategy

### Exception Hierarchy

```
AppException (base)
    ├── ConnectionException
    │   ├── ConnectionFailed
    │   ├── ConnectionTimeout
    │   └── PeerDisconnected
    ├── TransferException
    │   ├── TransferFailed
    │   ├── TransferCancelled
    │   └── TransferRejected
    ├── FileSystemException
    │   ├── FileNotFound
    │   ├── InsufficientStorage
    │   └── PermissionDenied
    └── DiscoveryException
```

### Error Propagation

```
Repository throws → ViewModel catches → State updated → View shows error

try {
  await _repo.sendFile(file);
} on TransferException catch (e) {
  state = state.copyWith(
    status: ConnectionStatus.error,
    errorMessage: e.message
  );
  _notificationService.showError(e.title, e.message);
}
```

---

## State Persistence

### Transfer Resume

If app closes during transfer:

1. `TransferStateRepository.saveState()` stores:
   - File path
   - Total bytes
   - Transferred bytes
   - Peer address
   - Transfer ID

2. On restart:
   - `getIncompleteTransfers()` queries Hive
   - User can choose to resume or delete

3. Resume:
   - Open file in append mode
   - Seek to `transferredBytes` offset
   - Continue from there

### Settings

Persisted to Hive:
- Device name
- PIN requirement
- Dark mode (future)

Loaded on app start in `main.dart`.

---

## Testing Strategy

### Unit Tests

Test repositories and viewmodels:
```dart
test('ConnectionViewModel sends file', () async {
  final mockRepo = MockConnectionRepository();
  final viewModel = ConnectionViewModel(mockRepo);
  
  await viewModel.sendFiles([file]);
  
  verify(mockRepo.requestTransfer(any)).called(1);
  expect(viewModel.state.status, ConnectionStatus.transferring);
});
```

### Widget Tests

Test UI components:
```dart
testWidgets('TransferScreen shows progress', (tester) async {
  await tester.pumpWidget(MyApp());
  await tester.tap(find.text('Send Files'));
  await tester.pump();
  
  expect(find.byType(CircularProgressIndicator), findsOneWidget);
});
```

### Integration Tests

Test full flows:
```dart
testWidgets('Complete file transfer', (tester) async {
  // Start server on one instance
  // Connect from another
  // Send file
  // Verify received
});
```

---

## Design Decisions

### Why Riverpod over Provider/BLoC?

- **Type-safe**: Compile-time errors
- **No BuildContext**: Access anywhere
- **Autodispose**: Automatic cleanup
- **Testing**: Easy to mock

### Why Hive over SQLite?

- **NoSQL**: No schema migrations
- **Fast**: Binary format
- **Simple**: No SQL syntax
- **Cross-platform**: Works everywhere
- **Type-safe**: Generated adapters

### Why self-signed certificates?

- **No CA needed**: Works offline
- **LAN-only**: Don't need public trust
- **Simple**: Generate on-the-fly
- **Secure enough**: With PIN authentication

### Why UDP Multicast?

- **Cross-platform**: Works uniformly on Android, iOS, Linux, macOS, Windows
- **Simple**: No platform-specific native code required
- **Automatic**: Zero-configuration device discovery
- **LAN-only**: Security by network isolation (multicast doesn't route beyond LAN)
- **Efficient**: 3-second broadcast interval, 10-second peer timeout

**Technical Details:**
- Multicast address: `239.255.12.34` (administratively scoped)
- Port: `26841`
- Android requires WifiManager.MulticastLock
- Replaced NSD/mDNS for better Linux compatibility

---

## Future Improvements

1. **WebRTC for internet transfers**
   - Punch through NAT
   - Peer-to-peer over internet

2. **End-to-end file encryption**
   - AES-256 file encryption
   - Separate from TLS

3. **Certificate pinning**
   - Trust on first use (TOFU)
   - Store peer certificates

4. **Mesh networking**
   - Multi-hop transfers
   - Route through trusted peers

5. **Compression**
   - Gzip/Brotli before transfer
   - Especially for text files

---