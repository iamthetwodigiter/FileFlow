import 'package:fileflow/core/theme/app_theme.dart';
import 'package:fileflow/features/history/model/history_item.dart';
import 'package:fileflow/features/history/provider/history_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  void _showDeleteConfirmation(BuildContext context, VoidCallback onPressed) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Delete History"),
        content: const Text(
          "Are you sure to delete all the transaction history?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Cancel",
              style: TextStyle(color: AppTheme.error),
            ),
          ),
          FilledButton(onPressed: onPressed, child: const Text("Delete")),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
    double s = bytes.toDouble();
    int idx = 0;
    while (s >= 1024 && idx < suffixes.length - 1) {
      s /= 1024;
      idx++;
    }
    return "${s.toStringAsFixed(2)} ${suffixes[idx]}";
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyViewModelProvider);
    final viewModel = ref.read(historyViewModelProvider.notifier);

    final totalSentBytes = history
        .where((item) => item.type == HistoryType.sent)
        .fold(0, (sum, item) => sum + item.fileSize);
    final totalReceivedBytes = history
        .where((item) => item.type == HistoryType.received)
        .fold(0, (sum, item) => sum + item.fileSize);
    final totalFiles = history.fold(0, (sum, item) => sum + item.fileCount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              _showDeleteConfirmation(context, () {
                viewModel.clearAll();
                Navigator.pop(context);
              });
            },
          ),
        ],
      ),
      body: history.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history_toggle_off,
                    size: 64,
                    color: AppTheme.borderColor(context),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No transfer history",
                    style: AppTheme.titleMedium.copyWith(
                      color: AppTheme.textColor(context).withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            )
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primary,
                            AppTheme.primary.withValues(alpha: 0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Total Shared",
                                style: GoogleFonts.outfit(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Icon(
                                Icons.bar_chart_rounded,
                                color: Colors.white,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _formatBytes(
                                  totalSentBytes + totalReceivedBytes,
                                ),
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 8,
                                  bottom: 6,
                                ),
                                child: Text(
                                  "in $totalFiles files",
                                  style: GoogleFonts.outfit(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: _statItem(
                                  Icons.arrow_upward,
                                  "Sent",
                                  _formatBytes(totalSentBytes),
                                ),
                              ),
                              Container(
                                height: 30,
                                width: 1,
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                              Expanded(
                                child: _statItem(
                                  Icons.arrow_downward,
                                  "Received",
                                  _formatBytes(totalReceivedBytes),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                final item = history[history.length - 1 - index];
                final isSent = item.type == HistoryType.sent;

                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: AppTheme.borderColor(context)),
                  ),
                  child: item.isBatch && (item.batchFiles?.isNotEmpty ?? false)
                      ? Theme(
                          data: Theme.of(
                            context,
                          ).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            leading: CircleAvatar(
                              backgroundColor: isSent
                                  ? AppTheme.primary.withValues(alpha: 0.1)
                                  : AppTheme.success.withValues(alpha: 0.1),
                              child: Icon(
                                isSent
                                    ? Icons.arrow_upward
                                    : Icons.arrow_downward,
                                color: isSent
                                    ? AppTheme.primary
                                    : AppTheme.success,
                                size: 20,
                              ),
                            ),
                            title: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    "Batch of ${item.fileCount} files",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.isDark(context)
                                        ? AppTheme.slate700
                                        : AppTheme.slate200,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    "Batch",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textColor(context),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "${isSent ? 'Sent to' : 'Received from'} ${item.deviceName}",
                                ),
                                Text(
                                  DateFormat.yMMMd().add_jm().format(
                                    item.timestamp,
                                  ),
                                  style: AppTheme.bodySmall,
                                ),
                              ],
                            ),
                            trailing: Text(
                              _formatBytes(item.fileSize),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Divider(
                                  color: AppTheme.borderColor(context),
                                ),
                              ),
                              ...?item.batchFiles?.map(
                                (file) => ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 0,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  leading: const Icon(
                                    Icons.description_outlined,
                                    size: 18,
                                    color: Colors.grey,
                                  ),
                                  title: Text(
                                    file.fileName,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  trailing: Text(
                                    _formatBytes(file.fileSize),
                                    style: AppTheme.bodySmall,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isSent
                                ? AppTheme.primary.withValues(alpha: 0.1)
                                : AppTheme.success.withValues(alpha: 0.1),
                            child: Icon(
                              isSent
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward,
                              color: isSent
                                  ? AppTheme.primary
                                  : AppTheme.success,
                              size: 20,
                            ),
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  item.fileName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (item.isBatch) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.isDark(context)
                                        ? AppTheme.slate700
                                        : AppTheme.slate200,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    "Batch",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textColor(context),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${isSent ? 'Sent to' : 'Received from'} ${item.deviceName}",
                              ),
                              Text(
                                DateFormat.yMMMd().add_jm().format(
                                  item.timestamp,
                                ),
                                style: AppTheme.bodySmall,
                              ),
                            ],
                          ),
                          trailing: Text(
                            _formatBytes(item.fileSize),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                );
                    },
                    childCount: history.length,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _statItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: Colors.white.withValues(alpha: 0.8),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
