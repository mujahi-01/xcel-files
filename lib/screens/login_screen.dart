import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── Retrieve Android ID as unique device identifier ──────────────────
  Future<String> _getDeviceId() async {
    final info = DeviceInfoPlugin();
    final android = await info.androidInfo;
    return android.id; // stable hardware ID
  }

  // ── Core login logic ─────────────────────────────────────────────────
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    try {
      // 1. Fetch user document from Firestore (doc ID = username)
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(username)
          .get();

      if (!doc.exists) {
        _setError('User not found.');
        return;
      }

      final data = doc.data()!;

      // 2. Verify password
      if (data['password'] != password) {
        _setError('Incorrect password.');
        return;
      }

      // 3. Check validity (Firestore Timestamp)
      final Timestamp validityTs = data['validity'] as Timestamp;
      if (validityTs.toDate().isBefore(DateTime.now())) {
        _setError('Account expired. Please contact admin.');
        return;
      }

      // 4. One-device-per-user check
      final currentDeviceId = await _getDeviceId();
      final storedDeviceId = data['deviceId'] as String?;

      if (storedDeviceId == null) {
        // First login on any device – bind device
        await FirebaseFirestore.instance
            .collection('users')
            .doc(username)
            .update({'deviceId': currentDeviceId});
      } else if (storedDeviceId != currentDeviceId) {
        _setError('This account is already used on another device.');
        return;
      }

      // 5. Persist login state in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('username', username);

      // 6. Navigate to Home
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      _setError('Login error: $e');
    }
  }

  void _setError(String msg) {
    setState(() {
      _isLoading = false;
      _errorMessage = msg;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Logo / title ─────────────────────────────────────
                const Text(
                  'XCEL',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Login to continue',
                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                ),
                const SizedBox(height: 40),

                // ── Username ──────────────────────────────────────────
                TextFormField(
                  controller: _usernameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Username', Icons.person),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter username' : null,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),

                // ── Password ──────────────────────────────────────────
                TextFormField(
                  controller: _passwordCtrl,
                  style: const TextStyle(color: Colors.white),
                  obscureText: _obscurePassword,
                  decoration: _inputDecoration(
                    'Password',
                    Icons.lock,
                    suffix: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Enter password' : null,
                  onFieldSubmitted: (_) => _login(),
                ),
                const SizedBox(height: 8),

                // ── Error message ─────────────────────────────────────
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.redAccent),
                      textAlign: TextAlign.center,
                    ),
                  ),

                const SizedBox(height: 24),

                // ── Login button ──────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('LOGIN',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Input decoration helper ──────────────────────────────────────────
  InputDecoration _inputDecoration(String label, IconData icon,
      {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey[400]),
      prefixIcon: Icon(icon, color: Colors.grey[500]),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.grey[800],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.blueGrey, width: 1.5),
      ),
    );
  }
}
