import 'package:fileflow/core/theme/app_theme.dart';
import 'package:fileflow/features/discovery/view/discovery_screen.dart';
import 'package:fileflow/features/history/view/history_screen.dart';
import 'package:fileflow/features/settings/view/settings_screen.dart';
import 'package:fileflow/features/transfer/provider/transfer_provider.dart';
import 'package:fileflow/features/transfer/view/transfer_screen.dart';
import 'package:fileflow/features/transfer/viewmodel/connection_viewmodel.dart' as conn;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;

 void _showConnectionRequestDialog(conn.ConnectionState state, BuildContext context) {
     showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Connection Request'),
        content: Text('Device "${state.connectedTo}" wants to connect with you.'),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(connectionViewModelProvider.notifier).rejectConnection();
              Navigator.of(context).pop();
            },
            child: const Text('Reject', style: TextStyle(color: AppTheme.error)),
          ),
          FilledButton(
            onPressed: () {
              ref.read(connectionViewModelProvider.notifier).acceptConnection();
              Navigator.of(context).pop();
              // Switch to Transfer tab to see status
              setState(() {
                _selectedIndex = 1;
              });
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  void _showTransferRequestDialog(conn.ConnectionState state, BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Receive File?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Device "${state.connectedTo}" wants to send:'),
            const SizedBox(height: 8),
            Text(
              state.incomingFileName ?? 'Unknown File',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Size: ${_formatBytes(state.incomingFileSize ?? 0)}',
              style: AppTheme.bodySmall,
            ),
            if (state.isBatch) ...[
               const SizedBox(height: 8),
               const Chip(label: Text("Batch Transfer"))
            ]
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(connectionViewModelProvider.notifier).rejectTransfer();
              Navigator.of(context).pop();
            },
            child: const Text('Decline', style: TextStyle(color: AppTheme.error)),
          ),
          FilledButton(
            onPressed: () {
              ref.read(connectionViewModelProvider.notifier).acceptTransfer();
              Navigator.of(context).pop();
              setState(() {
                _selectedIndex = 1;
              });
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
    double s = bytes.toDouble();
    int idx = 0;
    while(s >= 1024 && idx < suffixes.length - 1){
        s /= 1024;
        idx++;
    }
    return "${s.toStringAsFixed(2)} ${suffixes[idx]}";
  }

  @override
  Widget build(BuildContext context) {
    // Listen to connection state to show dialogs
    ref.listen(connectionViewModelProvider, (previous, next) {
      if (next.status == conn.ConnectionStatus.awaitingConfirmation) {
        _showConnectionRequestDialog(next, context);
      } else if (next.status == conn.ConnectionStatus.transferRequestReceived) {
        _showTransferRequestDialog(next, context);
      } else if (next.status == conn.ConnectionStatus.error && next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(next.errorMessage!),
              backgroundColor: AppTheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    });

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          DiscoveryScreen(),
          TransferScreen(),
          HistoryScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.radar_rounded),
            label: 'Nearby',
          ),
          NavigationDestination(
            icon: Icon(Icons.swap_horiz_rounded),
            label: 'Transfer',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_rounded),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
