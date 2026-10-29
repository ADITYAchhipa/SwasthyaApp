import 'package:swasthya_tap/models/models.dart';
import 'package:swasthya_tap/services/api_service.dart';
import 'package:swasthya_tap/services/offline_mesh/mesh_config.dart';
import 'package:swasthya_tap/services/offline_mesh/network_manager.dart';
import 'package:swasthya_tap/services/offline_mesh/offline_mesh_manager.dart';

class MedicalDataGateway {
  /// Fetches citizen medical data using online-first flow with offline mesh fallback for authorized doctors.
  static Future<MedicalFetchResult> fetchCitizen(
    String idOrToken, {
    void Function(MeshUiState)? onProgress,
  }) async {
    // 1. Try online API first if internet is available
    if (await NetworkManager.instance.isInternetAvailable()) {
      final profile = await ApiService.getCitizen(idOrToken);
      if (profile != null) return MedicalFetchResult(profile: profile);
    }

    // 2. Offline Mesh Fallback: If mesh is enabled, attempt peer-to-peer relay
    if (MeshConfig.enabled) {
      final res = await OfflineMeshManager.instance.requestPatient(idOrToken, onProgress: onProgress);
      if (res != null && res['patient'] != null) {
        final profile = ApiService.parseCitizen(res['patient'] as Map<String, dynamic>);
        return MedicalFetchResult(
          profile: profile,
          source: 'mesh',
        );
      }
    }

    // 3. Fallback to local demo profile if network and mesh were unreachable
    final fallback = await ApiService.getCitizen(idOrToken);
    return MedicalFetchResult(profile: fallback);
  }

  static Future<Map<String, dynamic>?> fetchHospital(
    String hospitalId, {
    void Function(MeshUiState)? onProgress,
  }) async {
    if (await NetworkManager.instance.isInternetAvailable()) {
      return ApiService.getHospital(hospitalId);
    }
    if (!MeshConfig.enabled) return null;
    return OfflineMeshManager.instance.requestHospital(hospitalId, onProgress: onProgress);
  }
}
