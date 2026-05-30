import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'admin_screen.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _username;
  String _validityStr = '—';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _username = prefs.getString('username');
    if (_username != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_username)
            .get();
        if (doc.exists) {
          final ts = doc.data()!['validity'] as Timestamp?;
          if (ts != null) {
            _validityStr =
                DateFormat('dd MMM yyyy, hh:mm a').format(ts.toDate());
          }
        }
      } catch (_) {}
    }
    if (mounted) setState(() => _loading = false);
  }

  // ── Logout ────────────────────────────────────────────────────────────
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  // ── Admin password dialog ─────────────────────────────────────────────
  Future<void> _showAdminDialog() async {
    final ctrl = TextEditingController();
    String? err;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: Colors.grey[850],
          title: const Text('Admin Access',
              style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter admin password',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  filled: true,
                  fillColor: Colors.grey[800],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              if (err != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(err!, style: const TextStyle(color: Colors.red)),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                if (ctrl.text == 'Mujahi@admin') {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminScreen()),
                  );
                } else {
                  setS(() => err = 'Incorrect password.');
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey[700]),
              child: const Text('Enter'),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),

          // ── Avatar ───────────────────────────────────────────────
          CircleAvatar(
            radius: 48,
            backgroundColor: Colors.blueGrey[700],
            child: Text(
              (_username?.isNotEmpty == true
                      ? _username![0].toUpperCase()
                      : '?'),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),

          // ── Username ─────────────────────────────────────────────
          Text(
            _username ?? 'Unknown',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),

          // ── Info cards ───────────────────────────────────────────
          _InfoCard(label: 'Username', value: _username ?? '—'),
          const SizedBox(height: 12),
          _InfoCard(label: 'Valid Until', value: _validityStr),
          const SizedBox(height: 12),
          _InfoCard(label: 'Status', value: '● Active'),
          const SizedBox(height: 12),
          // Placeholder for future parameters
          _InfoCard(label: 'Plan', value: '—'),
          const SizedBox(height: 12),
          _InfoCard(label: 'Device Bound', value: 'Yes'),

          const SizedBox(height: 40),

          // ── Admin access button ───────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showAdminDialog,
              icon: const Icon(Icons.admin_panel_settings, color: Colors.orange),
              label: const Text('Admin Access',
                  style: TextStyle(color: Colors.orange)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.orange),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Logout ───────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              label: const Text('Logout',
                  style: TextStyle(color: Colors.redAccent)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reusable info card ───────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final String label;
  final String value;
  const _InfoCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(color: Colors.grey[400], fontSize: 13)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
