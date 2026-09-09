import 'package:swasthya_tap/models/models.dart';
import 'package:swasthya_tap/services/api_service.dart';
import 'package:swasthya_tap/services/offline_mesh/mesh_config.dart';
import 'package:swasthya_tap/services/offline_mesh/network_manager.dart';
import 'package:swasthya_tap/services/offline_mesh/offline_mesh_manager.dart';

class MedicalDataGateway {
  /// Fetches citizen medical data using online-first flow with offline mesh fallback.
  static Future<MedicalFetchResult> fetchCitizen(
    String idOrToken, {
    void Function(MeshUiState)? onProgress,
  }) async {
    // 1. Online path - checks real internet reachability
    if (await NetworkManager.instance.isInternetAvailable()) {
      final profile = await ApiService.getCitizenOnlineOnly(idOrToken);
      if (profile != null) {
        return MedicalFetchResult.online(profile);
      }
    }

    // 2. Offline Mesh path - if enabled & usable
    final consent = await MeshConfig.getConsent();
    if (MeshConfig.enabled && consent && await OfflineMeshManager.instance.isUsable()) {
      return await OfflineMeshManager.instance.requestMedicalData(
        idOrToken,
        onProgress: onProgress,
      );
    }

    // 3. Local/Mock fallback (maintains existing app demo mode behavior)
    final fallbackProfile = await ApiService.getCitizen(idOrToken);
    return MedicalFetchResult.localCache(fallbackProfile);
  }
}
