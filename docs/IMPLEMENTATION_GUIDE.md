# FileFlow Implementation Guide

Complete code flow documentation for all major features.

## 1. Connection Request Handling

**Flow:** Connection Request (connectionRequest) → Accept (connectionAccepted) or Reject (connectionRejected)

### Device A (Sender)

1. User taps "Connect" on discovered peer
2. `ConnectionViewModel.connectToPeer(peer, pin?)` is called
3. `ConnectionRepository.connect(ip, port, myDeviceName, pin)` executed
4. TLS connection established via `SecureSocket.connect()`
5. Sends `TransferEventType.connectionRequest` with {deviceName, pin}
6. State becomes `ConnectionStatus.connecting`
7. Waits for response...

### Device B (Receiver)

1. `ConnectionRepository.startServer()` already listening on port 4000
2. Receives incoming SecureSocket connection
3. `_handleNewSocket()` called to listen to incoming data
4. Receives `TransferEventType.connectionRequest` event
5. If PIN required: Validates PIN with PinAuthService
6. State becomes `ConnectionStatus.awaitingConfirmation`
7. User sees connection request in UI
8. User taps "Accept" or "Reject"

### User Accepts

1. `ConnectionViewModel.acceptConnection()` called
2. `ConnectionRepository.acceptConnection(myDeviceName)` executed
3. Sends `TransferEventType.connectionAccepted` event
4. Both devices transition to `ConnectionStatus.connected`
5. Notifications sent on both sides

### User Rejects

1. `ConnectionViewModel.rejectConnection()` called
2. `ConnectionRepository.rejectConnection(reason)` executed
3. Sends `TransferEventType.connectionRejected` event
4. Both devices return to disconnected state
5. Error notification sent to connecting device

### File References

- `connection_repository.dart`: connect(), startServer(), acceptConnection(), rejectConnection()
- `connection_viewmodel.dart`: connectToPeer(), acceptConnection(), rejectConnection()
- `pin_auth_service.dart`: verifyPin(), generatePin()
- `notification_service.dart`: showConnectionEstablished(), showConnectionRejected()

---

## 2. Transfer Request Handling

**Flow:** Transfer Request → Accept (transferAccepted) or Reject (transferRejected) → Send File → Complete

### Device A (Sender)

1. User selects files (via `pickAndSendFiles()` or `pickFolder()`)
2. `ConnectionViewModel.sendFiles(fileList)` called
3. `_pendingFiles` list populated
4. State becomes `ConnectionStatus.awaitingTransferAcceptance`
5. `ConnectionRepository.requestTransferBatch(count, totalSize)` or `requestTransfer(name, size)`
6. Sends `TransferEventType.transferRequested` with metadata
7. Waits for response...

### Device B (Receiver)

1. Receives `TransferEventType.transferRequested` event
2. State becomes `ConnectionStatus.transferRequestReceived`
3. Event data contains: {fileName, fileSize, fileCount, isBatch}
4. UI shows "Transfer Request" dialog
5. User sees device name, file name(s), total size
6. User taps "Accept" or "Reject"

### User Accepts

1. `ConnectionViewModel.acceptTransfer()` called
2. `ConnectionRepository.sendTransferResponse(true)` executed
3. Sends `TransferEventType.transferAccepted` event
4. Device A receives acceptance → triggers `_processTransferQueue()`
5. State on both sides becomes `ConnectionStatus.transferring`
6. File transfer begins (see section 3)

### User Rejects

1. `ConnectionViewModel.rejectTransfer()` called
2. `ConnectionRepository.sendTransferResponse(false)` executed
3. Sends `TransferEventType.transferRejected` event
4. Device A cancels and clears pending files
5. Both devices return to connected state
6. Notification sent

### Batch Transfers

1. Device A sends ONE transferRequested with isBatch: true
2. Device B accepts ONCE
3. Device A processes queue via `_processTransferQueue()`
4. Each file triggers `sendFile()`
5. After each file: `_processTransferQueue()` called recursively
6. Until `_pendingFiles` is empty
7. Final state becomes transferCompleted

### File References

- `sendFiles()`, `pickAndSendFiles()`, `pickFolder()` in connection_viewmodel.dart
- `requestTransfer()`, `requestTransferBatch()` in connection_repository.dart
- `acceptTransfer()`, `rejectTransfer()` in connection_viewmodel.dart
- `_processTransferQueue()` for batch handling in connection_viewmodel.dart

