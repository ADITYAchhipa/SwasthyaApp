import 'dart:convert';

class OfflinePacket {
  final int v;                  // packet version, always 1
  final String t;               // packet type: REQUEST | RESPONSE | HANDSHAKE_INIT | HANDSHAKE_ACK | ACK
  final String rid;             // request_id (uuid)
  final String org;             // origin_device_id_hash
  final String dst;             // destination_token
  final int iat;                // created_at unix timestamp (sec)
  final int exp;                // expires_at unix timestamp (sec)
  int ttl;                      // mutable ttl
  final String epk;             // ephemeral key (base64url)
  final String pay;             // payload (base64url)
  String sig;                   // signature (base64url)

  OfflinePacket({
    required this.v,
    required this.t,
    required this.rid,
    required this.org,
    this.dst = '',
    required this.iat,
    required this.exp,
    required this.ttl,
    this.epk = '',
    this.pay = '',
    this.sig = '',
  });

  Map<String, dynamic> toSignMap() {
    return {
      'v': v,
      't': t,
      'rid': rid,
      'org': org,
      'dst': dst,
      'iat': iat,
      'exp': exp,
      'epk': epk,
      'pay': pay,
    };
  }

  /// Serialize the signature region to canonical JSON format (sorted keys, no whitespace).
  String getCanonicalString() {
    final map = toSignMap();
    final sortedKeys = map.keys.toList()..sort();
    final buffer = StringBuffer('{');
    for (int i = 0; i < sortedKeys.length; i++) {
      final key = sortedKeys[i];
      final value = map[key];
      if (i > 0) buffer.write(',');
      buffer.write('"$key":');
      buffer.write(jsonEncode(value));
    }
    buffer.write('}');
    return buffer.toString();
  }

  List<int> getCanonicalBytes() {
    return utf8.encode(getCanonicalString());
  }

  /// Get Additional Authenticated Data (AAD) bytes for L2 encryption (excludes pay and sig).
  List<int> getAadBytes() {
    final map = {
      'v': v,
      't': t,
      'rid': rid,
      'org': org,
      'dst': dst,
      'iat': iat,
      'exp': exp,
      'epk': epk,
    };
    final sortedKeys = map.keys.toList()..sort();
    final buffer = StringBuffer('{');
    for (int i = 0; i < sortedKeys.length; i++) {
      final key = sortedKeys[i];
      final value = map[key];
      if (i > 0) buffer.write(',');
      buffer.write('"$key":');
      buffer.write(jsonEncode(value));
    }
    buffer.write('}');
    return utf8.encode(buffer.toString());
  }

  Map<String, dynamic> toJson() {
    return {
      'v': v,
      't': t,
      'rid': rid,
      'org': org,
      'dst': dst,
      'iat': iat,
      'exp': exp,
      'ttl': ttl,
      'epk': epk,
      'pay': pay,
      'sig': sig,
    };
  }

  factory OfflinePacket.fromJson(Map<String, dynamic> json) {
    return OfflinePacket(
      v: json['v'] as int,
      t: json['t'] as String,
      rid: json['rid'] as String,
      org: json['org'] as String,
      dst: json['dst'] as String? ?? '',
      iat: json['iat'] as int,
      exp: json['exp'] as int,
      ttl: json['ttl'] as int,
      epk: json['epk'] as String? ?? '',
      pay: json['pay'] as String? ?? '',
      sig: json['sig'] as String? ?? '',
    );
  }
}
