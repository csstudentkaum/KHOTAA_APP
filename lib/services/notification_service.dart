import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'local_notification_service.dart';

/// Service for managing in-app notifications stored in Firestore
/// and FCM push notification tokens.
class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _notificationsRef =>
      _firestore.collection('notifications');

  // ── FCM Token Management ──

  /// Save the current device's FCM token to the user document
  Future<void> saveFCMToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final messaging = FirebaseMessaging.instance;

      // Request permission (required on iOS)
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      final token = await messaging.getToken();
      if (token != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('✅ FCM token saved for ${user.uid}');
      }

      // Listen for token refresh
      messaging.onTokenRefresh.listen((newToken) async {
        await _firestore.collection('users').doc(user.uid).update({
          'fcmToken': newToken,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('🔄 FCM token refreshed for ${user.uid}');
      });
    } catch (e) {
      debugPrint('❌ Error saving FCM token: $e');
    }
  }

  // ── In-App Notification CRUD ──

  /// Create a notification for a specific user
  Future<void> createNotification({
    required String recipientID,
    required String title,
    required String body,
    required String
    type, // e.g. 'new_booking', 'booking_accepted', 'booking_rejected', 'booking_completed'
    Map<String, dynamic>? data,
  }) async {
    final docRef = _notificationsRef.doc();

    await docRef.set({
      'notificationID': docRef.id,
      'recipientID': recipientID,
      'title': title,
      'body': body,
      'type': type,
      'data': data ?? {},
      'isRead': false,
      'createdAt': Timestamp.now(),
    });

    debugPrint('🔔 Notification created for $recipientID: $title');

    // Play sound if notification is for the currently logged-in user
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && currentUser.uid == recipientID) {
      final isAlert =
          type == 'high_pressure' ||
          type == 'elevated_pressure' ||
          type == 'abnormal_temperature' ||
          type == 'elevated_temperature';
      LocalNotificationService().playSound(isAlert: isAlert);
    }
  }

  /// Stream notifications for the current user (most recent first)
  Stream<QuerySnapshot> streamNotifications(String userID) {
    return _notificationsRef
        .where('recipientID', isEqualTo: userID)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Stream unread count for badge
  Stream<int> streamUnreadCount(String userID) {
    return _notificationsRef
        .where('recipientID', isEqualTo: userID)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Mark a single notification as read
  Future<void> markAsRead(String notificationID) async {
    await _notificationsRef.doc(notificationID).update({'isRead': true});
  }

  /// Mark all notifications as read for a user
  Future<void> markAllAsRead(String userID) async {
    final snapshot = await _notificationsRef
        .where('recipientID', isEqualTo: userID)
        .where('isRead', isEqualTo: false)
        .get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  // ── Booking Notification Helpers ──

  /// Notify doctor when a patient books a consultation
  Future<void> notifyDoctorNewBooking({
    required String doctorID,
    required String patientName,
    required String date,
    required String timeSlot,
    required String consultationID,
  }) async {
    await createNotification(
      recipientID: doctorID,
      title: 'New Booking Request',
      body: '$patientName has booked a consultation on $date at $timeSlot.',
      type: 'new_booking',
      data: {'consultationID': consultationID},
    );
  }

  /// Notify patient when doctor accepts their booking
  Future<void> notifyPatientBookingAccepted({
    required String patientID,
    required String doctorName,
    required String date,
    required String timeSlot,
    required String consultationID,
  }) async {
    await createNotification(
      recipientID: patientID,
      title: 'Booking Accepted',
      body: '$doctorName has accepted your consultation on $date at $timeSlot.',
      type: 'booking_accepted',
      data: {'consultationID': consultationID},
    );
  }

  /// Notify patient when doctor rejects their booking
  Future<void> notifyPatientBookingRejected({
    required String patientID,
    required String doctorName,
    required String consultationID,
  }) async {
    await createNotification(
      recipientID: patientID,
      title: 'Booking Declined',
      body: '$doctorName has declined your consultation request.',
      type: 'booking_rejected',
      data: {'consultationID': consultationID},
    );
  }

  /// Notify patient when consultation is completed
  Future<void> notifyPatientBookingCompleted({
    required String patientID,
    required String doctorName,
    required String consultationID,
  }) async {
    await createNotification(
      recipientID: patientID,
      title: 'Consultation Completed',
      body: 'Your consultation with $doctorName has been completed.',
      type: 'booking_completed',
      data: {'consultationID': consultationID},
    );
  }

  /// Notify doctor when patient cancels their booking
  Future<void> notifyDoctorBookingCancelled({
    required String doctorID,
    required String patientName,
    required String date,
    required String timeSlot,
    required String consultationID,
  }) async {
    await createNotification(
      recipientID: doctorID,
      title: 'Booking Cancelled',
      body:
          '$patientName has cancelled their appointment on $date at $timeSlot.',
      type: 'booking_cancelled',
      data: {'consultationID': consultationID},
    );
  }

  /// Delete all notifications for a user
  Future<void> clearAllNotifications(String userID) async {
    final snapshot = await _notificationsRef
        .where('recipientID', isEqualTo: userID)
        .get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // ── DFU Risk Alert Helpers ──

  /// Notify doctor about high pressure reading for a patient
  Future<void> notifyDoctorHighPressure({
    required String doctorID,
    required String patientName,
    required String patientID,
    required double pressureValue,
    required String readingID,
  }) async {
    await createNotification(
      recipientID: doctorID,
      title: '⚠️ High Pressure Alert',
      body:
          '$patientName has a high foot pressure reading of ${pressureValue.toStringAsFixed(0)} kPa. Immediate attention may be needed.',
      type: 'high_pressure',
      data: {
        'patientID': patientID,
        'patientName': patientName,
        'readingID': readingID,
        'pressureValue': pressureValue,
      },
    );
  }

  /// Notify doctor about abnormal temperature reading for a patient
  Future<void> notifyDoctorAbnormalTemperature({
    required String doctorID,
    required String patientName,
    required String patientID,
    required double temperatureValue,
    required String readingID,
  }) async {
    await createNotification(
      recipientID: doctorID,
      title: '🌡️ Abnormal Temperature Alert',
      body:
          '$patientName has an abnormal foot temperature of ${temperatureValue.toStringAsFixed(1)} °C. Please review.',
      type: 'abnormal_temperature',
      data: {
        'patientID': patientID,
        'patientName': patientName,
        'readingID': readingID,
        'temperatureValue': temperatureValue,
      },
    );
  }

  /// Notify doctor about elevated pressure (warning level)
  Future<void> notifyDoctorElevatedPressure({
    required String doctorID,
    required String patientName,
    required String patientID,
    required double pressureValue,
    required String readingID,
  }) async {
    await createNotification(
      recipientID: doctorID,
      title: 'Elevated Pressure Warning',
      body:
          '$patientName has an above-normal foot pressure of ${pressureValue.toStringAsFixed(0)} kPa. Monitor closely.',
      type: 'elevated_pressure',
      data: {
        'patientID': patientID,
        'patientName': patientName,
        'readingID': readingID,
        'pressureValue': pressureValue,
      },
    );
  }

  /// Notify doctor about elevated temperature (warning level)
  Future<void> notifyDoctorElevatedTemperature({
    required String doctorID,
    required String patientName,
    required String patientID,
    required double temperatureValue,
    required String readingID,
  }) async {
    await createNotification(
      recipientID: doctorID,
      title: 'Elevated Temperature Warning',
      body:
          '$patientName has an elevated foot temperature of ${temperatureValue.toStringAsFixed(1)} °C. Monitor closely.',
      type: 'elevated_temperature',
      data: {
        'patientID': patientID,
        'patientName': patientName,
        'readingID': readingID,
        'temperatureValue': temperatureValue,
      },
    );
  }

  /// Notify patient about their own high-risk reading
  Future<void> notifyPatientRiskAlert({
    required String patientID,
    required String title,
    required String body,
    required String type,
    required String readingID,
  }) async {
    await createNotification(
      recipientID: patientID,
      title: title,
      body: body,
      type: type,
      data: {'readingID': readingID},
    );
  }
}
