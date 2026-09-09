import 'package:flutter/foundation.dart';
import 'package:swasthya_tap/services/offline_mesh/mesh_config.dart';

class OfflineMeshProvider extends ChangeNotifier {
  bool _consent = false;
  bool get consent => _consent;

  bool get isMeshEnabled => MeshConfig.enabled;

  Future<void> init() async {
    _consent = await MeshConfig.getConsent();
    notifyListeners();
  }

  Future<void> setConsent(bool value) async {
    _consent = value;
    await MeshConfig.setConsent(value);
    notifyListeners();
  }
}
