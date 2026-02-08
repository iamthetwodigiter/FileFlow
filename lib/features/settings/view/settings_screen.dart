import 'package:fileflow/core/constants/app_constants.dart';
import 'package:fileflow/core/providers/providers.dart';
import 'package:fileflow/core/theme/app_theme.dart';
import 'package:fileflow/features/settings/provider/settings_provider.dart';
import 'package:fileflow/features/transfer/provider/transfer_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  void _showNameDialog(
    BuildContext context,
    String? currentName,
    dynamic viewModel,
  ) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Device Name"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: "Enter name",
            border: OutlineInputBorder(),
          ),
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
              viewModel.setDeviceName(controller.text);
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Text(
      title,
      style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
    ),
  );

  Widget _deviceDetailsTile(String title, String value) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18),
    child: Row(
      children: [
        Text('$title: ', style: TextStyle(fontSize: 16)),
        Text(
          value,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsViewModelProvider);
    final viewModel = ref.read(settingsViewModelProvider.notifier);
    final deviceInfo = ref.watch(deviceInfoProvider);
    final connectionState = ref.watch(connectionViewModelProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          _sectionHeader("Device"),

          ExpansionTile(
            maintainState: true,
            initiallyExpanded: true,
            collapsedShape: RoundedRectangleBorder(
              side: BorderSide(color: AppTheme.transparent),
            ),
            shape: RoundedRectangleBorder(
              side: BorderSide(color: AppTheme.transparent),
            ),
            iconColor: AppTheme.primary,
            collapsedIconColor: AppTheme.primary,
            title: Text(
              'Device Details',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            children: [
              ListTile(
                leading: const Icon(Icons.smartphone),
                title: const Text(
                  "Device Name",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: Text(deviceInfo.name),
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    _showNameDialog(context, settings.deviceName, viewModel);
                  },
                ),
              ),
              _deviceDetailsTile('ID', deviceInfo.id),
              _deviceDetailsTile('Model', deviceInfo.model),
              _deviceDetailsTile(
                'Running on',
                '${deviceInfo.os} ${deviceInfo.version}',
              ),
            ],
          ),

          const Divider(),
          _sectionHeader("Appearance"),
          ListTile(
            leading: const Icon(Icons.dark_mode),
            title: const Text(
              "Dark Mode",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            trailing: Switch(
              value: settings.darkMode,
              onChanged: (value) {
                viewModel.toggleDarkMode();
              },
            ),
          ),

          const Divider(),
          _sectionHeader("Security"),
          ListTile(
            leading: const Icon(Icons.security_rounded),
            title: const Text(
              "Required Pin for Connection",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: settings.requiredPin
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (connectionState.sessionPin != null)
                        RichText(
                          text: TextSpan(
                            style: TextStyle(
                              color: AppTheme.textColor(context),
                            ),
                            text: 'PIN: ',
                            children: [
                              TextSpan(
                                text: connectionState.sessionPin,
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const Text('[Enter this pin on peer device to connect]'),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: () async {
                          await ref
                              .read(connectionViewModelProvider.notifier)
                              .restartServer();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Server restarted successfully'),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Restart Server to Apply'),
                      ),
                    ],
                  )
                : null,
            trailing: Switch(
              value: settings.requiredPin,
              onChanged: (value) async {
                await viewModel.toggleRequiredPin(value);
              },
            ),
          ),

          const Divider(),
          _sectionHeader("About"),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text(
              "Version",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(AppConstants.appVersion),
          ),
        ],
      ),
    );
  }
}
