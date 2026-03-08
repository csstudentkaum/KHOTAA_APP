import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import '../../app/app_theme.dart';
import '../../models/chat_message.dart';
import '../../models/consultation.dart';
import '../../services/firebase/consultation_chat_service.dart';

/// Shared consultation session screen used by both patient and doctor.
/// Pass [isDoctor] = true when launched from the doctor shell.
class ConsultationSessionScreen extends StatefulWidget {
  final String consultationId;
  final bool isDoctor;

  const ConsultationSessionScreen({
    super.key,
    required this.consultationId,
    this.isDoctor = false,
  });

  @override
  State<ConsultationSessionScreen> createState() =>
      _ConsultationSessionScreenState();
}

class _ConsultationSessionScreenState
    extends State<ConsultationSessionScreen> {
  final _service = ConsultationChatService();
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  final _imagePicker = ImagePicker();

  String? _currentUserId;
  bool _isRecording = false;
  bool _isSending = false;
  String? _playingMessageId;
  int _playingElapsedSeconds = 0;
  String? _recordingPath;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;
  StreamSubscription<List<ChatMessage>>? _messagesSubscription;
  StreamSubscription<Duration>? _positionSubscription;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    // Listen to messages outside the build tree so _markRead fires
    // reliably whenever the other party sends a message — even when
    // the app is foregrounded on the receiver's device.
    _messagesSubscription =
        _service.streamMessages(widget.consultationId).listen((_) {
      if (mounted && _currentUserId != null) _markRead();
    });
    _positionSubscription = _player.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _playingElapsedSeconds = pos.inSeconds);
    });
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _positionSubscription?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    _recorder.dispose();
    _player.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  Future<void> _markRead() async {
    if (_currentUserId == null) return;
    await _service.markMessagesAsRead(widget.consultationId, _currentUserId!);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Send actions ──

  Future<void> _sendText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    setState(() => _isSending = true);
    try {
      await _service.sendText(widget.consultationId, text);
      _scrollToBottom();
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _pickImage() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null) return;
    setState(() => _isSending = true);
    try {
      await _service.sendImage(widget.consultationId, File(picked.path));
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image upload failed: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final pf = result.files.first;
    if (pf.path == null) return;
    setState(() => _isSending = true);
    try {
      await _service.sendFile(
        widget.consultationId,
        File(pf.path!),
        pf.name,
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File upload failed: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      _recordingTimer?.cancel();
      // Save path before stopping so we never lose it if stop() returns null
      final savedPath = _recordingPath;
      final savedSeconds = _recordingSeconds;
      await _recorder.stop();
      setState(() {
        _isRecording = false;
        _recordingSeconds = 0;
        _recordingPath = null;
      });
      if (savedPath == null) return;
      final file = File(savedPath);
      if (!file.existsSync()) return;
      setState(() => _isSending = true);
      try {
        // Use the timer seconds — more reliable than estimating from file size
        final duration = savedSeconds.clamp(1, 600);
        await _service.sendVoice(widget.consultationId, file, duration);
        _scrollToBottom();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Voice upload failed: $e'), backgroundColor: AppColors.error),
          );
        }
      } finally {
        setState(() => _isSending = false);
      }
    } else {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Microphone permission is required.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }
      final dir = await getTemporaryDirectory();
      _recordingPath =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: _recordingPath!,
      );
      setState(() {
        _isRecording = true;
        _recordingSeconds = 0;
      });
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _recordingSeconds++);
      });
    }
  }

  Future<void> _initiateVideoCall(Consultation consultation) async {
    final me = FirebaseAuth.instance.currentUser;
    final myName = me?.displayName ??
        (widget.isDoctor ? 'Doctor' : 'Patient');
    await _service.postVideoCallMessage(widget.consultationId, myName);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Video call feature coming soon.'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  void _showEndSessionDialog(Consultation consultation) {
    showDialog(
      context: context,
      builder: (_) => _EndSessionDialog(
        consultationId: widget.consultationId,
        service: _service,
      ),
    );
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Consultation?>(
      stream: _service.streamConsultation(widget.consultationId),
      builder: (context, consultSnap) {
        final consultation = consultSnap.data;
        final isReadOnly =
            consultation != null && consultation.isCompleted;

        return Scaffold(
          backgroundColor: const Color(0xFFEDF3F2),
          appBar: _buildAppBar(consultation, isReadOnly),
          body: Column(
            children: [
              // ── Fixed "Start Video" banner at top of chat ──
              if (consultation != null &&
                  consultation.canJoin &&
                  !isReadOnly)
                GestureDetector(
                  onTap: () => _initiateVideoCall(consultation),
                  child: Container(
                    color: const Color(0xFF1E8C7E),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Icon(Icons.videocam_rounded,
                              color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Video consultation is ready',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              Text(
                                'Tap to join the video call',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Text(
                            'Join',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: StreamBuilder<List<ChatMessage>>(
                  stream: _service.streamMessages(widget.consultationId),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      );
                    }
                    final messages = snap.data ?? [];
                    if (messages.isEmpty) {
                      return _EmptyChat(isDoctor: widget.isDoctor);
                    }
                    WidgetsBinding.instance
                        .addPostFrameCallback((_) => _scrollToBottom());
                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 12),
                      itemCount: messages.length,
                      itemBuilder: (context, i) {
                        final msg = messages[i];
                        final isMe = msg.senderID == _currentUserId;
                        return _MessageBubble(
                          message: msg,
                          isMe: isMe,
                          playingMessageId: _playingMessageId,
                          playingElapsedSeconds: _playingElapsedSeconds,
                          getSignedUrl: (url) => _service.getFileUrl(url),
                          onPlayVoice: (msgId, pathname) async {
                            if (_playingMessageId == msgId) {
                              await _player.stop();
                              setState(() {
                                _playingMessageId = null;
                                _playingElapsedSeconds = 0;
                              });
                            } else {
                              setState(() {
                                _playingMessageId = msgId;
                                _playingElapsedSeconds = 0;
                              });
                              try {
                                final signedUrl = await _service.getFileUrl(pathname);
                                await _player.play(UrlSource(signedUrl));
                              } catch (e) {
                                setState(() {
                                  _playingMessageId = null;
                                  _playingElapsedSeconds = 0;
                                });
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Could not play audio: $e'),
                                      backgroundColor: AppColors.error,
                                    ),
                                  );
                                }
                                return;
                              }
                              _player.onPlayerComplete.listen((_) {
                                if (mounted) {
                                  setState(() {
                                    _playingMessageId = null;
                                    _playingElapsedSeconds = 0;
                                  });
                                }
                              });
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              if (!isReadOnly)
                _InputBar(
                  controller: _textController,
                  isRecording: _isRecording,
                  isSending: _isSending,
                  recordingSeconds: _recordingSeconds,
                  onSendText: _sendText,
                  onPickImage: _pickImage,
                  onPickFile: _pickFile,
                  onToggleRecording: _toggleRecording,
                ),
              if (isReadOnly)
                const _ReadOnlyBanner(),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(
      Consultation? consultation, bool isReadOnly) {
    final otherName = widget.isDoctor
        ? (consultation?.patientName ?? 'Patient')
        : (consultation?.doctorName ?? 'Doctor');
    final initial = otherName.isNotEmpty ? otherName[0].toUpperCase() : '?';
    final isActive = consultation?.status == ConsultationStatus.active;

    return AppBar(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0.5,
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white.withValues(alpha: 0.25),
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                fontFamily: 'Poppins',
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  otherName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontFamily: 'Poppins',
                  ),
                ),
                Text(
                  isActive
                      ? 'Online'
                      : _statusLabel(consultation?.status),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white70,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // ── End Session (doctor only) — clean outlined style ──
        if (widget.isDoctor && !isReadOnly)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: OutlinedButton(
              onPressed: consultation != null
                  ? () => _showEndSessionDialog(consultation)
                  : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54, width: 1.2),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text(
                'End Session',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _statusLabel(ConsultationStatus? status) {
    switch (status) {
      case ConsultationStatus.pending:
        return 'Pending confirmation';
      case ConsultationStatus.accepted:
        return 'Accepted';
      case ConsultationStatus.active:
        return 'Online';
      case ConsultationStatus.followUp:
        return 'Follow-up';
      case ConsultationStatus.completed:
        return 'Session ended';
      case ConsultationStatus.rejected:
        return 'Rejected';
      case null:
        return '';
    }
  }
}

// ────────────────────────────────────────────────────────────────────────────

class _EmptyChat extends StatelessWidget {
  final bool isDoctor;

  const _EmptyChat({required this.isDoctor});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline_rounded,
                size: 56, color: AppColors.primary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(
              isDoctor
                  ? 'No messages yet.\nThe patient can start the conversation.'
                  : 'No messages yet.\nSend a message to start the session.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────

class _ReadOnlyBanner extends StatelessWidget {
  const _ReadOnlyBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: AppColors.divider,
      child: const Text(
        'Session completed — chat is read-only',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isRecording;
  final bool isSending;
  final int recordingSeconds;
  final VoidCallback onSendText;
  final VoidCallback onPickImage;
  final VoidCallback onPickFile;
  final VoidCallback onToggleRecording;

  const _InputBar({
    required this.controller,
    required this.isRecording,
    required this.isSending,
    required this.recordingSeconds,
    required this.onSendText,
    required this.onPickImage,
    required this.onPickFile,
    required this.onToggleRecording,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEDF3F2),
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // ── Input pill ──────────────────────────────────────────
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 130),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Attach button (left)
                  IconButton(
                    onPressed:
                        isSending ? null : () => _showAttachMenu(context),
                    icon: const Icon(Icons.attach_file_rounded),
                    color: AppColors.textSecondary,
                    iconSize: 22,
                    padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                    constraints: const BoxConstraints(),
                  ),
                  // Text field OR recording indicator (centre)
                  Expanded(
                    child: isRecording
                        ? Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 6),
                            child: Row(
                              children: [
                                const Icon(Icons.mic_rounded,
                                    color: AppColors.error, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  _formatRecording(recordingSeconds),
                                  style: const TextStyle(
                                    color: AppColors.error,
                                    fontSize: 13,
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Expanded(
                                  child: Text(
                                    'Slide to cancel',
                                    style: TextStyle(
                                      color: AppColors.textHint,
                                      fontSize: 12,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : TextField(
                            controller: controller,
                            maxLines: null,
                            textCapitalization: TextCapitalization.none,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Message',
                              hintStyle: TextStyle(
                                color: AppColors.textHint,
                                fontSize: 14,
                                fontFamily: 'Poppins',
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 10),
                            ),
                            onSubmitted: (_) => onSendText(),
                          ),
                  ),
                  // Mic icon inside pill (right) — only when not typing
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder: (context, value, child) {
                      final hasText = value.text.trim().isNotEmpty;
                      if (hasText) return const SizedBox.shrink();
                      return GestureDetector(
                        onTap: isSending ? null : onToggleRecording,
                        child: Padding(
                          padding:
                              const EdgeInsets.fromLTRB(4, 10, 12, 10),
                          child: Icon(
                            isRecording
                                ? Icons.stop_circle_rounded
                                : Icons.mic_rounded,
                            color: isRecording
                                ? AppColors.error
                                : AppColors.textSecondary,
                            size: 22,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // ── Send button (outside pill) — only when typing or recording ──
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, child) {
              final hasText = value.text.trim().isNotEmpty;
              if (!hasText && !isRecording) return const SizedBox.shrink();
              return _CircleButton(
                icon: isRecording
                    ? Icons.send_rounded
                    : Icons.send_rounded,
                onPressed: isSending
                    ? null
                    : (isRecording ? onToggleRecording : onSendText),
                color: AppColors.primary,
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatRecording(int seconds) {
    final m = seconds ~/ 60;
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _showAttachMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE8F5E9),
                child: Icon(Icons.image_rounded, color: AppColors.success),
              ),
              title: const Text('Photo',
                  style: TextStyle(fontFamily: 'Poppins')),
              subtitle: const Text('Send a wound photo from gallery',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                onPickImage();
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE3F2FD),
                child: Icon(Icons.attach_file_rounded, color: Colors.blue),
              ),
              title: const Text('File',
                  style: TextStyle(fontFamily: 'Poppins')),
              subtitle: const Text('Send a document or file',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                onPickFile();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color color;

  const _CircleButton({
    required this.icon,
    required this.onPressed,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final String? playingMessageId;
  final int playingElapsedSeconds;
  final void Function(String msgId, String url) onPlayVoice;
  final Future<String> Function(String url) getSignedUrl;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.playingMessageId,
    required this.playingElapsedSeconds,
    required this.onPlayVoice,
    required this.getSignedUrl,
  });

  @override
  Widget build(BuildContext context) {
    // System messages — centered pill
    if (message.type == MessageType.system) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFE1F0EE),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              message.text ?? '',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar for received messages (left side)
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              child: Text(
                (message.senderName ?? '?')[0].toUpperCase(),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          // Bubble + meta row below
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Sender name above received bubble
                if (!isMe && message.senderName != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    child: Text(
                      message.senderName!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                // Bubble
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isMe ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isMe ? 16 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: _bubbleContent(context),
                  ),
                ),
                // Time + ticks BELOW the bubble
                Padding(
                  padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                  child: _timeAndTick(),
                ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 6),
        ],
      ),
    );
  }

  // Time + read ticks shown BELOW the bubble
  Widget _timeAndTick() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatTime(message.createdAt),
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textHint,
            fontFamily: 'Poppins',
          ),
        ),
        if (isMe) ...[
          const SizedBox(width: 3),
          Icon(
            message.isRead ? Icons.done_all_rounded : Icons.done_rounded,
            size: 14,
            color: message.isRead
                ? AppColors.success // green = read
                : AppColors.textHint, // grey = sent
          ),
        ],
      ],
    );
  }

  Widget _bubbleContent(BuildContext context) {
    switch (message.type) {
      case MessageType.text:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Text(
            message.text ?? '',
            style: TextStyle(
              fontSize: 14,
              color: isMe ? Colors.white : AppColors.textPrimary,
              height: 1.35,
            ),
          ),
        );

      case MessageType.image:
        return ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          child: FutureBuilder<String>(
            future: getSignedUrl(message.fileUrl ?? ''),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const SizedBox(
                  width: 220,
                  height: 180,
                  child: Center(
                    child: Icon(Icons.broken_image_rounded,
                        color: AppColors.textHint),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const SizedBox(
                  width: 220,
                  height: 180,
                  child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary, strokeWidth: 2),
                  ),
                );
              }
              return GestureDetector(
                onTap: () => _showFullScreenImage(context, snapshot.data!),
                child: Image.network(
                  snapshot.data!,
                  width: 220,
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return const SizedBox(
                      width: 220,
                      height: 180,
                      child: Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary, strokeWidth: 2),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        );

      case MessageType.file:
        return GestureDetector(
          onTap: message.fileUrl != null
              ? () async {
                  final url = message.fileUrl!;
                  final name = message.fileName ??
                      url.split('?').first.split('/').last;
                  // Check extension from fileName first, then URL
                  final ext = name.split('.').last.toLowerCase();
                  const imageExts = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'};
                  if (imageExts.contains(ext)) {
                    _showFullScreenImage(context, url);
                    return;
                  }
                  if (ext == 'pdf') {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            _PdfViewerScreen(url: url, fileName: name),
                      ),
                    );
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Only PDF files can be viewed in-app'),
                        backgroundColor: Colors.grey),
                  );
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.insert_drive_file_rounded,
                  size: 28,
                  color: isMe ? Colors.white70 : AppColors.primary,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    message.fileName ?? 'File',
                    style: TextStyle(
                      fontSize: 13,
                      color: isMe ? Colors.white : AppColors.textPrimary,
                      fontFamily: 'Poppins',
                      decoration: TextDecoration.underline,
                      decorationColor:
                          isMe ? Colors.white70 : AppColors.primary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );

      case MessageType.voice:
        final isPlaying = playingMessageId == message.messageID;
        final totalSec = message.voiceDuration ?? 0;
        // While playing show elapsed, otherwise show total duration
        final displaySec = isPlaying ? playingElapsedSeconds : totalSec;
        // Progress 0..1
        final progress = (totalSec > 0 && isPlaying)
            ? (playingElapsedSeconds / totalSec).clamp(0.0, 1.0)
            : 0.0;
        final bubbleColor = isMe ? AppColors.primary : Colors.white;
        final onBubble = isMe ? Colors.white : AppColors.primary;
        final onBubbleFaint = isMe ? Colors.white54 : AppColors.primary.withOpacity(0.35);
        return Container(
          constraints: const BoxConstraints(minWidth: 200, maxWidth: 260),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Play / Pause button
              GestureDetector(
                onTap: message.fileUrl != null
                    ? () => onPlayVoice(message.messageID, message.fileUrl!)
                    : null,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: onBubble,
                  ),
                  child: Icon(
                    isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: bubbleColor,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Waveform + progress + time
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Waveform bars with progress overlay
                    LayoutBuilder(
                      builder: (context, constraints) {
                        const barCount = 28;
                        const heights = [
                          0.4, 0.6, 0.8, 0.5, 1.0, 0.7, 0.4, 0.9,
                          0.6, 0.3, 0.8, 0.5, 0.7, 1.0, 0.4, 0.6,
                          0.9, 0.5, 0.3, 0.7, 1.0, 0.4, 0.6, 0.8,
                          0.5, 0.9, 0.4, 0.6,
                        ];
                        final totalW = constraints.maxWidth;
                        final barW = (totalW / barCount) * 0.55;
                        return SizedBox(
                          height: 28,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: List.generate(barCount, (i) {
                              final fraction = (i + 1) / barCount;
                              final played = fraction <= progress;
                              return Container(
                                width: barW,
                                height: 28 * heights[i],
                                decoration: BoxDecoration(
                                  color: played ? onBubble : onBubbleFaint,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              );
                            }),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    // Elapsed / total time
                    Text(
                      _formatDuration(displaySec),
                      style: TextStyle(
                        fontSize: 11,
                        color: isMe ? Colors.white70 : AppColors.textSecondary,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

      case MessageType.system:
        return const SizedBox.shrink();
    }
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _showFullScreenImage(BuildContext context, String url) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) => _FullScreenImage(url: url),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────

class _FullScreenImage extends StatelessWidget {
  final String url;
  const _FullScreenImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5.0,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────

class _PdfViewerScreen extends StatefulWidget {
  final String url;
  final String fileName;
  const _PdfViewerScreen({required this.url, required this.fileName});

  @override
  State<_PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<_PdfViewerScreen> {
  final List<Uint8List> _pages = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await http.get(Uri.parse(widget.url));
      if (response.statusCode != 200) {
        setState(() {
          _error = 'Server error ${response.statusCode}';
          _loading = false;
        });
        return;
      }
      final pages = <Uint8List>[];
      await for (final page in Printing.raster(response.bodyBytes, dpi: 150)) {
        pages.add(await page.toPng());
      }
      setState(() {
        _pages.addAll(pages);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName,
            style: const TextStyle(fontSize: 14),
            overflow: TextOverflow.ellipsis),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!_loading && _pages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text('${_pages.length} pages',
                    style: const TextStyle(color: Colors.white, fontSize: 13)),
              ),
            ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Text(_error!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center))
          : _loading
              ? const Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Loading PDF...'),
                ]))
              : ListView.builder(
                  itemCount: _pages.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Image.memory(_pages[i], fit: BoxFit.fitWidth),
                  ),
                ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────

class _EndSessionDialog extends StatefulWidget {
  final String consultationId;
  final ConsultationChatService service;

  const _EndSessionDialog({
    required this.consultationId,
    required this.service,
  });

  @override
  State<_EndSessionDialog> createState() => _EndSessionDialogState();
}

class _EndSessionDialogState extends State<_EndSessionDialog> {
  bool _isSaving = false;

  Future<void> _complete() async {
    setState(() => _isSaving = true);
    await widget.service.completeSession(widget.consultationId);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _followUp() async {
    setState(() => _isSaving = true);
    await widget.service.scheduleFollowUp(widget.consultationId);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
        child: _isSaving
            ? const SizedBox(
                height: 100,
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'End Session',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'How would you like to close this consultation?',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textHint,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 20),
                  _EndOptionTile(
                    icon: Icons.check_circle_rounded,
                    iconColor: AppColors.success,
                    title: 'Complete Session',
                    subtitle: 'Mark consultation as finished',
                    onTap: _complete,
                  ),
                  const SizedBox(height: 10),
                  _EndOptionTile(
                    icon: Icons.event_repeat_rounded,
                    iconColor: AppColors.primary,
                    title: 'Schedule Follow-up',
                    subtitle: 'Request a follow-up appointment',
                    onTap: _followUp,
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: AppColors.textHint,
                          fontFamily: 'Poppins',
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _EndOptionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _EndOptionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: iconColor.withValues(alpha: 0.22)),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 26),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                      color: iconColor,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textHint,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 13, color: iconColor.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}
