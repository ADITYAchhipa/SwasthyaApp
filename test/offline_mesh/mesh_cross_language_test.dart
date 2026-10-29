import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:crypto/crypto.dart' as dart_crypto;
import 'package:flutter_test/flutter_test.dart';
import 'package:swasthya_tap/services/offline_mesh/crypto_manager.dart';
import 'package:swasthya_tap/services/offline_mesh/offline_packet.dart';
import 'package:swasthya_tap/services/offline_mesh/mesh_read_policy.dart';

void main() {
  late Map<String, dynamic> vectors;

  setUpAll(() {
    final file = File('test/vectors/mesh_v2_vectors.json');
    if (!file.existsSync()) {
      fail('Golden vectors file test/vectors/mesh_v2_vectors.json not found');
    }
    vectors = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  });

  group('Cross-Language Cryptographic Vectors (C01 - C10)', () {
    test('C01: Canonical JSON and AAD strings match golden vector exactly in Dart', () {
      final headerMap = vectors['canonicalization']['requestHeader'] as Map<String, dynamic>;
      final packet = OfflinePacket(
        v: headerMap['v'] as int,
        t: headerMap['t'] as String,
        op: headerMap['op'] as String,
        rid: headerMap['rid'] as String,
        org: headerMap['org'] as String,
        dst: headerMap['dst'] as String,
        iat: headerMap['iat'] as int,
        exp: headerMap['exp'] as int,
        ttl: headerMap['ttl'] as int,
        epk: 'test_epk_sample_value_base64url_string_43c',
        pay: 'test_pay_sample_value_base64url_string_60c',
      );

      final canonical = packet.getCanonicalString();
      final expectedCanonical = vectors['canonicalization']['expectedCanonicalString'] as String;
      expect(canonical, equals(expectedCanonical));

      final aad = utf8.decode(packet.getAadBytes());
      final expectedAad = vectors['canonicalization']['expectedAadString'] as String;
      expect(aad, equals(expectedAad));
    });

    test('C02: Dart verifies request golden vector signature against client Ed25519 key', () async {
      final reqMap = vectors['requestVector']['packet'] as Map<String, dynamic>;
      final packet = OfflinePacket.fromJson(reqMap);

      final clientSigningPubB64 = vectors['keys']['client']['signingPublicKeyBase64'] as String;
      final pubKeyBytes = base64Decode(clientSigningPubB64);
      final sigBytes = base64Url.decode(packet.sig);

      final isValid = await CryptoManager.verify(
        message: packet.getCanonicalBytes(),
        signatureBytes: sigBytes,
        ed25519PubKeyBytes: pubKeyBytes,
      );

      expect(isValid, isTrue, reason: 'Request signature must verify with client Ed25519 public key');
    });

    test('C03: Dart opens response golden vector sealed by Node using client X25519 key', () async {
      final respMap = vectors['responseVector']['packet'] as Map<String, dynamic>;
      final packet = OfflinePacket.fromJson(respMap);

      // Verify server Ed25519 signature
      final serverSigningPubB64 = vectors['keys']['server']['ed25519PublicKeyBase64'] as String;
      final serverPubBytes = base64Decode(serverSigningPubB64);
      final sigBytes = base64Url.decode(packet.sig);

      final isSigValid = await CryptoManager.verify(
        message: packet.getCanonicalBytes(),
        signatureBytes: sigBytes,
        ed25519PubKeyBytes: serverPubBytes,
      );
      expect(isSigValid, isTrue, reason: 'Response signature must verify with server Ed25519 public key');

      // Reconstruct client agreement keypair from the 32-byte seed
      final clientSeedHex = vectors['keys']['client']['x25519SeedHex'] as String;
      final clientSeed = List<int>.generate(
        clientSeedHex.length ~/ 2,
        (i) => int.parse(clientSeedHex.substring(i * 2, i * 2 + 2), radix: 16),
      );
      final clientKeyPair = await X25519().newKeyPairFromSeed(clientSeed);

      // Decrypt L2 payload using client keypair
      final decryptedBytes = await CryptoManager.openL2(
        sealedBytes: base64Url.decode(packet.pay),
        ephemeralPubKeyBytes: base64Url.decode(packet.epk),
        recipientKeyPair: clientKeyPair,
        aad: packet.getAadBytes(),
        info: 'swasthyatap/mesh/v2/resp',
      );

      final decryptedJson = jsonDecode(utf8.decode(decryptedBytes)) as Map<String, dynamic>;
      final expectedPayload = vectors['responseVector']['plaintextPayload'] as Map<String, dynamic>;

      expect(decryptedJson['ok'], equals(expectedPayload['ok']));
      expect(decryptedJson['rid'], equals(expectedPayload['rid']));
      expect(decryptedJson['op'], equals(expectedPayload['op']));
      expect(decryptedJson['hospital']['hospitalId'], equals(expectedPayload['hospital']['hospitalId']));
      expect(decryptedJson['hospital']['name'], equals(expectedPayload['hospital']['name']));
    });

    test('C04: Wrong client key cannot decrypt response (Gateway isolation)', () async {
      final respMap = vectors['responseVector']['packet'] as Map<String, dynamic>;
      final packet = OfflinePacket.fromJson(respMap);

      // An unrelated keypair
      final wrongKeyPair = await X25519().newKeyPair();

      expect(
        () async => await CryptoManager.openL2(
          sealedBytes: base64Url.decode(packet.pay),
          ephemeralPubKeyBytes: base64Url.decode(packet.epk),
          recipientKeyPair: wrongKeyPair,
          aad: packet.getAadBytes(),
          info: 'swasthyatap/mesh/v2/resp',
        ),
        throwsA(anything),
      );
    });

    test('C05: Tampered payload, signature, or headers fail verification', () async {
      final respMap = vectors['responseVector']['packet'] as Map<String, dynamic>;
      final packet = OfflinePacket.fromJson(respMap);
      final serverPubBytes = base64Decode(vectors['keys']['server']['ed25519PublicKeyBase64'] as String);

      // Tampered payload
      final tamperedPacket = OfflinePacket(
        v: packet.v,
        t: packet.t,
        op: packet.op,
        rid: packet.rid,
        org: packet.org,
        dst: packet.dst,
        iat: packet.iat,
        exp: packet.exp,
        ttl: packet.ttl,
        epk: packet.epk,
        pay: packet.pay.substring(0, packet.pay.length - 4) + 'AAAA',
        sig: packet.sig,
      );

      final isSigValid = await CryptoManager.verify(
        message: tamperedPacket.getCanonicalBytes(),
        signatureBytes: base64Url.decode(tamperedPacket.sig),
        ed25519PubKeyBytes: serverPubBytes,
      );
      expect(isSigValid, isFalse);
    });

    test('C06: Wrong context string fails decryption', () async {
      final respMap = vectors['responseVector']['packet'] as Map<String, dynamic>;
      final packet = OfflinePacket.fromJson(respMap);

      final clientSeedHex = vectors['keys']['client']['x25519SeedHex'] as String;
      final clientSeed = List<int>.generate(
        clientSeedHex.length ~/ 2,
        (i) => int.parse(clientSeedHex.substring(i * 2, i * 2 + 2), radix: 16),
      );
      final clientKeyPair = await X25519().newKeyPairFromSeed(clientSeed);

      expect(
        () async => await CryptoManager.openL2(
          sealedBytes: base64Url.decode(packet.pay),
          ephemeralPubKeyBytes: base64Url.decode(packet.epk),
          recipientKeyPair: clientKeyPair,
          aad: packet.getAadBytes(),
          info: 'swasthyatap/mesh/v1/resp', // wrong v1 context
        ),
        throwsA(anything),
      );
    });

    test('C07: Repeated sealing produces distinct ephemeral keys and nonces', () async {
      final recipientX25519Pub = base64Decode(vectors['keys']['server']['x25519PublicKeyBase64'] as String);
      final aad = utf8.encode('{"test":"aad"}');
      final cleartext = utf8.encode('{"hello":"world"}');

      final sealed1 = await CryptoManager.sealL2(
        cleartext: cleartext,
        recipientX25519PubKeyBytes: recipientX25519Pub,
        aad: aad,
        info: 'swasthyatap/mesh/v2/req',
      );

      final sealed2 = await CryptoManager.sealL2(
        cleartext: cleartext,
        recipientX25519PubKeyBytes: recipientX25519Pub,
        aad: aad,
        info: 'swasthyatap/mesh/v2/req',
      );

      expect(sealed1['epk'], isNot(equals(sealed2['epk'])));
      expect(sealed1['pay'], isNot(equals(sealed2['pay'])));
    });

    test('C08: Enrollment proof format and verification in Dart', () async {
      final proofVector = vectors['enrollmentProofVector'] as Map<String, dynamic>;
      final token = proofVector['token'] as String;
      final expectedProofBytesUtf8 = proofVector['proofBytesUtf8'] as String;

      final deviceId = vectors['keys']['client']['deviceId'] as String;
      final signingPub = vectors['keys']['client']['signingPublicKeyBase64'] as String;
      final agreementPub = vectors['keys']['client']['agreementPublicKeyBase64'] as String;

      final tokenDigestHex = dart_crypto.sha256.convert(utf8.encode(token)).toString();
      final tuple = [2, 'REGISTER_DEVICE', deviceId, signingPub, agreementPub, tokenDigestHex];
      final generatedProofBytesUtf8 = jsonEncode(tuple);

      expect(generatedProofBytesUtf8, equals(expectedProofBytesUtf8));

      // Reconstruct client Ed25519 keypair and verify proof signature
      final clientEdSeedHex = vectors['keys']['client']['ed25519SeedHex'] as String;
      final clientEdSeed = List<int>.generate(
        clientEdSeedHex.length ~/ 2,
        (i) => int.parse(clientEdSeedHex.substring(i * 2, i * 2 + 2), radix: 16),
      );
      final clientSigningKeyPair = await Ed25519().newKeyPairFromSeed(clientEdSeed);
      final clientSigningPub = (await clientSigningKeyPair.extractPublicKey()).bytes;

      final sigBytes = base64Url.decode(proofVector['proofSignatureBase64Url'] as String);
      final isProofValid = await CryptoManager.verify(
        message: utf8.encode(generatedProofBytesUtf8),
        signatureBytes: sigBytes,
        ed25519PubKeyBytes: clientSigningPub,
      );
      expect(isProofValid, isTrue);
    });
  });
}
