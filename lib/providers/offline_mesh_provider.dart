import 'package:flutter/foundation.dart';
import 'package:swasthya_tap/services/offline_mesh/mesh_config.dart';
import 'package:swasthya_tap/services/offline_mesh/offline_mesh_manager.dart';

class OfflineMeshProvider extends ChangeNotifier {
  bool _consent = false;
  bool get consent => _consent;

  bool _backgroundRelay = false;
  bool get backgroundRelay => _backgroundRelay;

  bool get isMeshEnabled => MeshConfig.enabled;

  Future<void> init() async {
    _consent = await MeshConfig.getConsent();
    _backgroundRelay = await MeshConfig.getBackgroundRelay();
    notifyListeners();
  }

  Future<void> setConsent(bool value) async {
    _consent = value;
    await MeshConfig.setConsent(value);
    if (value) {
      await OfflineMeshManager.instance.bootstrap();
    } else {
      await OfflineMeshManager.instance.stop();
    }
    notifyListeners();
  }

  Future<void> setBackgroundRelay(bool value) async {
    _backgroundRelay = value;
    await MeshConfig.setBackgroundRelay(value);
    await OfflineMeshManager.instance.syncBackgroundService();
    notifyListeners();
  }
}
