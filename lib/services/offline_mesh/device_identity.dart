import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DeviceIdentity {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  static const String _kEd25519Private = 'mesh_ed25519_private';
  static const String _kEd25519Public = 'mesh_ed25519_public';
  static const String _kX25519Private = 'mesh_x25519_private';
  static const String _kX25519Public = 'mesh_x25519_public';
  static const String _kDeviceId = 'mesh_device_id';
  static const String _kDestinationToken = 'mesh_destination_token';
  static const String _kServerSigningPublic = 'mesh_server_signing_public';
  static const String _kServerAgreementPublic = 'mesh_server_agreement_public';

  final SimpleKeyPair signingKeyPair;     // Ed25519
  final SimpleKeyPair agreementKeyPair;   // X25519
  final String deviceId;
  String? destinationToken;
  List<int>? serverSigningPublicKey;
  List<int>? serverAgreementPublicKey;

  DeviceIdentity({
    required this.signingKeyPair,
    required this.agreementKeyPair,
    required this.deviceId,
    this.destinationToken,
    this.serverSigningPublicKey,
    this.serverAgreementPublicKey,
  });

  static DeviceIdentity? _instance;
  static DeviceIdentity get instance => _instance!;
  static bool get hasInstance => _instance != null;

  /// Load from secure storage or generate a new identity if none exists.
  static Future<DeviceIdentity> loadOrCreate() async {
    final edPrivateB64 = await _storage.read(key: _kEd25519Private);
    final edPublicB64 = await _storage.read(key: _kEd25519Public);
    final xPrivateB64 = await _storage.read(key: _kX25519Private);
    final xPublicB64 = await _storage.read(key: _kX25519Public);
    final storedDeviceId = await _storage.read(key: _kDeviceId);
    final storedDestToken = await _storage.read(key: _kDestinationToken);
    final storedServerSignPub = await _storage.read(key: _kServerSigningPublic);
    final storedServerAgreePub = await _storage.read(key: _kServerAgreementPublic);

    if (edPrivateB64 != null &&
        edPublicB64 != null &&
        xPrivateB64 != null &&
        xPublicB64 != null &&
        storedDeviceId != null) {
      final signingKeyPair = SimpleKeyPairData(
        base64Decode(edPrivateB64),
        publicKey: SimplePublicKey(base64Decode(edPublicB64), type: KeyPairType.ed25519),
        type: KeyPairType.ed25519,
      );

      final agreementKeyPair = SimpleKeyPairData(
        base64Decode(xPrivateB64),
        publicKey: SimplePublicKey(base64Decode(xPublicB64), type: KeyPairType.x25519),
        type: KeyPairType.x25519,
      );

      _instance = DeviceIdentity(
        signingKeyPair: signingKeyPair,
        agreementKeyPair: agreementKeyPair,
        deviceId: storedDeviceId,
        destinationToken: storedDestToken,
        serverSigningPublicKey: storedServerSignPub != null ? base64Decode(storedServerSignPub) : null,
        serverAgreementPublicKey: storedServerAgreePub != null ? base64Decode(storedServerAgreePub) : null,
      );
      return _instance!;
    }

    // Generate brand new keys
    final ed25519Algo = Ed25519();
    final x25519Algo = X25519();

    final newEdKeyPair = await ed25519Algo.newKeyPair();
    final newXKeyPair = await x25519Algo.newKeyPair();

    final edPrivBytes = await newEdKeyPair.extractPrivateKeyBytes();
    final edPub = await newEdKeyPair.extractPublicKey();
    final edPubBytes = edPub.bytes;

    final xPrivBytes = await newXKeyPair.extractPrivateKeyBytes();
    final xPub = await newXKeyPair.extractPublicKey();
    final xPubBytes = xPub.bytes;

    // deviceId : base64url(SHA-256(ed25519_pub))[0..32]
    final hashBytes = sha256.convert(edPubBytes).bytes;
    final encoded = base64Url.encode(hashBytes).replaceAll('=', '');
    final deviceId = encoded.length > 32 ? encoded.substring(0, 32) : encoded;

    // Write to secure storage
    await _storage.write(key: _kEd25519Private, value: base64Encode(edPrivBytes));
    await _storage.write(key: _kEd25519Public, value: base64Encode(edPubBytes));
    await _storage.write(key: _kX25519Private, value: base64Encode(xPrivBytes));
    await _storage.write(key: _kX25519Public, value: base64Encode(xPubBytes));
    await _storage.write(key: _kDeviceId, value: deviceId);

    final signingKeyPair = SimpleKeyPairData(
      edPrivBytes,
      publicKey: SimplePublicKey(edPubBytes, type: KeyPairType.ed25519),
      type: KeyPairType.ed25519,
    );

    final agreementKeyPair = SimpleKeyPairData(
      xPrivBytes,
      publicKey: SimplePublicKey(xPubBytes, type: KeyPairType.x25519),
      type: KeyPairType.x25519,
    );

    _instance = DeviceIdentity(
      signingKeyPair: signingKeyPair,
      agreementKeyPair: agreementKeyPair,
      deviceId: deviceId,
    );
    return _instance!;
  }

  /// Update server keys and destination token upon online enrollment.
  Future<void> updateEnrollment({
    required String destToken,
    required List<int> serverSignPub,
    required List<int> serverAgreePub,
  }) async {
    destinationToken = destToken;
    serverSigningPublicKey = serverSignPub;
    serverAgreementPublicKey = serverAgreePub;

    await _storage.write(key: _kDestinationToken, value: destToken);
    await _storage.write(key: _kServerSigningPublic, value: base64Encode(serverSignPub));
    await _storage.write(key: _kServerAgreementPublic, value: base64Encode(serverAgreePub));
  }

  /// Check if the device is enrolled/registered with the server.
  bool get isEnrolled => destinationToken != null && serverSigningPublicKey != null && serverAgreementPublicKey != null;

  /// Clear all stored identity details (for testing or reset purposes).
  static Future<void> clearIdentity() async {
    await _storage.delete(key: _kEd25519Private);
    await _storage.delete(key: _kEd25519Public);
    await _storage.delete(key: _kX25519Private);
    await _storage.delete(key: _kX25519Public);
    await _storage.delete(key: _kDeviceId);
    await _storage.delete(key: _kDestinationToken);
    await _storage.delete(key: _kServerSigningPublic);
    await _storage.delete(key: _kServerAgreementPublic);
    _instance = null;
  }
}
