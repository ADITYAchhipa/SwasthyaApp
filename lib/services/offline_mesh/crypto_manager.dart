import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

class CryptoManager {
  static final _aesGcm = AesGcm.with256bits();
  static final _chacha20 = Chacha20.poly1305Aead();
  static final _ed25519 = Ed25519();
  static final _x25519 = X25519();

  /// Seal L2 payload from device to backend (or vice-versa).
  /// Info specifies the context (e.g. 'swasthyatap/mesh/v1/req' or 'swasthyatap/mesh/v1/resp').
  /// Returns a Map with 'epk' (base64url ephemeral pubkey) and 'pay' (base64url ciphertext||tag).
  static Future<Map<String, String>> sealL2({
    required List<int> cleartext,
    required List<int> recipientX25519PubKeyBytes,
    required List<int> aad,
    required String info,
  }) async {
    // Generate ephemeral X25519 keypair
    final ephemeralKeyPair = await _x25519.newKeyPair();
    final ephemeralPublicKey = await ephemeralKeyPair.extractPublicKey();
    final ephemeralPubKeyBytes = ephemeralPublicKey.bytes;

    final recipientPubKey = SimplePublicKey(
      recipientX25519PubKeyBytes,
      type: KeyPairType.x25519,
    );

    // Compute DH shared secret
    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: ephemeralKeyPair,
      remotePublicKey: recipientPubKey,
    );

    // Derive symmetric key via HKDF-SHA256
    final hkdf = Hkdf(hmac: Hmac(Sha256()), outputLength: 32);
    final derivedKey = await hkdf.deriveKey(
      secretKey: sharedSecret,
      nonce: const [], // Salt is empty
      info: utf8.encode(info),
    );

    // Generate random 12-byte nonce
    final nonce = _aesGcm.newNonce();

    // Encrypt with AES-256-GCM
    final secretBox = await _aesGcm.encrypt(
      cleartext,
      secretKey: derivedKey,
      nonce: nonce,
      aad: aad,
    );

    // Payload = nonce (12 bytes) || ciphertext || tag (16 bytes)
    final sealedBytes = Uint8List(12 + secretBox.cipherText.length + secretBox.mac.bytes.length);
    sealedBytes.setRange(0, 12, nonce);
    sealedBytes.setRange(12, 12 + secretBox.cipherText.length, secretBox.cipherText);
    sealedBytes.setRange(12 + secretBox.cipherText.length, sealedBytes.length, secretBox.mac.bytes);

    return {
      'epk': base64Url.encode(ephemeralPubKeyBytes).replaceAll('=', ''),
      'pay': base64Url.encode(sealedBytes).replaceAll('=', ''),
    };
  }

  /// Open sealed L2 payload received by device (or backend).
  /// Info specifies the context (e.g. 'swasthyatap/mesh/v1/req' or 'swasthyatap/mesh/v1/resp').
  /// Returns the decrypted cleartext.
  static Future<List<int>> openL2({
    required List<int> sealedBytes,
    required List<int> ephemeralPubKeyBytes,
    required SimpleKeyPair recipientKeyPair,
    required List<int> aad,
    required String info,
  }) async {
    if (sealedBytes.length < 12 + 16) {
      throw Exception('Sealed payload is too short');
    }

    // Extract nonce, ciphertext, and tag
    final nonce = sealedBytes.sublist(0, 12);
    final tag = sealedBytes.sublist(sealedBytes.length - 16);
    final ciphertext = sealedBytes.sublist(12, sealedBytes.length - 16);

    final ephemeralPubKey = SimplePublicKey(
      ephemeralPubKeyBytes,
      type: KeyPairType.x25519,
    );

    // Compute DH shared secret
    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: recipientKeyPair,
      remotePublicKey: ephemeralPubKey,
    );

    // Derive symmetric key via HKDF-SHA256
    final hkdf = Hkdf(hmac: Hmac(Sha256()), outputLength: 32);
    final derivedKey = await hkdf.deriveKey(
      secretKey: sharedSecret,
      nonce: const [],
      info: utf8.encode(info),
    );

    // Decrypt using AES-256-GCM
    final secretBox = SecretBox(
      ciphertext,
      nonce: nonce,
      mac: Mac(tag),
    );

    return await _aesGcm.decrypt(
      secretBox,
      secretKey: derivedKey,
      aad: aad,
    );
  }

  /// Sign message with Ed25519 private key.
  static Future<List<int>> sign({
    required List<int> message,
    required SimpleKeyPair keyPair,
  }) async {
    final signature = await _ed25519.sign(message, keyPair: keyPair);
    return signature.bytes;
  }

  /// Verify Ed25519 signature of message.
  static Future<bool> verify({
    required List<int> message,
    required List<int> signatureBytes,
    required List<int> ed25519PubKeyBytes,
  }) async {
    try {
      final publicKey = SimplePublicKey(
        ed25519PubKeyBytes,
        type: KeyPairType.ed25519,
      );
      final signature = Signature(
        signatureBytes,
        publicKey: publicKey,
      );
      return await _ed25519.verify(message, signature: signature);
    } catch (_) {
      return false;
    }
  }

  /// Derive L1 symmetric session key from ECDH shared secret + both nonces.
  static Future<SecretKey> deriveL1SessionKey({
    required SimpleKeyPair myKeyPair,
    required List<int> peerX25519PubKeyBytes,
    required List<int> nonceA,
    required List<int> nonceB,
  }) async {
    final peerPubKey = SimplePublicKey(
      peerX25519PubKeyBytes,
      type: KeyPairType.x25519,
    );

    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: myKeyPair,
      remotePublicKey: peerPubKey,
    );

    final salt = [...nonceA, ...nonceB];
    final hkdf = Hkdf(hmac: Hmac(Sha256()), outputLength: 32);

    return await hkdf.deriveKey(
      secretKey: sharedSecret,
      nonce: salt,
      info: utf8.encode('swasthyatap/mesh/v1/session'),
    );
  }

  /// Encrypt frame at L1 (hop-by-hop session layer) using ChaCha20-Poly1305.
  /// Prepend random 12-byte nonce to output: nonce (12 bytes) || ciphertext || tag (16 bytes).
  static Future<List<int>> encryptL1({
    required List<int> cleartext,
    required SecretKey sessionKey,
  }) async {
    final nonce = _chacha20.newNonce();
    final secretBox = await _chacha20.encrypt(
      cleartext,
      secretKey: sessionKey,
      nonce: nonce,
    );

    final sealedBytes = Uint8List(12 + secretBox.cipherText.length + secretBox.mac.bytes.length);
    sealedBytes.setRange(0, 12, nonce);
    sealedBytes.setRange(12, 12 + secretBox.cipherText.length, secretBox.cipherText);
    sealedBytes.setRange(12 + secretBox.cipherText.length, sealedBytes.length, secretBox.mac.bytes);

    return sealedBytes;
  }

  /// Decrypt frame at L1 (hop-by-hop session layer) using ChaCha20-Poly1305.
  static Future<List<int>> decryptL1({
    required List<int> sealedBytes,
    required SecretKey sessionKey,
  }) async {
    if (sealedBytes.length < 12 + 16) {
      throw Exception('L1 sealed payload is too short');
    }

    final nonce = sealedBytes.sublist(0, 12);
    final tag = sealedBytes.sublist(sealedBytes.length - 16);
    final ciphertext = sealedBytes.sublist(12, sealedBytes.length - 16);

    final secretBox = SecretBox(
      ciphertext,
      nonce: nonce,
      mac: Mac(tag),
    );

    return await _chacha20.decrypt(
      secretBox,
      secretKey: sessionKey,
    );
  }
}
