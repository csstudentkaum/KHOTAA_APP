import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/firebase/consultation_chat_service.dart';

// App ID and temporary test token are read from .env
String get kAgoraAppId => dotenv.env['AGORA_APP_ID'] ?? '';
String get kAgoraToken => dotenv.env['AGORA_TOKEN'] ?? '';
String get kAgoraTestChannel => dotenv.env['AGORA_TEST_CHANNEL'] ?? '';

/// Full-screen Zoom-like video consultation screen.
///
/// [channelId]       – Agora channel name
/// [otherPersonName] – Display name shown in the waiting / active state
///
/// For testing: set AGORA_TOKEN and AGORA_TEST_CHANNEL in your .env file.
/// For production: upgrade to a token server (Vercel endpoint).
class AgoraVideoCallScreen extends StatefulWidget {
  final String channelId;
  final String otherPersonName;
  final String consultationId;

  const AgoraVideoCallScreen({
    super.key,
    required this.channelId,
    required this.otherPersonName,
    required this.consultationId,
  });

  @override
  State<AgoraVideoCallScreen> createState() => _AgoraVideoCallScreenState();
}

class _AgoraVideoCallScreenState extends State<AgoraVideoCallScreen>
    with TickerProviderStateMixin {
  // ── Agora ──
  RtcEngine? _engine;
  bool _engineReady = false;
  bool _engineInitialized = false;
  bool _localJoined = false; // true once onJoinChannelSuccess fires
  int? _remoteUid;
  bool _remoteVideoEnabled = true;
  late String _activeChannel; // the channel we actually joined (test or real)

  // ── Local state ──
  bool _micMuted = false;
  bool _cameraOff = false;
  bool _speakerOn = true;
  bool _frontCamera = true;

  // ── UI state ──
  bool _controlsVisible = true;
  Timer? _hideTimer;

  // ── Call timer ──
  int _callSeconds = 0;
  Timer? _callTimer;

  // ── PiP position ──
  double _pipRight = 16;
  double _pipBottom = 120;

  // ── Waiting pulse animation ──
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    // Force landscape for video call
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _initAgora();
    _scheduleHideControls();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _callTimer?.cancel();
    _pulseCtrl.dispose();
    if (_engineInitialized && _engine != null) {
      _engine!.leaveChannel();
      _engine!.release();
    }
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  // ── Agora initialisation ─────────────────────────────────────────────────

  Future<void> _initAgora() async {
    // Request permissions
    await [Permission.camera, Permission.microphone].request();

    final appId = kAgoraAppId;
    if (appId.isEmpty) {
      debugPrint('[Agora] AGORA_APP_ID is not set in .env');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Agora App ID not configured. Check your .env file.')),
        );
        Navigator.of(context).pop();
      }
      return;
    }

    _engine = createAgoraRtcEngine();
    try {
      await _engine!.initialize(RtcEngineContext(appId: appId));
    } catch (e) {
      debugPrint('[Agora] initialize failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Video call failed to start: $e')),
        );
        Navigator.of(context).pop();
      }
      return;
    }
    _engineInitialized = true;

    _engine!.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (connection, elapsed) {
        debugPrint('[Agora] joined channel: ${connection.channelId} (uid: ${connection.localUid})');
        if (mounted) setState(() => _localJoined = true);
      },
      onUserJoined: (connection, remoteUid, elapsed) {
        debugPrint('[Agora] remote user joined: $remoteUid');
        if (mounted) {
          setState(() => _remoteUid = remoteUid);
          _startCallTimer();
        }
      },
      onUserOffline: (connection, remoteUid, reason) {
        debugPrint('[Agora] remote user offline: $remoteUid, reason: $reason');
        if (mounted) {
          setState(() => _remoteUid = null);
          _callTimer?.cancel();
          // The other party left — end the call for this side too
          if (reason == UserOfflineReasonType.userOfflineQuit ||
              reason == UserOfflineReasonType.userOfflineDropped) {
            _onRemoteEnded();
          }
        }
      },
      onRemoteVideoStateChanged: (connection, remoteUid, state, reason, elapsed) {
        debugPrint('[Agora] remote video state: $state, reason: $reason');
        // Only mark camera off if explicitly disabled by the user (not emulator quirks)
        if (state == RemoteVideoState.remoteVideoStateDecoding ||
            state == RemoteVideoState.remoteVideoStateStarting) {
          if (mounted) setState(() => _remoteVideoEnabled = true);
        } else if (reason == RemoteVideoStateReason.remoteVideoStateReasonRemoteMuted) {
          if (mounted) setState(() => _remoteVideoEnabled = false);
        }
      },
      onConnectionStateChanged: (connection, state, reason) {
        debugPrint('[Agora] connection state: $state, reason: $reason');
      },
      onTokenPrivilegeWillExpire: (connection, token) {
        debugPrint('[Agora] token will expire soon!');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Token expiring soon — rejoin may be needed')),
          );
        }
      },
      onError: (err, msg) {
        debugPrint('[Agora] error $err: $msg');
        // Token expired or invalid
        if (mounted && (err == ErrorCodeType.errTokenExpired || err == ErrorCodeType.errInvalidToken)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Agora token expired — generate a new one in the console')),
          );
        }
      },
    ));

    await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await _engine!.enableVideo();
    await _engine!.setVideoEncoderConfiguration(
      const VideoEncoderConfiguration(
        dimensions: VideoDimensions(width: 1280, height: 720),
        frameRate: 30,
        bitrate: 0, // auto
      ),
    );
    await _engine!.startPreview();

    if (mounted) setState(() => _engineReady = true);

    // Use the temp token from .env; channel name is overridden to match
    _activeChannel = kAgoraTestChannel.isNotEmpty ? kAgoraTestChannel : widget.channelId;
    final token = kAgoraToken;

    await _engine!.joinChannel(
      token: token,
      channelId: _activeChannel,
      uid: 0,
      options: const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileCommunication,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishCameraTrack: true,
        publishMicrophoneTrack: true,
        autoSubscribeAudio: true,
        autoSubscribeVideo: true,
      ),
    );

    await _engine!.setEnableSpeakerphone(true);

    debugPrint('[Agora] joined channel=$_activeChannel, token=${token.isNotEmpty ? "present (${token.length} chars)" : "EMPTY"}');
  }

  // ── Timer ────────────────────────────────────────────────────────────────

  void _startCallTimer() {
    _callTimer?.cancel();
    setState(() => _callSeconds = 0);
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _callSeconds++);
    });
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = (seconds % 60).toString().padLeft(2, '0');
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$s';
    return '$m:$s';
  }

  // ── Controls visibility ──────────────────────────────────────────────────

  void _scheduleHideControls() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _onTapScreen() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _scheduleHideControls();
  }

  // ── Controls actions ─────────────────────────────────────────────────────

  Future<void> _toggleMic() async {
    setState(() => _micMuted = !_micMuted);
    await _engine!.muteLocalAudioStream(_micMuted);
  }

  Future<void> _toggleCamera() async {
    setState(() => _cameraOff = !_cameraOff);
    await _engine!.muteLocalVideoStream(_cameraOff);
  }

  Future<void> _flipCamera() async {
    setState(() => _frontCamera = !_frontCamera);
    await _engine!.switchCamera();
  }

  Future<void> _toggleSpeaker() async {
    setState(() => _speakerOn = !_speakerOn);
    await _engine!.setEnableSpeakerphone(_speakerOn);
  }

  Future<void> _endCall({bool postMessage = true}) async {
    if (_engineInitialized && _engine != null) await _engine!.leaveChannel();
    // Post "call ended" message only when this user actively ended the call
    if (postMessage && _callSeconds > 0) {
      final duration = _formatDuration(_callSeconds);
      await ConsultationChatService().sendSystemMessage(
        widget.consultationId,
        'Video call ended — $duration',
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  /// Called when the remote user leaves — show a brief overlay then auto-close.
  void _onRemoteEnded() {
    if (!mounted) return;
    // Show "Call ended" snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('The other party ended the call'),
        duration: Duration(seconds: 2),
      ),
    );
    // Auto-leave after a short delay so the user sees the message
    // postMessage: false — the other side already posted the ended message
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _endCall(postMessage: false);
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: _onTapScreen,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Remote video (full screen) ──
              _RemoteVideoLayer(
                engine: _engine,
                engineReady: _engineReady,
                localJoined: _localJoined,
                remoteUid: _remoteUid,
                remoteVideoEnabled: _remoteVideoEnabled,
                otherPersonName: widget.otherPersonName,
                pulseAnim: _pulseAnim,
                channelId: _engineReady ? _activeChannel : widget.channelId,
              ),

              // ── Local PiP (draggable) ──
              if (_engineReady && !_cameraOff && _engine != null)
                _DraggablePip(
                  engine: _engine!,
                  right: _pipRight,
                  bottom: _pipBottom,
                  onDragEnd: (r, b) => setState(() {
                    _pipRight = r;
                    _pipBottom = b;
                  }),
                ),

              // ── Camera off indicator on PiP slot ──
              if (_engineReady && _cameraOff)
                Positioned(
                  right: _pipRight,
                  bottom: _pipBottom,
                  child: Container(
                    width: 110,
                    height: 150,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.videocam_off_rounded,
                            color: Colors.white54, size: 28),
                        SizedBox(height: 6),
                        Text('Camera off',
                            style: TextStyle(
                                color: Colors.white54,
                                fontSize: 10,
                                fontFamily: 'Poppins')),
                      ],
                    ),
                  ),
                ),

              // ── Top bar ── Positioned here so AnimatedOpacity doesn’t break it
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  opacity: _controlsVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: _TopBar(
                    otherPersonName: widget.otherPersonName,
                    callSeconds: _callSeconds,
                    isConnected: _remoteUid != null,
                    formatDuration: _formatDuration,
                    onEndCall: _endCall,
                  ),
                ),
              ),

              // ── Bottom controls ── Positioned here so AnimatedOpacity doesn’t break it
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  opacity: _controlsVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: _BottomControls(
                    micMuted: _micMuted,
                    cameraOff: _cameraOff,
                    speakerOn: _speakerOn,
                    onToggleMic: _toggleMic,
                    onToggleCamera: _toggleCamera,
                    onFlipCamera: _flipCamera,
                    onToggleSpeaker: _toggleSpeaker,
                    onEndCall: _endCall,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Token loading / error overlay

// ────────────────────────────────────────────────────────────────────────────
// Remote video layer

class _RemoteVideoLayer extends StatelessWidget {
  final RtcEngine? engine;
  final bool engineReady;
  final bool localJoined;
  final int? remoteUid;
  final bool remoteVideoEnabled;
  final String otherPersonName;
  final Animation<double> pulseAnim;
  final String channelId;

  const _RemoteVideoLayer({
    required this.engine,
    required this.engineReady,
    required this.localJoined,
    required this.remoteUid,
    required this.remoteVideoEnabled,
    required this.otherPersonName,
    required this.pulseAnim,
    required this.channelId,
  });

  @override
  Widget build(BuildContext context) {
    debugPrint('[Agora UI] localJoined=$localJoined remoteUid=$remoteUid engine=${engine != null} channelId=$channelId');
    // Remote joined → show video view
    if (remoteUid != null && engine != null) {
      debugPrint('[Agora UI] >>> SHOWING REMOTE VIDEO for uid=$remoteUid on channel=$channelId');
      return Stack(
        fit: StackFit.expand,
        children: [
          AgoraVideoView(
            controller: VideoViewController.remote(
              rtcEngine: engine!,
              canvas: VideoCanvas(uid: remoteUid!),
              connection: RtcConnection(channelId: channelId),
            ),
          ),
          // Connected banner so user knows video is active
          Positioned(
            top: 60,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF34C759).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Connected with $otherPersonName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // We joined the channel — waiting for the other person
    if (localJoined) {
      return _WaitingBackground(
        otherPersonName: otherPersonName,
        pulseAnim: pulseAnim,
        statusText: 'Waiting for ${otherPersonName.split(' ').first} to join…',
        showPulse: true,
      );
    }

    // Still connecting to Agora channel — show simple joining UI (no other person info)
    return _JoiningOverlay();
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Joining overlay — shown while YOU are still connecting (no other person info)

class _JoiningOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1B2B3A), Color(0xFF0D1B2A)],
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Color(0xFF2A9D8F),
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Joining call…',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
                fontFamily: 'Poppins',
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Setting up your connection',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 13,
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
// Waiting background — shown before remote joins

class _WaitingBackground extends StatelessWidget {
  final String otherPersonName;
  final Animation<double> pulseAnim;
  final String statusText;
  final bool showPulse;

  const _WaitingBackground({
    required this.otherPersonName,
    required this.pulseAnim,
    required this.statusText,
    this.showPulse = true,
  });

  @override
  Widget build(BuildContext context) {
    final initial =
        otherPersonName.isNotEmpty ? otherPersonName[0].toUpperCase() : '?';
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1B2B3A), Color(0xFF0D1B2A)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pulsing rings
            if (showPulse)
              ScaleTransition(
                scale: pulseAnim,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF2E7D9C).withValues(alpha: 0.2),
                  ),
                  child: Center(
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF2E7D9C).withValues(alpha: 0.35),
                      ),
                      child: Center(
                        child: CircleAvatar(
                          radius: 36,
                          backgroundColor: const Color(0xFF1E8C7E),
                          child: Text(
                            initial,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else
              CircleAvatar(
                radius: 44,
                backgroundColor: const Color(0xFF1E8C7E),
                child: Text(
                  otherPersonName.isNotEmpty
                      ? otherPersonName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            const SizedBox(height: 28),
            Text(
              otherPersonName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              statusText,
              style: const TextStyle(
                color: Colors.white60,
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
// Draggable PiP local camera preview

class _DraggablePip extends StatelessWidget {
  final RtcEngine engine;
  final double right;
  final double bottom;
  final void Function(double right, double bottom) onDragEnd;

  const _DraggablePip({
    required this.engine,
    required this.right,
    required this.bottom,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    const pipW = 110.0;
    const pipH = 150.0;

    return Positioned(
      right: right,
      bottom: bottom,
      child: GestureDetector(
        onPanUpdate: (details) {
          final newRight =
              (right - details.delta.dx).clamp(8.0, screenW - pipW - 8);
          final newBottom =
              (bottom - details.delta.dy).clamp(8.0, screenH - pipH - 8);
          onDragEnd(newRight, newBottom);
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: pipW,
            height: pipH,
            child: AgoraVideoView(
              controller: VideoViewController(
                rtcEngine: engine,
                canvas: const VideoCanvas(uid: 0),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Top bar

class _TopBar extends StatelessWidget {
  final String otherPersonName;
  final int callSeconds;
  final bool isConnected;
  final String Function(int) formatDuration;
  final VoidCallback onEndCall;

  const _TopBar({
    required this.otherPersonName,
    required this.callSeconds,
    required this.isConnected,
    required this.formatDuration,
    required this.onEndCall,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 16,
      ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.65),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          children: [
            // Back / minimise
            _ControlIcon(
              icon: Icons.arrow_back_ios_rounded,
              onTap: onEndCall,
              size: 18,
              padding: const EdgeInsets.all(8),
            ),
            const SizedBox(width: 12),
            // Name + timer
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    otherPersonName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      fontFamily: 'Poppins',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (isConnected) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFF34C759),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          formatDuration(callSeconds),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  ] else
                    const Text(
                      'Connecting…',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        fontFamily: 'Poppins',
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Bottom controls bar — Zoom-style dark pill

class _BottomControls extends StatelessWidget {
  final bool micMuted;
  final bool cameraOff;
  final bool speakerOn;
  final VoidCallback onToggleMic;
  final VoidCallback onToggleCamera;
  final VoidCallback onFlipCamera;
  final VoidCallback onToggleSpeaker;
  final VoidCallback onEndCall;

  const _BottomControls({
    required this.micMuted,
    required this.cameraOff,
    required this.speakerOn,
    required this.onToggleMic,
    required this.onToggleCamera,
    required this.onFlipCamera,
    required this.onToggleSpeaker,
    required this.onEndCall,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 24,
        top: 20,
        left: 20,
        right: 20,
      ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withValues(alpha: 0.75),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Mic
            _ControlButton(
              icon: micMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
              label: micMuted ? 'Unmute' : 'Mute',
              active: !micMuted,
              onTap: onToggleMic,
            ),
            // Camera
            _ControlButton(
              icon: cameraOff
                  ? Icons.videocam_off_rounded
                  : Icons.videocam_rounded,
              label: cameraOff ? 'Start video' : 'Stop video',
              active: !cameraOff,
              onTap: onToggleCamera,
            ),
            // Flip camera
            _ControlButton(
              icon: Icons.flip_camera_ios_rounded,
              label: 'Flip',
              active: true,
              onTap: onFlipCamera,
            ),
            // Speaker
            _ControlButton(
              icon: speakerOn
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
              label: speakerOn ? 'Speaker' : 'Earpiece',
              active: speakerOn,
              onTap: onToggleSpeaker,
            ),
            // End call
            _EndCallButton(onTap: onEndCall),
          ],
        ),
      );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Individual control button (mic, camera, flip, speaker)

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: active
                  ? Colors.white.withValues(alpha: 0.18)
                  : const Color(0xFF636366),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }
}

// Red end-call button
class _EndCallButton extends StatelessWidget {
  final VoidCallback onTap;
  const _EndCallButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              color: Color(0xFFFF3B30),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.call_end_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(height: 6),
          const Text(
            'End',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Small generic icon button used in top bar

class _ControlIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final EdgeInsets padding;

  const _ControlIcon({
    required this.icon,
    required this.onTap,
    this.size = 22,
    this.padding = const EdgeInsets.all(10),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: size),
      ),
    );
  }
}
