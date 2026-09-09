import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:swasthya_tap/providers/offline_mesh_provider.dart';

class MeshSettingsTile extends StatelessWidget {
  const MeshSettingsTile({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<OfflineMeshProvider>(
      builder: (context, provider, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title: const Text(
                "Allow Offline Mesh Retrieval",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              subtitle: const Text(
                "Allow SwasthyaTap to use nearby devices for offline data retrieval",
                style: TextStyle(fontSize: 13),
              ),
              value: provider.consent,
              activeColor: Colors.teal,
              onChanged: (bool value) async {
                if (value) {
                  // Show the one-time explainer
                  final proceed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: const Text("Offline Mesh Participation"),
                      content: const Text(
                        "Enabling this feature allows your device to securely and anonymously "
                        "forward encrypted medical data requests and responses for other nearby users. "
                        "No medical records or sensitive data will be readable by your device.",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text("Cancel", style: TextStyle(color: Colors.black54)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text("Enable", style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                  if (proceed == true) {
                    await provider.setConsent(true);
                  }
                } else {
                  await provider.setConsent(false);
                }
              },
            ),
            const Divider(),
          ],
        );
      },
    );
  }
}
