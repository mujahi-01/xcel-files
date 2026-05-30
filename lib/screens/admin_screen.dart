import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _firestore = FirebaseFirestore.instance;
  int _tabIndex = 0; // 0 = Users, 1 = Create User, 2 = Send Message

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.grey[850],
        title: const Text('Admin Panel',
            style: TextStyle(color: Colors.orange, letterSpacing: 2)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          onTap: (i) => setState(() => _tabIndex = i),
          controller: null, // use manual state
          tabs: const [
            Tab(text: 'Users'),
            Tab(text: 'New User'),
            Tab(text: 'Message'),
          ],
          labelColor: Colors.orange,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.orange,
        ),
      ),
      body: IndexedStack(
        index: _tabIndex,
        children: [
          _UsersTab(firestore: _firestore),
          _CreateUserTab(firestore: _firestore),
          _SendMessageTab(firestore: _firestore),
        ],
      ),
    );
  }
}

// ── Tab 1: Users list ────────────────────────────────────────────────────
class _UsersTab extends StatelessWidget {
  final FirebaseFirestore firestore;
  const _UsersTab({required this.firestore});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: firestore.collection('users').snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
              child: Text('No users.', style: TextStyle(color: Colors.grey[400])));
        }
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final doc = docs[i];
            final data = doc.data() as Map<String, dynamic>;
            return _UserTile(doc: doc, data: data, firestore: firestore);
          },
        );
      },
    );
  }
}

class _UserTile extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final Map<String, dynamic> data;
  final FirebaseFirestore firestore;
  const _UserTile(
      {required this.doc, required this.data, required this.firestore});

  bool get _isActive {
    final deviceId = data['deviceId'] as String?;
    final ts = (data['validity'] as Timestamp?)?.toDate();
    return deviceId != null &&
        ts != null &&
        ts.isAfter(DateTime.now());
  }

  Future<void> _editValidity(BuildContext context) async {
    final current = (data['validity'] as Timestamp?)?.toDate() ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now(),
      lastDate: DateTime(2099),
    );
    if (picked == null) return;
    // Keep same time, update date
    final newDt = DateTime(
        picked.year, picked.month, picked.day, current.hour, current.minute);
    await firestore.collection('users').doc(doc.id).update({
      'validity': Timestamp.fromDate(newDt),
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Validity updated.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final validityTs = data['validity'] as Timestamp?;
    final validityStr = validityTs != null
        ? DateFormat('dd MMM yyyy').format(validityTs.toDate())
        : '—';
    final deviceId = data['deviceId'] as String? ?? 'Not bound';
    final password = data['password'] as String? ?? '';

    return Card(
      color: Colors.grey[850],
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Username + active badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(doc.id,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isActive ? Colors.green[800] : Colors.red[900],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _isActive ? 'Active' : 'Inactive',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Password (masked but selectable/copyable)
            SelectableText(
              'Password: ${'•' * password.length}  ($password)',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text('Valid until: $validityStr',
                style: TextStyle(color: Colors.grey[400], fontSize: 12)),
            const SizedBox(height: 4),
            SelectableText(
              'Device ID: $deviceId',
              style: TextStyle(color: Colors.grey[500], fontSize: 11),
            ),
            const SizedBox(height: 10),
            // Edit validity button
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _editValidity(context),
                icon: const Icon(Icons.edit_calendar,
                    size: 16, color: Colors.orange),
                label: const Text('Edit Validity',
                    style: TextStyle(color: Colors.orange, fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tab 2: Create new user ───────────────────────────────────────────────
class _CreateUserTab extends StatefulWidget {
  final FirebaseFirestore firestore;
  const _CreateUserTab({required this.firestore});

  @override
  State<_CreateUserTab> createState() => _CreateUserTabState();
}

class _CreateUserTabState extends State<_CreateUserTab> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  DateTime? _validityDate;
  bool _saving = false;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2099),
    );
    if (picked != null) setState(() => _validityDate = picked);
  }

  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) return;
    if (_validityDate == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please pick a validity date.')));
      return;
    }

    setState(() => _saving = true);

    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    try {
      // Check if user already exists
      final existing =
          await widget.firestore.collection('users').doc(username).get();
      if (existing.exists) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Username already exists.')));
        setState(() => _saving = false);
        return;
      }

      await widget.firestore.collection('users').doc(username).set({
        'password': password,
        'validity': Timestamp.fromDate(_validityDate!),
        'deviceId': null,
      });

      _usernameCtrl.clear();
      _passwordCtrl.clear();
      setState(() {
        _validityDate = null;
        _saving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('User created successfully.')));
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            const SizedBox(height: 12),
            _buildField(_usernameCtrl, 'Username', Icons.person),
            const SizedBox(height: 16),
            _buildField(_passwordCtrl, 'Password', Icons.lock),
            const SizedBox(height: 16),
            // Validity date picker
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: Colors.grey[500]),
                    const SizedBox(width: 12),
                    Text(
                      _validityDate != null
                          ? 'Valid until: ${DateFormat('dd MMM yyyy').format(_validityDate!)}'
                          : 'Pick validity date',
                      style: TextStyle(
                          color: _validityDate != null
                              ? Colors.white
                              : Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _createUser,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[700],
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('CREATE USER',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextFormField _buildField(
      TextEditingController ctrl, String label, IconData icon) {
    return TextFormField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[400]),
        prefixIcon: Icon(icon, color: Colors.grey[500]),
        filled: true,
        fillColor: Colors.grey[800],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.orange, width: 1.5),
        ),
      ),
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? 'Required field' : null,
    );
  }
}

// ── Tab 3: Send message to user ──────────────────────────────────────────
class _SendMessageTab extends StatefulWidget {
  final FirebaseFirestore firestore;
  const _SendMessageTab({required this.firestore});

  @override
  State<_SendMessageTab> createState() => _SendMessageTabState();
}

class _SendMessageTabState extends State<_SendMessageTab> {
  String? _selectedUser;
  final _msgCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_selectedUser == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Select a user first.')));
      return;
    }
    if (_msgCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Message cannot be empty.')));
      return;
    }

    setState(() => _sending = true);

    try {
      await widget.firestore.collection('messages').add({
        'userId': _selectedUser,
        'adminMessage': _msgCtrl.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'reply': null,
      });
      _msgCtrl.clear();
      setState(() {
        _selectedUser = null;
        _sending = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Message sent.')));
      }
    } catch (e) {
      setState(() => _sending = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 12),

          // ── User selector from Firestore ─────────────────────────
          FutureBuilder<QuerySnapshot>(
            future: widget.firestore.collection('users').get(),
            builder: (ctx, snap) {
              final users = snap.data?.docs.map((d) => d.id).toList() ?? [];
              return DropdownButtonFormField<String>(
                value: _selectedUser,
                dropdownColor: Colors.grey[850],
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Select User',
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.grey[800],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: users
                    .map((u) => DropdownMenuItem(
                          value: u,
                          child: Text(u,
                              style: const TextStyle(color: Colors.white)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedUser = v),
              );
            },
          ),
          const SizedBox(height: 16),

          // ── Message input ─────────────────────────────────────────
          TextField(
            controller: _msgCtrl,
            maxLines: 5,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Type message here…',
              hintStyle: TextStyle(color: Colors.grey[500]),
              filled: true,
              fillColor: Colors.grey[800],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.orange, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _sending ? null : _send,
              icon: const Icon(Icons.send),
              label: _sending
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('SEND MESSAGE',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey[700],
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