---

## 3. File Transfer Protocol

### Protocol Overview

1. **[JSON]** fileMetadata event with {fileName, fileSize, transferID, offset}
2. **[BINARY]** File chunks streamed
3. **[JSON]** transferComplete event when done

### Step 1: Send Metadata

Device A calls `sendFile(file, offset=0)`:
- Calculates fileName and fileSize
- Creates transferID = "${fileName}_${fileSize}"
- Sends `TransferEventType.fileMetadata` with:
  - fileName: "document.pdf"
  - fileSize: 10485760
  - transferID: "document.pdf_10485760"
  - offset: 0 (for resume capability)
- Sets up speed tracking

### Step 2: Receive Metadata (Device B)

Receives fileMetadata event:
- Creates receiving file at /storage/emulated/0/FileFlow/document.pdf
- Opens file for writing
- Starts background foreground service for notification
- Initializes progress tracking variables:
  - `_totalBytes` = 10485760
  - `_receivedBytes` = 0
  - `_lastSpeedUpdate` = now()
- Saves transfer state for recovery

### Step 3: Stream File Chunks

Device A reads file in chunks:
- Opens `file.openRead(offset)`
- For each chunk:
  - Checks if paused (`_isTransferPaused`) - waits if true
  - Checks if cancelled (`_isTransferCancelled`) - breaks if true
  - Sends chunk as BINARY packet
  - Updates progress: (bytesSent / fileSize)
  - Updates notification every 1%
  - Flushes every 1MB for network efficiency
- Continues until end of file

### Step 4: Receive Chunks (Device B)

For each incoming BINARY packet:
- Writes bytes to file
- Updates `_receivedBytes += chunk.length`
- Calculates progress: `(_receivedBytes / _totalBytes)`
- Updates `_progressController.add(progress)`
- Updates notification every 1%
- Speed calculated automatically via `_updateTransferSpeed()`

### Step 5: Complete Transfer

Device A sends `TransferEventType.transferComplete` when all data sent:
- Includes fileName and transferID
- Stops speed tracking
- Stops foreground service

### Step 6: Handle Completion (Device B)

Receives transferComplete event:
- Flushes and closes file sink
- Marks transfer complete in transfer state repository
- Stops foreground service
- Creates HistoryItem with file details
- Adds to history via `historyViewModel.addItem()`
- Sends notification: "Transfer completed"
- Transitions to transferCompleted state

### Packet Structure

**Header (5 bytes):**
- Bytes 0-3: Payload length (uint32, big-endian)
- Byte 4: Type (0=JSON, 1=BINARY)

**Payload (variable length):**
- JSON packets: UTF-8 encoded JSON
- BINARY packets: Raw file bytes

### File References

- `sendFile()` in connection_repository.dart
- `_handleIncomingEvent(fileMetadata)` in connection_repository.dart
- `_handleBinaryChunk()` in connection_repository.dart
- packet_reader.dart for packet parsing

---

## 4. Pause & Resume Functionality

### Pause Operation

User taps Pause during transfer:

1. `ConnectionViewModel.pauseTransfer()` called
2. `ConnectionRepository._isTransferPaused = true`
3. `_pausedAtBytes` = current `_receivedBytes` (stored for resume)
4. Speed tracking stopped
5. Sends `TransferEventType.transferPaused` event with:
   - pausedAtBytes: 5242880 (current position)
   - totalBytes: 10485760
6. State becomes `ConnectionStatus.transferPaused`
7. Notification shows "Transfer paused"

Device B receives transferPaused:

1. Sets `_isTransferPaused = true`
2. Updates state to transferPaused
3. Stops writing to file (but keeps it open)
4. Speed tracking stops

### Resume Operation

User taps Resume:

1. `ConnectionViewModel.resumeTransfer()` called
2. `ConnectionRepository._isTransferPaused = false`
3. Restarts speed tracking
4. Sends `TransferEventType.transferResumed` event with:
   - resumedFromBytes: 5242880
5. State becomes `ConnectionStatus.transferring`
6. Notification shows "Transfer resumed"
7. File read loop continues from stored position

Device B receives transferResumed:

