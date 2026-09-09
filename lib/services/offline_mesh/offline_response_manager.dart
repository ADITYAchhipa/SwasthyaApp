import 'dart:convert';
import 'package:swasthya_tap/services/offline_mesh/crypto_manager.dart';
import 'package:swasthya_tap/services/offline_mesh/device_identity.dart';
import 'package:swasthya_tap/services/offline_mesh/offline_packet.dart';
import 'package:swasthya_tap/services/offline_mesh/offline_request_manager.dart';

class OfflineResponseManager {
  static final OfflineResponseManager instance = OfflineResponseManager._internal();
  OfflineResponseManager._internal();

  /// Decrypts and validates an incoming RESPONSE packet, resolving the pending request if successful.
  Future<void> handleResponse(OfflinePacket packet) async {
    final myIdentity = DeviceIdentity.instance;

    // 1. Verify the server's Ed25519 signature
    final serverSigningKey = myIdentity.serverSigningPublicKey;
    if (serverSigningKey == null) {
      OfflineRequestManager.instance.failRequest(
        packet.rid,
        Exception('No server signing public key cached'),
      );
      return;
    }

    final isSigValid = await CryptoManager.verify(
      message: packet.getCanonicalBytes(),
      signatureBytes: base64Url.decode(packet.sig),
      ed25519PubKeyBytes: serverSigningKey,
    );

    if (!isSigValid) {
      OfflineRequestManager.instance.failRequest(
        packet.rid,
        Exception('Response packet signature verification failed'),
      );
      return;
    }

    // 2. Attempt L2 payload decryption
    try {
      final decryptedBytes = await CryptoManager.openL2(
        sealedBytes: base64Url.decode(packet.pay),
        ephemeralPubKeyBytes: base64Url.decode(packet.epk),
        recipientKeyPair: myIdentity.agreementKeyPair,
        aad: packet.getAadBytes(),
        info: 'swasthyatap/mesh/v1/resp',
      );

      final decryptedStr = utf8.decode(decryptedBytes);
      final decryptedJson = jsonDecode(decryptedStr) as Map<String, dynamic>;

      if (decryptedJson['ok'] == false) {
        final errorMsg = decryptedJson['error'] as String? ?? 'Data retrieval failed';
        OfflineRequestManager.instance.failRequest(packet.rid, Exception(errorMsg));
      } else {
        // Resolve request successfully
        OfflineRequestManager.instance.resolveRequest(packet.rid, packet);
      }
    } catch (e) {
      OfflineRequestManager.instance.failRequest(
        packet.rid,
        Exception('Failed to decrypt medical profile payload: $e'),
      );
    }
  }
}
