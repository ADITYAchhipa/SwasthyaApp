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
                "Offline Mesh Relay Participation",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              subtitle: const Text(
                "Allow SwasthyaTap to forward encrypted hospital directory traffic for nearby devices",
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
                        "Enabling this feature allows your device to forward encrypted "
                        "hospital directory data requests and responses for other nearby users. "
                        "Protected request details and returned hospital records remain encrypted "
                        "and cannot be decrypted by intermediate devices.",
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
            if (provider.consent) ...[
              Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: SwitchListTile(
                  title: const Text(
                    "Background Relay",
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: const Text(
                    "Keep relay listening when the app is closed (uses battery and displays persistent notification)",
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  value: provider.backgroundRelay,
                  activeColor: Colors.teal,
                  onChanged: (bool value) async {
                    await provider.setBackgroundRelay(value);
                  },
                ),
              ),
            ],
            const Divider(),
          ],
        );
      },
    );
  }
}
