import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, image, file, voice, system }

class ChatMessage {
  final String messageID;
  final String senderID;
  final String? senderName;
  final MessageType type;
  final String? text;        // for text messages
  final String? fileUrl;     // for image/file/voice
  final String? fileName;    // original file name
  final int? voiceDuration;  // seconds, for voice messages
  final DateTime createdAt;
  final bool isRead;

  const ChatMessage({
    required this.messageID,
    required this.senderID,
    this.senderName,
    required this.type,
    this.text,
    this.fileUrl,
    this.fileName,
    this.voiceDuration,
    required this.createdAt,
    this.isRead = false,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map, {String? id}) {
    return ChatMessage(
      messageID: id ?? map['messageID'] as String? ?? '',
      senderID: map['senderID'] as String? ?? '',
      senderName: map['senderName'] as String?,
      type: _typeFromString(map['type'] as String? ?? 'text'),
      text: map['text'] as String?,
      fileUrl: map['fileUrl'] as String?,
      fileName: map['fileName'] as String?,
      voiceDuration: map['voiceDuration'] as int?,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      isRead: map['isRead'] as bool? ?? false,
    );
  }

  factory ChatMessage.fromDocument(DocumentSnapshot doc) =>
      ChatMessage.fromMap(doc.data() as Map<String, dynamic>, id: doc.id);

  Map<String, dynamic> toMap() => {
        'messageID': messageID,
        'senderID': senderID,
        'senderName': senderName,
        'type': _typeToString(type),
        'text': text,
        'fileUrl': fileUrl,
        'fileName': fileName,
        'voiceDuration': voiceDuration,
        'createdAt': Timestamp.fromDate(createdAt),
        'isRead': isRead,
      };

  static MessageType _typeFromString(String s) {
    switch (s) {
      case 'image': return MessageType.image;
      case 'file': return MessageType.file;
      case 'voice': return MessageType.voice;
      case 'system': return MessageType.system;
      default: return MessageType.text;
    }
  }

  static String _typeToString(MessageType t) {
    switch (t) {
      case MessageType.image: return 'image';
      case MessageType.file: return 'file';
      case MessageType.voice: return 'voice';
      case MessageType.system: return 'system';
      case MessageType.text: return 'text';
    }
  }

  // ── Factories ──

  factory ChatMessage.text({
    required String senderID,
    String? senderName,
    required String text,
  }) =>
      ChatMessage(
        messageID: '',
        senderID: senderID,
        senderName: senderName,
        type: MessageType.text,
        text: text,
        createdAt: DateTime.now(),
      );

  factory ChatMessage.image({
    required String senderID,
    String? senderName,
    required String fileUrl,
  }) =>
      ChatMessage(
        messageID: '',
        senderID: senderID,
        senderName: senderName,
        type: MessageType.image,
        fileUrl: fileUrl,
        createdAt: DateTime.now(),
      );

  factory ChatMessage.file({
    required String senderID,
    String? senderName,
    required String fileUrl,
    required String fileName,
  }) =>
      ChatMessage(
        messageID: '',
        senderID: senderID,
        senderName: senderName,
        type: MessageType.file,
        fileUrl: fileUrl,
        fileName: fileName,
        createdAt: DateTime.now(),
      );

  factory ChatMessage.voice({
    required String senderID,
    String? senderName,
    required String fileUrl,
    required int duration,
  }) =>
      ChatMessage(
        messageID: '',
        senderID: senderID,
        senderName: senderName,
        type: MessageType.voice,
        fileUrl: fileUrl,
        voiceDuration: duration,
        createdAt: DateTime.now(),
      );

  factory ChatMessage.system({required String text}) =>
      ChatMessage(
        messageID: '',
        senderID: 'system',
        type: MessageType.system,
        text: text,
        createdAt: DateTime.now(),
      );
}
