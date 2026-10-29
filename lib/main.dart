import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'providers/swasthya_tap_provider.dart';
import 'providers/offline_mesh_provider.dart';
import 'services/offline_mesh/offline_mesh_manager.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Bootstrap Offline Mesh
  final meshManager = OfflineMeshManager.instance;
  unawaited(meshManager.bootstrap());

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SwasthyaTapProvider()),
        ChangeNotifierProvider(create: (_) => OfflineMeshProvider()..init()),
      ],
      child: const SwasthyaTapApp(),
    ),
  );
}

class SwasthyaTapApp extends StatelessWidget {
  const SwasthyaTapApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Swasthya Tap',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const SplashScreen(),
    );
  }
}

