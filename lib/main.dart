import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/workmanager_callback.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Firebase ────────────────────────────────────────────────────────────
  await Firebase.initializeApp();

  // ── Workmanager ─────────────────────────────────────────────────────────
  // callbackDispatcher is defined in services/workmanager_callback.dart.
  // It must be a top-level function (required by Workmanager).
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

  // ── Decide initial route ─────────────────────────────────────────────
  final prefs = await SharedPreferences.getInstance();
  final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  runApp(XcelApp(startLoggedIn: isLoggedIn));
}

class XcelApp extends StatelessWidget {
  final bool startLoggedIn;
  const XcelApp({super.key, required this.startLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'XCEL',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      // Show HomeScreen directly if auto-login flag is set, otherwise Login.
      home: startLoggedIn ? const HomeScreen() : const LoginScreen(),
    );
  }
}
