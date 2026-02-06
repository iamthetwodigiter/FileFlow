import 'package:fileflow/core/providers/providers.dart';
import 'package:fileflow/features/discovery/model/peer.dart';
import 'package:fileflow/features/discovery/repository/discovery_repository.dart';
import 'package:fileflow/features/discovery/viewmodel/discovery_viewmodel.dart';
import 'package:fileflow/features/settings/provider/settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

final discoveryRepositoryProvider = Provider((ref) => DiscoveryRepository());

final peerListProvider = StateNotifierProvider<DiscoveryViewmodel, List<Peer>>((
  ref,
) {
  final settings = ref.watch(settingsViewModelProvider);
  final deviceInfo = ref.read(deviceInfoProvider);
  final effectiveDeviceInfo =
      (settings.deviceName != null && settings.deviceName!.isNotEmpty
      ? deviceInfo.copyWith(name: settings.deviceName)
      : deviceInfo).copyWith(isPinRequired: settings.requiredPin);
  final viewmodel = DiscoveryViewmodel(
    DiscoveryRepository(),
    effectiveDeviceInfo,
  );
  viewmodel.init();
  return viewmodel;
});

final myIpProvider = Provider<String?>((ref) {
  ref.watch(peerListProvider);
  final notifier = ref.read(peerListProvider.notifier);
  return notifier.myIp;
});
