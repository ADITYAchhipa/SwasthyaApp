import 'package:flutter_test/flutter_test.dart';
import 'package:swasthya_tap/services/offline_mesh/mesh_config.dart';
import 'package:swasthya_tap/services/offline_mesh/mesh_read_policy.dart';
import 'package:swasthya_tap/services/offline_mesh/offline_mesh_manager.dart';
import 'package:swasthya_tap/services/offline_mesh/offline_packet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Mobile Policy & Envelope Validation (M01 - M03)', () {
    test('M01: MeshReadPolicy identifier grammar and closed operation', () {
      expect(MeshReadPolicy.operation, equals('READ_HOSPITAL'));
      expect(MeshReadPolicy.version, equals(2));
      expect(MeshReadPolicy.maxHops, equals(8));
      expect(MeshReadPolicy.maxLifetimeSeconds, equals(120));
      expect(MeshReadPolicy.maxPacketBytes, equals(96 * 1024));

      // Valid IDs
      expect(MeshReadPolicy.validHospitalId('HOSP_123'), isTrue);
      expect(MeshReadPolicy.validHospitalId('hosp-456_abc'), isTrue);
      expect(MeshReadPolicy.validHospitalId('h1'), isTrue);

      // Invalid IDs
      expect(MeshReadPolicy.validHospitalId(''), isFalse);
      expect(MeshReadPolicy.validHospitalId('HOSP 123'), isFalse); // spaces
      expect(MeshReadPolicy.validHospitalId('../hospitals/123'), isFalse); // path traversal
      expect(MeshReadPolicy.validHospitalId('HOSP/123'), isFalse); // slashes
      expect(MeshReadPolicy.validHospitalId('HOSP_123;DROP TABLE'), isFalse); // SQL injection
      expect(MeshReadPolicy.validHospitalId('a' * 81), isFalse); // > 80 chars
    });

    test('M01: Direct requestMedicalData returns unauthorized without queuing', () async {
      final result = await OfflineMeshManager.instance.requestMedicalData('patient_slug_123');
      expect(result.failure, equals(MeshFailure.unauthorized));
      expect(result.profile, isNull);
    });

    test('M02: OfflinePacket.isValidReadPacket strictly enforces v2 read envelope', () {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final valid = OfflinePacket(
        v: 2,
        t: 'MEDICAL_DATA_REQUEST',
        op: 'READ_HOSPITAL',
        rid: '550e8400-e29b-41d4-a716-446655440000',
        org: 'a' * 32,
        dst: 'b' * 43,
        iat: now,
        exp: now + 60,
        ttl: 5,
        epk: 'c' * 43,
        pay: 'd' * 40,
        sig: 'e' * 86,
      );
      expect(valid.isValidReadPacket(now: now), isTrue);

      // Version mismatch
      final badVersion = OfflinePacket(
        v: 1,
        t: valid.t,
        op: valid.op,
        rid: valid.rid,
        org: valid.org,
        dst: valid.dst,
        iat: valid.iat,
        exp: valid.exp,
        ttl: valid.ttl,
        epk: valid.epk,
        pay: valid.pay,
        sig: valid.sig,
      );
      expect(badVersion.isValidReadPacket(now: now), isFalse);

      // Operation mismatch
      final badOp = OfflinePacket(
        v: valid.v,
        t: valid.t,
        op: 'FETCH_CITIZEN',
        rid: valid.rid,
        org: valid.org,
        dst: valid.dst,
        iat: valid.iat,
        exp: valid.exp,
        ttl: valid.ttl,
        epk: valid.epk,
        pay: valid.pay,
        sig: valid.sig,
      );
      expect(badOp.isValidReadPacket(now: now), isFalse);

      // Expired packet
      final expired = OfflinePacket(
        v: valid.v,
        t: valid.t,
        op: valid.op,
        rid: valid.rid,
        org: valid.org,
        dst: valid.dst,
        iat: now - 100,
        exp: now - 10,
        ttl: valid.ttl,
        epk: valid.epk,
        pay: valid.pay,
        sig: valid.sig,
      );
      expect(expired.isValidReadPacket(now: now), isFalse);

      // Excessive TTL (> 8)
      final excessiveTtl = OfflinePacket(
        v: valid.v,
        t: valid.t,
        op: valid.op,
        rid: valid.rid,
        org: valid.org,
        dst: valid.dst,
        iat: valid.iat,
        exp: valid.exp,
        ttl: 9,
        epk: valid.epk,
        pay: valid.pay,
        sig: valid.sig,
      );
      expect(excessiveTtl.isValidReadPacket(now: now), isFalse);
    });

    test('M03: MeshConfig defaults off and enforces build flag and remote lease', () {
      expect(MeshConfig.kEnabledAtBuild, isFalse);
      expect(MeshConfig.enabled, isFalse);
      expect(MeshConfig.allowMeteredGatewayUpload, isFalse);
    });
  });
}
