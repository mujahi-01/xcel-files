import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/directory_rename.dart';
import '../services/workmanager_callback.dart';
import 'login_screen.dart';
import 'messages_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Bottom nav index
  int _navIndex = 0;

  // Current ON/OFF state
  bool _isOn = false;

  // Animation target colour for TURN ON / TURN OFF buttons
  Color _onColor = Colors.grey[800]!;
  Color _offColor = Colors.grey[800]!;

  bool _actionLoading = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _loadState();
    // Verify validity in the background
    _verifyValidityInBackground();
  }

  // ── Load persisted state ─────────────────────────────────────────────
  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final on = prefs.getBool('isOn') ?? false;
    setState(() {
      _isOn = on;
      _onColor = on ? Colors.green[700]! : Colors.grey[800]!;
      _offColor = on ? Colors.grey[800]! : Colors.red[700]!;
    });
  }

  // ── Background validity check ────────────────────────────────────────
  Future<void> _verifyValidityInBackground() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('username');
    if (username == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(username)
          .get();
      if (!doc.exists) {
        _forceLogout('Account not found.');
        return;
      }
      final Timestamp ts = doc.data()!['validity'] as Timestamp;
      if (ts.toDate().isBefore(DateTime.now())) {
        _forceLogout('Account expired.');
      }
    } catch (_) {
      // Silently ignore network errors; don't block the user offline.
    }
  }

  // ── Force logout ─────────────────────────────────────────────────────
  Future<void> _forceLogout(String reason) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(reason)));
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  // ── Request storage permission ───────────────────────────────────────
  Future<bool> _ensurePermission() async {
    // On Android 11+ (API 30+) we need MANAGE_EXTERNAL_STORAGE.
    // On older devices, WRITE_EXTERNAL_STORAGE is sufficient.
    PermissionStatus status = await Permission.manageExternalStorage.status;
    if (status.isGranted) return true;

    status = await Permission.manageExternalStorage.request();
    if (status.isGranted) return true;

    // Fallback: legacy storage permission
    PermissionStatus legacy = await Permission.storage.request();
    if (legacy.isGranted) return true;

    // Show dialog if both denied
    if (mounted) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Storage Permission Required'),
          content: const Text(
            'XCEL needs full storage access to rename the game '
            'directories.\n\nPlease grant "All files access" in Settings.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    }
    return false;
  }

  // ── TURN ON handler ──────────────────────────────────────────────────
  Future<void> _turnOn() async {
    if (_isOn || _actionLoading) return;

    final hasPermission = await _ensurePermission();
    if (!hasPermission) return;

    setState(() => _actionLoading = true);

    final result = await turnOnRename();

    if (result.success) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isOn', true);
      // Schedule auto turn-off after 4 hours
      await scheduleAutoTurnOff();
      setState(() {
        _isOn = true;
        _onColor = Colors.green[700]!;
        _offColor = Colors.grey[800]!;
        _statusMessage = result.message;
      });
    } else {
      setState(() => _statusMessage = result.message);
    }

    setState(() => _actionLoading = false);
  }

  // ── TURN OFF handler ─────────────────────────────────────────────────
  Future<void> _turnOff() async {
    if (!_isOn || _actionLoading) return;

    final hasPermission = await _ensurePermission();
    if (!hasPermission) return;

    setState(() => _actionLoading = true);

    final result = await turnOffRename();

    if (result.success) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isOn', false);
      // Cancel the scheduled auto task since user manually turned off
      await cancelAutoTurnOff();
      setState(() {
        _isOn = false;
        _onColor = Colors.grey[800]!;
        _offColor = Colors.red[700]!;
        _statusMessage = result.message;
      });
    } else {
      setState(() => _statusMessage = result.message);
    }

    setState(() => _actionLoading = false);
  }

  // ── Body pages for bottom nav ────────────────────────────────────────
  Widget _buildCurrentPage() {
    switch (_navIndex) {
      case 1:
        return const MessagesScreen();
      case 2:
        return const ProfileScreen();
      default:
        return _buildHomePage();
    }
  }

  // ── Home page content ────────────────────────────────────────────────
  Widget _buildHomePage() {
    return Column(
      children: [
        // ── Status indicator ────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Text(
            _isOn ? '● ACTIVE' : '● INACTIVE',
            style: TextStyle(
              color: _isOn ? Colors.green : Colors.red,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
            ),
          ),
        ),

        // ── TURN ON button ──────────────────────────────────────────
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: GestureDetector(
              onTap: _isOn ? null : _turnOn,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  color: _onColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green[900]!, width: 2),
                ),
                alignment: Alignment.center,
                child: _actionLoading && !_isOn
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.power_settings_new,
                              color: Colors.white, size: 56),
                          SizedBox(height: 12),
                          Text(
                            'TURN ON',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 4,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),

        // ── TURN OFF button ─────────────────────────────────────────
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: GestureDetector(
              onTap: _isOn ? _turnOff : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  color: _offColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.red[900]!, width: 2),
                ),
                alignment: Alignment.center,
                child: _actionLoading && _isOn
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.power_off, color: Colors.white, size: 56),
                          SizedBox(height: 12),
                          Text(
                            'TURN OFF',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 4,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),

        // ── Status message ──────────────────────────────────────────
        if (_statusMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            child: Text(
              _statusMessage!,
              style: TextStyle(
                color:
                    _statusMessage!.contains('success') || _statusMessage!.contains('successfully')
                        ? Colors.greenAccent
                        : Colors.redAccent,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ),

        // ── Telegram section ────────────────────────────────────────
        const _TelegramSection(),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.grey[850],
        title: const Text('XCEL', style: TextStyle(color: Colors.white, letterSpacing: 4)),
        centerTitle: true,
        elevation: 0,
      ),
      body: _buildCurrentPage(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _navIndex,
        backgroundColor: Colors.grey[850],
        selectedItemColor: Colors.blueGrey[300],
        unselectedItemColor: Colors.grey[600],
        onTap: (i) => setState(() => _navIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.message), label: 'Messages'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

// ── Telegram section widget ──────────────────────────────────────────────
class _TelegramSection extends StatelessWidget {
  const _TelegramSection();

  static const String _telegramUrl = 'https://t.me/thefalconsff';

  void _copy(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied: $text'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Heading – long-press to copy
          GestureDetector(
            onLongPress: () => _copy(context, 'Telegram'),
            child: const Text(
              'Telegram',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 6),
          // URL – long-press to copy
          GestureDetector(
            onLongPress: () => _copy(context, _telegramUrl),
            child: Text(
              _telegramUrl,
              style: const TextStyle(
                color: Colors.lightBlueAccent,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Long-press to copy',
            style: TextStyle(color: Colors.grey[500], fontSize: 11),
          ),
        ],
      ),
    );
  }
}
