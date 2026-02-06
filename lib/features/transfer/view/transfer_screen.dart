import 'package:fileflow/core/constants/app_constants.dart';
import 'package:fileflow/core/theme/app_theme.dart';
import 'package:fileflow/features/transfer/provider/transfer_provider.dart';
import 'package:fileflow/features/transfer/viewmodel/connection_viewmodel.dart'
    as conn;
import 'package:fileflow/features/transfer/model/transfer_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TransferScreen extends ConsumerWidget {
  const TransferScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(connectionViewModelProvider);
    final viewModel = ref.read(connectionViewModelProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Transfer'), centerTitle: true),
      body: _buildBody(context, state, viewModel),
    );
  }

  Widget _buildBody(
    BuildContext context,
    conn.ConnectionState state,
    conn.ConnectionViewModel viewModel,
  ) {
    switch (state.status) {
      case conn.ConnectionStatus.disconnected:
      case conn.ConnectionStatus.listening:
      case conn.ConnectionStatus.error:
        return _buildDisconnectedState(context, state);

      case conn.ConnectionStatus.connecting:
      case conn.ConnectionStatus.awaitingConfirmation:
        return _buildConnectingState(context, state);

      case conn.ConnectionStatus.connected:
        if (state.transferQueue.isNotEmpty && state.transferProgress > 0) {
          // Keep showing transfer screen if we have a queue and recent activity
          // or maybe we rely on status.
          // If status is connected but queue has items, it might be 'done'.
          // Let's check status.
        }
        return _buildConnectedState(context, state, viewModel);

      case conn.ConnectionStatus.transferRequestReceived:
      case conn.ConnectionStatus.awaitingTransferAcceptance:
        return const Center(child: CircularProgressIndicator());

      case conn.ConnectionStatus.transferring:
      case conn.ConnectionStatus.transferPaused:
      case conn.ConnectionStatus.transferCompleted:
        return _buildTransferringState(context, state, viewModel);
    }
  }

  Widget _buildDisconnectedState(
    BuildContext context,
    conn.ConnectionState state,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.link_off_rounded,
            size: 80,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            "Not Connected",
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text("Go to the 'Nearby' tab to find devices."),
          if (state.errorMessage != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "Error: ${state.errorMessage}",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConnectingState(
    BuildContext context,
    conn.ConnectionState state,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            state.status == conn.ConnectionStatus.awaitingConfirmation
                ? "Waiting for peer to accept..."
                : "Connecting to ${state.connectedTo ?? 'Device'}...",
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedState(
    BuildContext context,
    conn.ConnectionState state,
    conn.ConnectionViewModel viewModel,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: AppTheme.primary,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Connected to",
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                      Text(
                        state.connectedTo ?? "Unknown Device",
                        style: AppTheme.titleLarge.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => viewModel.disconnect(),
                  icon: const Icon(Icons.logout),
                  tooltip: "Disconnect",
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
          Text("Actions", style: AppTheme.titleMedium),
          const SizedBox(height: 16),

          _ActionCard(
            icon: Icons.file_present_rounded,
            title: "Send Files",
            subtitle: "Pick multiple files to share",
            color: AppTheme.primary,
            onTap: () => viewModel.pickAndSendFiles(),
          ),
          const SizedBox(height: 12),
          _ActionCard(
            icon: Icons.folder_open_rounded,
            title: "Send Folder",
            subtitle: "Share entire directories",
            color: AppTheme.warning,
            onTap: () => viewModel.pickFolder(),
          ),
          const SizedBox(height: 12),
          _ActionCard(
            icon: Icons.copy_rounded,
            title: "Share Clipboard",
            subtitle: "Send copied text immediately",
            color: AppTheme.success,
            onTap: () => viewModel.sendClipboard(),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferringState(
    BuildContext context,
    conn.ConnectionState state,
    conn.ConnectionViewModel viewModel,
  ) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                state.isIncoming ? "Receiving files" : "Sending files",
                style: AppTheme.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Destination: ${AppConstants.appDir}",
                style: AppTheme.bodySmall.copyWith(color: AppTheme.slate500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        // File List
        Expanded(
          child: state.transferQueue.isEmpty
              ? const Center(child: Text("Initializing transfer..."))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.transferQueue.length,
                  separatorBuilder: (c, i) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = state.transferQueue[index];
                    return _TransferQueueItemWidget(
                      item: item,
                      currentSpeed: state.transferSpeed,
                    );
                  },
                ),
        ),

        // Bottom Sheet (Controls)
        _TransferBottomSheet(state: state, viewModel: viewModel),
      ],
    );
  }
}

class _TransferQueueItemWidget extends StatelessWidget {
  final TransferItem item;
  final double currentSpeed;

  const _TransferQueueItemWidget({
    required this.item,
    required this.currentSpeed,
  });

  @override
  Widget build(BuildContext context) {
    final bool isCompleted = item.status == TransferItemStatus.completed;
    final bool isTransferring = item.status == TransferItemStatus.transferring;

    // Calculate processed bytes for this specific item based on progress
    final processedBytes = (item.fileSize * item.progress).toInt();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isTransferring
              ? AppTheme.primary.withValues(alpha: 0.3)
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          // Thumbnail/Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isCompleted
                  ? AppTheme.success.withValues(alpha: 0.1)
                  : AppTheme.borderColor(context).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: isCompleted
                ? const Icon(Icons.check_rounded, color: AppTheme.success)
                : Icon(
                    _getFileIcon(item.fileName),
                    color: AppTheme.textColor(context).withValues(alpha: 0.7),
                    size: 24,
                  ),
          ),
          const SizedBox(width: 16),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.fileName,
                        style: AppTheme.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                if (isTransferring) ...[
                  Row(
                    children: [
                      Text(
                        "${_formatBytes(processedBytes)} / ${_formatBytes(item.fileSize)}",
                        style: AppTheme.labelSmall,
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.outline,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatSpeed(currentSpeed),
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: item.progress,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ] else if (isCompleted) ...[
                  Text(
                    _formatBytes(item.fileSize),
                    style: TextStyle(
                      color: AppTheme.textColor(context).withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                ] else ...[
                  Text(
                    "${_formatBytes(item.fileSize)} • Pending",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'mp4':
      case 'mov':
        return Icons.movie;
      case 'mp3':
      case 'wav':
        return Icons.music_note;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'zip':
      case 'rar':
        return Icons.folder_zip;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatSpeed(double bytesPerSec) {
    if (bytesPerSec <= 0) return "0 KB/s";
    if (bytesPerSec < 1024 * 1024) {
      return "${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s";
    }
    return "${(bytesPerSec / 1024 / 1024).toStringAsFixed(1)} MB/s";
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    double s = bytes.toDouble();
    int idx = 0;
    while (s >= 1024 && idx < suffixes.length - 1) {
      s /= 1024;
      idx++;
    }
    return "${s.toStringAsFixed(1)} ${suffixes[idx]}";
  }
}

class _TransferBottomSheet extends StatelessWidget {
  final conn.ConnectionState state;
  final conn.ConnectionViewModel viewModel;

  const _TransferBottomSheet({required this.state, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final totalBytes = state.totalBatchSize > 0
        ? state.totalBatchSize
        : (state.incomingFileSize ?? 0);
    final currentTotalBytes =
        state.totalBatchBytesTransferred + state.transferredBytes;

    // Safety check
    final safeTotal = totalBytes > 0 ? totalBytes : 1;
    final totalProgress = (currentTotalBytes / safeTotal).clamp(0.0, 1.0);

    final remainingBytes = safeTotal - currentTotalBytes;
    final etaSeconds = state.transferSpeed > 0
        ? (remainingBytes / state.transferSpeed).ceil()
        : 0;

    final etaStr =
        (state.transferSpeed > 0 &&
            etaSeconds < 3600 * 24) // Sanity check for massive ETAs
        ? _formatDuration(Duration(seconds: etaSeconds))
        : "--:--";

    final isPaused = state.status == conn.ConnectionStatus.transferPaused;
    final isFinished = state.status == conn.ConnectionStatus.transferCompleted;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isFinished) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Overall Progress",
                      style: AppTheme.titleMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${_formatBytes(currentTotalBytes)} of ${_formatBytes(totalBytes)}",
                      style: AppTheme.labelSmall,
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        etaStr,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: totalProgress,
              minHeight: 12,
              borderRadius: BorderRadius.circular(6),
              backgroundColor: AppTheme.slate200,
            ),
            const SizedBox(height: 32),
          ],

          if (!isFinished)
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: isPaused
                          ? viewModel.resumeTransfer
                          : viewModel.pauseTransfer,
                      style: FilledButton.styleFrom(
                        backgroundColor: isPaused
                            ? AppTheme.primary
                            : AppTheme.slate200,
                        foregroundColor: isPaused
                            ? Colors.white
                            : AppTheme.slate700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: Icon(
                        isPaused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                      ),
                      label: Text(
                        isPaused ? "Resume" : "Pause",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 56,
                  height: 56,
                  child: IconButton.filled(
                    onPressed: viewModel.cancelTransfer,
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.error.withValues(alpha: 0.1),
                      foregroundColor: AppTheme.error,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: "Cancel",
                  ),
                ),
              ],
            )
          else
            SizedBox(
              height: 56,
              child: FilledButton.icon(
                onPressed: viewModel.resetTransfer,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.check_circle_rounded),
                label: const Text(
                  "Done",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return "${d.inHours}:${(d.inMinutes % 60).toString().padLeft(2, '0')}h";
    }
    return "${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')} min";
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    double s = bytes.toDouble();
    int idx = 0;
    while (s >= 1024 && idx < suffixes.length - 1) {
      s /= 1024;
      idx++;
    }
    return "${s.toStringAsFixed(1)} ${suffixes[idx]}";
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.borderColor(context)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTheme.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: AppTheme.labelSmall.copyWith(
                        color: AppTheme.textColor(
                          context,
                        ).withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
