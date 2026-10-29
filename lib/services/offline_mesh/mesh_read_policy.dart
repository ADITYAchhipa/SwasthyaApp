/// Approved mesh read operations with cryptographic validation and role-based access.
class MeshReadPolicy {
  static const operation = 'READ_HOSPITAL';
  static const readPatientOp = 'READ_PATIENT';
  static const approvedOperations = ['READ_HOSPITAL', 'READ_PATIENT'];
  static const version = 2;
  static const maxLifetimeSeconds = 120;
  static const maxPacketBytes = 96 * 1024;
  static const maxHops = 8;

  static bool validHospitalId(String id) =>
      RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(id);

  static bool validPatientId(String id) =>
      RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(id);
}
