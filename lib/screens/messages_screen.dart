import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  String? _username;
  final _replyControllers = <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    _loadUsername();
  }

  @override
  void dispose() {
    for (final c in _replyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _username = prefs.getString('username'));
  }

  // ── Send / update reply on a message document ────────────────────────
  Future<void> _sendReply(String docId, String replyText) async {
    if (replyText.trim().isEmpty) return;
    await FirebaseFirestore.instance
        .collection('messages')
        .doc(docId)
        .update({'reply': replyText.trim()});
  }

  TextEditingController _controllerFor(String docId) {
    return _replyControllers.putIfAbsent(docId, () => TextEditingController());
  }

  @override
  Widget build(BuildContext context) {
    if (_username == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<QuerySnapshot>(
      // Only fetch messages for the current user, ordered by time
      stream: FirebaseFirestore.instance
          .collection('messages')
          .where('userId', isEqualTo: _username)
          .orderBy('timestamp', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent)),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Text(
              'No messages yet.',
              style: TextStyle(color: Colors.grey[400]),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final doc = docs[i];
            final data = doc.data() as Map<String, dynamic>;
            final adminMsg = data['adminMessage'] as String? ?? '';
            final reply = data['reply'] as String?;
            final ts = (data['timestamp'] as Timestamp?)?.toDate();
            final timeStr = ts != null
                ? '${ts.day}/${ts.month}/${ts.year} ${ts.hour}:${ts.minute.toString().padLeft(2, '0')}'
                : '';

            final ctrl = _controllerFor(doc.id);

            return _MessageBubble(
              adminMessage: adminMsg,
              reply: reply,
              timeStr: timeStr,
              replyController: ctrl,
              onSend: () async {
                await _sendReply(doc.id, ctrl.text);
                ctrl.clear();
                FocusScope.of(context).unfocus();
              },
            );
          },
        );
      },
    );
  }
}

// ── Single message bubble ────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final String adminMessage;
  final String? reply;
  final String timeStr;
  final TextEditingController replyController;
  final VoidCallback onSend;

  const _MessageBubble({
    required this.adminMessage,
    required this.reply,
    required this.timeStr,
    required this.replyController,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey[850],
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Admin message ─────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.blueGrey[700],
                  child: const Icon(Icons.support_agent,
                      size: 16, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Admin',
                          style: TextStyle(
                              color: Colors.blueGrey[300],
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                      const SizedBox(height: 4),
                      // SelectableText makes message copyable
                      SelectableText(
                        adminMessage,
                        style: const TextStyle(color: Colors.white),
                      ),
                      if (timeStr.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(timeStr,
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 10)),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            // ── Existing reply (if any) ───────────────────────────
            if (reply != null && reply!.isNotEmpty) ...[
              const Divider(color: Colors.grey, height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.green[800],
                    child: const Icon(Icons.person, size: 16, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('You',
                            style: TextStyle(
                                color: Colors.green[300],
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                        const SizedBox(height: 4),
                        SelectableText(reply!,
                            style: const TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ],
              ),
            ],

            // ── Reply input ───────────────────────────────────────
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: replyController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: reply != null ? 'Update reply…' : 'Write a reply…',
                      hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                      filled: true,
                      fillColor: Colors.grey[800],
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onSend,
                  icon: const Icon(Icons.send, color: Colors.blueGrey),
                  tooltip: 'Send reply',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
