import 'dart:io';
import 'package:fileflow/core/theme/app_theme.dart';
import 'package:fileflow/core/constants/app_constants.dart';
import 'package:fileflow/core/providers/providers.dart';
import 'package:fileflow/features/discovery/provider/discovery_provider.dart';
import 'package:fileflow/features/transfer/provider/transfer_provider.dart';
import 'package:fileflow/features/transfer/viewmodel/connection_viewmodel.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

class DiscoveryScreen extends ConsumerWidget {
  const DiscoveryScreen({super.key});

  void _disconnect(BuildContext context, WidgetRef ref, String deviceName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Disconnect from $deviceName?"),
        content: const Text(
          "You will no longer be able to send or receive files",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Cancel",
              style: TextStyle(color: AppTheme.error),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(connectionViewModelProvider.notifier).disconnect();
            },
            child: const Text("Disconnect"),
          ),
        ],
      ),
    );
  }

  void _showConnectDialog(
    BuildContext context,
    WidgetRef ref,
    String ip,
    int port,
    String deviceName, {
    required bool isPinRequired,
  }) {
    final pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Connect to $deviceName"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isPinRequired) ...[
              const Text("This device requires a PIN to connect."),
              const SizedBox(height: 16),
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Enter PIN",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
            ] else
              const Text("Do you want to connect to this device?"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Cancel",
              style: TextStyle(color: AppTheme.error),
            ),
          ),
          FilledButton(
            onPressed: () {
              final pin = pinController.text.trim();
              Navigator.pop(context);
              ref
                  .read(connectionViewModelProvider.notifier)
                  .connect(ip, port, pin: pin.isNotEmpty ? pin : null);
            },
            child: const Text("Connect"),
          ),
        ],
      ),
    );
  }

  void _showQRDialog(
    BuildContext context,
    String? myIp,
    int port,
    String myName,
  ) {
    if (myIp == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No IP Address found. Connect to Wi-Fi.")),
      );
      return;
    }
    final qrData = "$myIp:$port";
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Scan to Connect"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 200,
              height: 200,
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 200.0,
              ),
            ),
            const SizedBox(height: 10),
            Text(myName, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(
              qrData,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  void _showScanner(
    BuildContext context,
    WidgetRef ref,
    String deviceName,
    bool isPinRequired,
  ) {
    // QR scanning only available on mobile
    if (!Platform.isAndroid && !Platform.isIOS) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('QR scanning is only available on mobile devices'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text("Scan QR to Connect")),
        body: MobileScanner(
          onDetect: (capture) {
            final List<Barcode> barcodes = capture.barcodes;
            for (final barcode in barcodes) {
              if (barcode.rawValue != null) {
                final code = barcode.rawValue!;
                Navigator.pop(context);
                _connectToIP(context, ref, code, deviceName, isPinRequired);
                break;
              }
            }
          },
          onDetectError: (error, stackTrace) {
            debugPrint('QR Scan error: $error');
            debugPrintStack(stackTrace: stackTrace);
          },
        ),
      ),
    );
  }

  void _connectToIP(
    BuildContext context,
    WidgetRef ref,
    String qrData,
    String deviceName,
    bool isPinRequired,
  ) {
    try {
      debugPrint('🔍 QR Code scanned: $qrData');
      final parts = qrData.split(':');
      if (parts.length != 2) {
        debugPrint('❌ Invalid QR format: expected IP:port, got $qrData');
        throw FormatException('Invalid QR format');
      }

      final ip = parts[0];
      final port = int.tryParse(parts[1]);
      if (port == null) {
        debugPrint('❌ Invalid port in QR: ${parts[1]}');
        throw FormatException('Invalid port');
      }

      debugPrint('🔗 Attempting direct connection to $ip:$port via QR');
      _showConnectDialog(
        context,
        ref,
        ip,
        port,
        deviceName,
        isPinRequired: isPinRequired,
      );
    } catch (e) {
      debugPrint('❌ QR connection error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid QR code format')));
    }
  }

  IconData _getDeviceIcon(String type) {
    if (type.toLowerCase().contains('android')) return Icons.android;
    if (type.toLowerCase().contains('ios')) return Icons.phone_iphone;
    if (type.toLowerCase().contains('windows')) return Icons.desktop_windows;
    if (type.toLowerCase().contains('mac')) return Icons.laptop_mac;
    if (type.toLowerCase().contains('linux')) return Icons.laptop_chromebook;
    return Icons.smartphone;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peers = ref.watch(peerListProvider);
    final connectionState = ref.watch(connectionViewModelProvider);
    final deviceInfo = ref.watch(deviceInfoProvider);
    final myIp = ref.watch(myIpProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Devices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(peerListProvider);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 200,
            width: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 100,
                      width: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.2),
                          width: 2,
                        ),
                      ),
                    ),
                    Container(
                      height: 140,
                      width: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          width: 2,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.radar_rounded,
                      size: 64,
                      color: AppTheme.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  "Scanning for devices...",
                  style: AppTheme.titleMedium.copyWith(
                    color: AppTheme.textColor(context).withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: peers.isEmpty
                ? Center(
                    child: Text(
                      "No devices found yet.\nMake sure other devices are on the same Wi-Fi.",
                      textAlign: TextAlign.center,
                      style: AppTheme.bodyLarge.copyWith(
                        color: AppTheme.textColor(
                          context,
                        ).withValues(alpha: 0.7),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: peers.length,
                    itemBuilder: (context, index) {
                      final peer = peers[index];
                      final isConnected =
                          connectionState.connectedTo == peer.deviceInfo.name &&
                          connectionState.status == ConnectionStatus.connected;

                      return Card(
                        elevation: 0,
                        color: isConnected
                            ? AppTheme.primary.withValues(alpha: 0.1)
                            : AppTheme.cardColor(context),
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: AppTheme.borderColor(context),
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: CircleAvatar(
                            backgroundColor: isConnected
                                ? AppTheme.primary
                                : AppTheme.slate200,
                            foregroundColor: isConnected
                                ? Colors.white
                                : AppTheme.slate600,
                            child: Icon(_getDeviceIcon(peer.deviceInfo.os)),
                          ),
                          title: Text(
                            peer.deviceInfo.name,
                            style: AppTheme.titleMedium.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text("IP: ${peer.ip}:${peer.port}"),
                          trailing: isConnected
                              ? InkWell(
                                  onTap: () {
                                    _disconnect(
                                      context,
                                      ref,
                                      peer.deviceInfo.name,
                                    );
                                  },
                                  child: const Chip(
                                    label: Text("Connected"),
                                    avatar: Icon(Icons.check, size: 16),
                                  ),
                                )
                              : ElevatedButton(
                                  onPressed:
                                      connectionState.status ==
                                          ConnectionStatus.connecting
                                      ? null
                                      : () {
                                          _showConnectDialog(
                                            context,
                                            ref,
                                            peer.ip,
                                            peer.port,
                                            peer.deviceInfo.name,
                                            isPinRequired:
                                                peer.deviceInfo.isPinRequired,
                                          );
                                        },
                                  child:
                                      connectionState.status ==
                                              ConnectionStatus.connecting &&
                                          connectionState.connectedTo ==
                                              peer.deviceInfo.name
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text("Connect"),
                                ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: Column(
        spacing: 10,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            onPressed: () {
              _showScanner(
                context,
                ref,
                peers.first.deviceInfo.name,
                peers.first.deviceInfo.isPinRequired,
              );
            },
            label: const Text("Scan QR"),
            icon: const Icon(Icons.qr_code_scanner_rounded),
          ),
          if (myIp != null)
            FloatingActionButton.extended(
              onPressed: () {
                _showQRDialog(
                  context,
                  myIp,
                  AppConstants.port,
                  deviceInfo.name,
                );
              },
              icon: const Icon(Icons.qr_code_2_rounded),
              label: const Text("Share QR"),
            ),
        ],
      ),
    );
  }
}
