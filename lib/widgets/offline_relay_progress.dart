import 'package:flutter/material.dart';
import 'package:swasthya_tap/services/offline_mesh/offline_mesh_manager.dart';

class OfflineRelayProgress extends StatelessWidget {
  final MeshUiState state;

  const OfflineRelayProgress({Key? key, required this.state}) : super(key: key);

  String _getMessage() {
    switch (state) {
      case MeshUiState.offline:
        return "You're offline";
      case MeshUiState.searching:
        return "Searching nearby SwasthyaTap devices…";
      case MeshUiState.relayFound:
        return "Secure relay found";
      case MeshUiState.sent:
        return "Request sent through a nearby device";
      case MeshUiState.awaiting:
        return "Retrieving hospital directory data…";
      case MeshUiState.received:
        return "Hospital directory snapshot received";
      case MeshUiState.failed:
        return "Unable to retrieve hospital data offline. Patient records require an active internet connection.";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            state == MeshUiState.failed ? "Mesh Operation Failed" : "Hospital Directory Mesh Retrieval",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          if (state != MeshUiState.failed && state != MeshUiState.received)
            const CircularProgressIndicator()
          else if (state == MeshUiState.failed)
            const Icon(Icons.error_outline, color: Colors.red, size: 48)
          else
            const Icon(Icons.check_circle_outline, color: Colors.green, size: 48),
          const SizedBox(height: 20),
          Text(
            _getMessage(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: state == MeshUiState.failed ? Colors.red : Colors.black87,
            ),
          ),
          const SizedBox(height: 24),
          if (state == MeshUiState.failed || state == MeshUiState.received)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text("Close"),
              ),
            ),
        ],
      ),
    );
  }
}

void showMeshProgressSheet(BuildContext context, ValueNotifier<MeshUiState> stateNotifier) {
  showModalBottomSheet(
    context: context,
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return ValueListenableBuilder<MeshUiState>(
        valueListenable: stateNotifier,
        builder: (context, state, _) {
          return OfflineRelayProgress(state: state);
        },
      );
    },
  );
}
