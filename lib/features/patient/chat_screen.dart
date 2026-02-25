import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../app/app_theme.dart';
import 'call_screen.dart';
import 'video_call_screen.dart';

// ── Figma palette ───────────────────────────────────────────────────
const _kTeal = Color(0xFF64ADB3);
const _kDarkBlue = Color(0xFF3D6A99);

/// Chat screen between patient and doctor — matches Figma design.
class ChatScreen extends StatefulWidget {
  final String doctorName;

  const ChatScreen({super.key, this.doctorName = 'Dr. Abdullah'});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  // Start with empty chat
  final List<_Message> _messages = [];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_Message(text: text, isMe: true));
      _controller.clear();
    });
    _scrollToBottom();

    // Simulated doctor reply for frontend demo
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() {
        _messages
            .add(_Message(text: _autoReply(), isMe: false));
      });
      _scrollToBottom();
    });
  }

  /// Opens a bottom sheet to pick image from gallery or camera, or a file
  void _showAttachmentPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDDDDD),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Send Attachment',
                style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _attachOption(
                    icon: Icons.photo_library_outlined,
                    label: 'Gallery',
                    onTap: () async {
                      Navigator.pop(context);
                      final picked = await ImagePicker()
                          .pickImage(source: ImageSource.gallery);
                      if (picked != null && mounted) {
                        setState(() {
                          _messages.add(_Message(
                            text: '📷 Photo attached',
                            isMe: true,
                          ));
                        });
                        _scrollToBottom();
                      }
                    },
                  ),
                  _attachOption(
                    icon: Icons.camera_alt_outlined,
                    label: 'Camera',
                    onTap: () async {
                      Navigator.pop(context);
                      final picked = await ImagePicker()
                          .pickImage(source: ImageSource.camera);
                      if (picked != null && mounted) {
                        setState(() {
                          _messages.add(_Message(
                            text: '📷 Photo attached',
                            isMe: true,
                          ));
                        });
                        _scrollToBottom();
                      }
                    },
                  ),
                  _attachOption(
                    icon: Icons.insert_drive_file_outlined,
                    label: 'Document',
                    onTap: () {
                      Navigator.pop(context);
                      // TODO: file picker
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _attachOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: _kTeal.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 26, color: _kTeal),
          ),
          const SizedBox(height: 8),
          Text(label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF666666)),
          ),
        ],
      ),
    );
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  int _replyIndex = 0;

  String _autoReply() {
    const replies = [
      'Thank you for reaching out. How can I help you today?',
      'Could you describe your symptoms in more detail?',
      'I understand. Let me review your information.',
      'Based on what you\'ve told me, I recommend we schedule a follow-up.',
      'Please make sure to stay hydrated and get enough rest.',
      'Do you have any other questions?',
      'I\'ll send you a prescription shortly.',
      'Feel free to message me anytime if you need help.',
    ];
    final reply = replies[_replyIndex % replies.length];
    _replyIndex++;
    return reply;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            const Divider(height: 1, color: Color(0xFFE8E8E8)),
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded,
                              size: 48,
                              color: _kTeal.withValues(alpha: 0.3)),
                          const SizedBox(height: 12),
                          Text(
                            'No messages yet',
                            style: TextStyle(
                              fontSize: 15,
                              color: const Color(0xFF9CA3AF),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Start the conversation',
                            style: TextStyle(
                              fontSize: 13,
                              color: const Color(0xFFBFC5CC),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) => _buildBubble(_messages[i]),
                    ),
            ),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  // ── App bar ───────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  size: 20, color: Color(0xFF1A1A1A)),
            ),
          ),
          const SizedBox(width: 10),
          // Doctor avatar
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFA3FBFF), Color(0xFF629699)],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF3D6A99), Color(0xFF2F4A5F)],
                  ),
                ),
                child: const Icon(Icons.person, size: 22, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.doctorName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      VideoCallScreen(doctorName: widget.doctorName),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(Icons.videocam_outlined,
                  size: 24, color: _kDarkBlue),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CallScreen(doctorName: widget.doctorName),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(Icons.phone_outlined, size: 22, color: _kDarkBlue),
            ),
          ),
        ],
      ),
    );
  }

  // ── Chat bubble ───────────────────────────────────────────────────

  Widget _buildBubble(_Message msg) {
    final isMe = msg.isMe;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isMe ? _kTeal : const Color(0xFFF2F2F2),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMe ? 16 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 16),
            ),
          ),
          child: Text(
            msg.text,
            style: TextStyle(
              fontSize: 14,
              color: isMe ? Colors.white : const Color(0xFF1A1A1A),
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }

  // ── Input bar ─────────────────────────────────────────────────────

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        10, 8, 10, MediaQuery.of(context).padding.bottom + 8,
      ),
      color: Colors.white,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Text field
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                color: const Color(0xFFF2F3F5),
              ),
              child: TextField(
                controller: _controller,
                onSubmitted: (_) => _send(),
                maxLines: 4,
                minLines: 1,
                style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A1A)),
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(
                    fontSize: 15,
                    color: Color(0xFFB0B0B0),
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16, vertical: 11,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Send button
          GestureDetector(
            onTap: _send,
            child: Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: _kTeal,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, size: 20, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _Message {
  final String text;
  final bool isMe;
  _Message({required this.text, required this.isMe});
}