1. Sets `_isTransferPaused = false`
2. Restarts speed tracking
3. File is still open - continues receiving chunks
4. State becomes transferring

### Why This Works

- File handle remains open during pause (doesn't close)
- Sender's `file.openRead(offset)` can be resumed from same point
- No data loss because receiver hasn't closed file
- Offset support built into `sendFile()` method
- Progress continues from exact byte position

### Limitations

- Can only pause/resume current file
- If connection dies during pause, resume fails (would need persist)
- Receiver's file cannot be truncated mid-pause

### File References

- `pauseTransfer()`, `resumeTransfer()` in connection_repository.dart
- `pauseTransfer()`, `resumeTransfer()` in connection_viewmodel.dart
- TransferEventType.transferPaused, transferResumed

---

## 5. Transfer Cancellation

### Cancel from Sender

User taps Cancel during transfer:

1. `ConnectionViewModel.cancelTransfer()` called
2. `ConnectionRepository._isTransferCancelled = true`
3. Speed tracking stopped
4. Sends `TransferEventType.transferCancelled` event
5. File read loop breaks on next iteration
6. State becomes error with errorMessage

Device B receives transferCancelled:

1. Sets `_isTransferCancelled = true`
2. Closes file sink
3. Deletes incomplete file: `_receivingFile!.deleteSync()`
4. Stops foreground service
5. State becomes error

### Cancel from Receiver

User taps Cancel on receiver:

1. `ConnectionViewModel.cancelTransfer()` called (same method)
2. `ConnectionRepository._isTransferCancelled = true`
3. Sends `TransferEventType.transferCancelled` event
4. Closes file sink and deletes incomplete file
5. State becomes error

Device A receives transferCancelled:

1. Sets `_isTransferCancelled = true`
2. Breaks file read loop
3. Stops speed tracking
4. Stops foreground service
5. State becomes error

### Cleanup

On both sides:
- File handle closed
- Incomplete file deleted
- Speed tracking timer cancelled
- Foreground service stopped
- Progress/speed streams cleared
- `_pendingFiles` cleared (prevents batch continuation)

Notifications:
- `showTransferCancelled()` called
- Shows which device cancelled and reason

### File References

- `cancelTransfer()` in connection_repository.dart
- `cancelTransfer()` in connection_viewmodel.dart
- TransferEventType.transferCancelled

---

## 6. Notification System

**Location:** lib/core/services/notification_service.dart  
**Backend:** Android NotificationCompat via MethodChannel

### Connection Notifications

- `showConnectionEstablished(deviceName)` - "Connected to [Device Name]"
- `showConnectionRejected(deviceName, reason)` - "Connection rejected by [Device]: [Reason]"
- `showError(title, message)` - General connection errors

### Transfer Request Notifications

- `showTransferRequest(deviceName, fileName, fileSize)` - "File transfer request from [Device]: [File] ([Size] MB)"
- High priority to get user attention

### Transfer Progress Notifications

- `showTransferStarted(fileName, isSending)` - "Sending/Receiving: [File]"
- `updateTransferProgress(fileName, %, speedMBps, isSending)` - "Sending/Receiving: [File]" with progress bar and "50% • 12.5 MB/s"
- Updated continuously during transfer

### Pause/Resume Notifications

- `showTransferPaused(fileName)` - "Transfer paused: [File]"
- `showTransferResumed(fileName)` - "Transfer resumed: [File]"

### Completion Notifications

- `showTransferCompleted(fileName, fileSize, isSending)` - "Sent successfully: [File] (10.5 MB)" or "Received successfully: [File] (10.5 MB)"
- Auto-dismiss after short delay

### Cancellation/Error Notifications

- `showTransferCancelled(fileName, reason)` - "Transfer failed: [Reason] - [File]"
- High priority

### Integration Points

All notifications called from ConnectionViewModel event handlers:
- connection_viewmodel.dart: `_repo.eventStream.listen()` block
- connection_viewmodel.dart: `_repo.speedStream.listen()` block
- connection_viewmodel.dart: Various handler methods

### File References

- notification_service.dart: All notification methods
- connection_viewmodel.dart: All notification calls
- Android backend: MainActivity.kt with NotificationCompat

---

## 7. History Tracking

**Backend:** Hive (Flutter local database)  
**Location:** lib/features/history/

### Data Model

HistoryItem (@HiveType):
- id: String (timestamp-based unique ID)
- fileName: String
- filePath: String (for opening file later)
- fileSize: int (in bytes)
- deviceName: String (peer device name)
- timestamp: DateTime (when transfer occurred)
- type: HistoryType (sent or received)

### When Sending

After each file completes `sendFile()`:

- Create HistoryItem with:
  - fileName: `_pendingFiles[0].uri.pathSegments.last`
  - filePath: nextFile.path
  - fileSize: nextFile.lengthSync()
  - type: HistoryType.sent
  - deviceName: state.connectedTo
- Call `_historyViewModel.addItem(item)`
- Item persisted to Hive database

### When Receiving

After transferComplete event:

- Create HistoryItem with:
  - fileName: state.incomingFileName
  - filePath: state.lastSavedPath
  - fileSize: state.incomingFileSize
  - type: HistoryType.received
  - deviceName: state.connectedTo
- Call `_historyViewModel.addItem(item)`
- Item persisted to Hive database

### Batch Transfers

Each file in batch gets individual history entry:
- After each file completes, separate HistoryItem created
- All entries linked via history repository

### History Operations

- `loadHistory()`: Retrieve all items from Hive
- `addItem(item)`: Add new entry
- `removeItem(id)`: Delete specific entry
- `clearAll()`: Remove all history

### File References

- history_item.dart: Data model
- history_repository.dart: Hive operations
- history_viewmodel.dart: State management
- history_view.dart: UI display

---

## 8. Error Handling & Recovery

### Connection Errors

**Trying to connect to unavailable device:**
- Handled in `connectToPeer()` catch block
- State: error, errorMessage set
- Notification: `showError()`

**TLS handshake failure:**
- Caught in `connect()` catch block
- Connection closed automatically
- Error propagated to viewmodel

**Socket closed unexpectedly:**
- `_handleNewSocket()` onError callback triggered
- `close()` called automatically
- State: error

### Transfer Errors

**File not found (deleted before transfer):**
- Caught in `sendFile()`
- Exception thrown and caught by caller
- State: error

**Permission denied reading/writing:**
- Caught in `sendFile()` or file write operations
- State: error, notifications sent

**Disk full on receiver:**
- `IOSink.add()` fails
- Exception caught by error handler
- State: error, incomplete file deleted

**Network interruption mid-transfer:**
- `Socket.listen()` onError triggered
- Transfer stopped
- Incomplete file deleted
- State: error

### Error Notifications

All errors trigger `showError(title, message)`:
- Connection Failed: [reason]
- Transfer Failed: [reason]
- File Pick Error: [reason]
- Clipboard Error: [reason]

### Recovery

**Automatic cleanup:**
- Closed file handles
- Deleted incomplete files
- Cancelled timers
- Stopped services

**Manual recovery:**
- User can retry connection
- Can restart receiving server
- Can retry file transfer

**Pause/Resume as recovery:**
- If pause before critical error
- Can resume from saved position
- Otherwise restart from beginning

### File References

- connection_repository.dart: `_handleNewSocket()` error handlers
- connection_repository.dart: All try-catch blocks
- connection_viewmodel.dart: Error state management
- notification_service.dart: `showError()` method

---

## Summary of Features

### Connection Requests
- Peer discovery via mDNS
- Connection acceptance/rejection
- PIN authentication (optional)
- Proper state transitions

### Transfer Requests
- Single file and batch transfers
- Transfer acceptance/rejection
- File metadata exchange
- Progress tracking

### File Transfer Protocol
- Chunked transfer
- Real-time progress updates
- Speed calculation
- Transfer validation

### Pause & Resume
- Pause mid-transfer
- Resume from exact position
- Progress preservation
- Offset-based continuation

### Transfer Cancellation
- Cancel from both sides
- Incomplete file cleanup
- Proper resource cleanup
- Error state management

### Notifications
- Connection events
- Transfer requests
- Progress updates
- Pause/resume events
- Completion status
- Error alerts

### History Tracking
- Persistent history
- Sent/received classification
- File details storage
- Device tracking

### Security
- TLS encryption
- Self-signed certificates
- PIN authentication
- Device identity verification

### Error Handling
- Comprehensive exception catching
- Proper cleanup on errors
- User notifications
- Manual recovery support
