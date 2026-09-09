import 'package:nearby_connections/nearby_connections.dart';

void main() {
  Nearby().acceptConnection('', onPayloadReceived: (a, b) {});
}
