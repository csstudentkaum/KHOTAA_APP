import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../app/app_theme.dart';
import '../../../models/consultation.dart';
import '../../../services/consultation_service.dart';
import '../../../services/notification_service.dart';
import '../../shared/consultation_session_screen.dart';
import '../../shared/treatment_plan_view.dart';

/// My Appointments screen - shows patient's consultation appointments
class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ConsultationService _consultationService = ConsultationService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Appointments',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textHint,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Follow-Up'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: user == null
          ? _buildNotLoggedIn()
          : StreamBuilder<List<Consultation>>(
              stream: _consultationService.streamPatientConsultations(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final all = snapshot.data ?? [];
                final upcoming = all.where((c) => c.isUpcoming).toList();
                final followUp = all.where((c) => c.isFollowUp).toList();
                final past = all.where((c) => c.isPast).toList();

                // Sort by date + time slot (soonest first)
                upcoming.sort((a, b) {
                  final dateA = a.consultationDate ?? DateTime(2099);
                  final dateB = b.consultationDate ?? DateTime(2099);
                  final dateCmp = dateA.compareTo(dateB);
                  if (dateCmp != 0) return dateCmp;
                  final timeA = _parseTimeSlot(a.timeSlot ?? '');
                  final timeB = _parseTimeSlot(b.timeSlot ?? '');
                  final minutesA = timeA != null
                      ? timeA.hour * 60 + timeA.minute
                      : 9999;
                  final minutesB = timeB != null
                      ? timeB.hour * 60 + timeB.minute
                      : 9999;
                  return minutesA.compareTo(minutesB);
                });

                // Past: most recent first
                past.sort((a, b) {
                  final dateA = a.consultationDate ?? DateTime(2099);
                  final dateB = b.consultationDate ?? DateTime(2099);
                  final dateCmp = dateB.compareTo(dateA);
                  if (dateCmp != 0) return dateCmp;
                  final timeA = _parseTimeSlot(a.timeSlot ?? '');
                  final timeB = _parseTimeSlot(b.timeSlot ?? '');
                  final minutesA = timeA != null
                      ? timeA.hour * 60 + timeA.minute
                      : 9999;
                  final minutesB = timeB != null
                      ? timeB.hour * 60 + timeB.minute
                      : 9999;
                  return minutesB.compareTo(minutesA);
                });

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildList(upcoming, isUpcoming: true),
                    _buildFollowUpList(followUp),
                    _buildList(past, isUpcoming: false),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildNotLoggedIn() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.login_outlined, size: 80, color: AppColors.textHint),
          SizedBox(height: 16),
          Text(
            'Please log in to view your bookings',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<Consultation> items, {required bool isUpcoming}) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isUpcoming
                  ? Icons.calendar_today_outlined
                  : Icons.history_outlined,
              size: 80,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 16),
            Text(
              isUpcoming ? 'No upcoming appointments' : 'No past appointments',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
            if (isUpcoming) ...[
              const SizedBox(height: 8),
              const Text(
                'Book an appointment with a doctor',
                style: TextStyle(color: AppColors.textHint, fontSize: 14),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  // Pop with a result so the caller can switch to Find a Doctor tab
                  Navigator.pop(context, 'findDoctor');
                },
                child: const Text(
                  'Find a Doctor',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {});
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          return _buildCard(items[index], isUpcoming: isUpcoming);
        },
      ),
    );
  }

  Widget _buildFollowUpList(List<Consultation> items) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.follow_the_signs_outlined,
              size: 80,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 16),
            const Text(
              'No follow-up sessions',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Active follow-up consultations will appear here',
              style: TextStyle(color: AppColors.textHint, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final c = items[index];
        final dueDate = c.followUpDueDate;
        String dueDateStr = '';
        if (dueDate != null) {
          dueDateStr =
              '${_monthName(dueDate.month)} ${dueDate.day}, ${dueDate.year}';
        }

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ConsultationSessionScreen(
                  consultationId: c.consultationID,
                  isDoctor: false,
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.inputBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(5),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row — same as doctor card
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person,
                        color: AppColors.primary.withAlpha(120),
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.doctorName?.startsWith('Dr.') == true
                                ? c.doctorName!
                                : 'Dr. ${c.doctorName ?? 'Unknown'}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'General Consultation',
                            style: TextStyle(
                              color: AppColors.textHint,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withAlpha(25),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'FOLLOW-UP',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // Date and time row
                Row(
                  children: [
                    _buildInfoChip(
                      Icons.calendar_today_outlined,
                      c.consultationDate != null ? c.formattedDate : 'No date',
                    ),
                    const SizedBox(width: 16),
                    if (c.timeSlot != null)
                      _buildInfoChip(Icons.access_time, c.timeSlot!),
                  ],
                ),

                // Due date
                if (dueDateStr.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [_buildInfoChip(Icons.event, 'Due: $dueDateStr')],
                  ),
                ],

                // Check-in status + Treatment Plan row
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (c.isCheckInDue && !c.hasCheckIn)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error.withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Check-in Due',
                          style: TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    if (c.hasCheckIn)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Check-in Done',
                          style: TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    const Spacer(),
                    if (c.treatmentPlanID != null &&
                        c.treatmentPlanID!.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TreatmentPlanView(
                                consultationId: c.consultationID,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.description_outlined,
                                size: 14,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Treatment Plan',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _monthName(int month) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month];
  }

  Widget _buildCard(Consultation c, {required bool isUpcoming}) {
    Color statusColor;
    IconData statusIcon;

    switch (c.status) {
      case 'accepted':
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle_outline;
        break;
      case 'active':
        statusColor = const Color(0xFF3B82F6);
        statusIcon = Icons.play_circle_outline;
        break;
      case 'followUp':
        statusColor = Colors.orange;
        statusIcon = Icons.access_time;
        break;
      case 'rejected':
        statusColor = AppColors.error;
        statusIcon = Icons.cancel_outlined;
        break;
      case 'completed':
        statusColor = AppColors.primary;
        statusIcon = Icons.done_all;
        break;
      default: // pending
        statusColor = AppColors.warning;
        statusIcon = Icons.schedule;
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ConsultationSessionScreen(
              consultationId: c.consultationID,
              isDoctor: false,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.inputBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(5),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person,
                      color: AppColors.primary.withAlpha(120),
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.doctorName ?? 'Doctor',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'General Consultation',
                          style: TextStyle(
                            color: AppColors.textHint,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (c.status != 'accepted' && c.status != 'rejected')
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withAlpha(25),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 14, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            c.status.toUpperCase(),
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Date and time row
              Row(
                children: [
                  _buildInfoChip(
                    Icons.calendar_today_outlined,
                    c.formattedDate,
                  ),
                  const SizedBox(width: 16),
                  if (c.timeSlot != null)
                    _buildInfoChip(Icons.access_time, c.timeSlot!),
                ],
              ),

              // Cancel button for upcoming pending or accepted
              if (isUpcoming &&
                  (c.status == 'pending' || c.status == 'accepted')) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showCancelDialog(c),
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    label: const Text('Cancel Appointment'),
                  ),
                ),
              ],

              // Start Consultation button for upcoming accepted (disabled until 30 min before)
              if (isUpcoming && c.status == 'accepted') ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isChatCallAvailable(c)
                        ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ConsultationSessionScreen(
                                  consultationId: c.consultationID,
                                  isDoctor: false,
                                ),
                              ),
                            );
                          }
                        : null,
                    icon: Icon(
                      Icons.video_call_outlined,
                      size: 20,
                      color: _isChatCallAvailable(c)
                          ? Colors.white
                          : AppColors.textHint,
                    ),
                    label: Text(
                      _isChatCallAvailable(c)
                          ? 'Start Consultation'
                          : 'Available 30 min before appointment',
                      style: TextStyle(
                        color: _isChatCallAvailable(c)
                            ? Colors.white
                            : AppColors.textHint,
                        fontWeight: FontWeight.w600,
                        fontSize: _isChatCallAvailable(c) ? 14 : 12,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isChatCallAvailable(c)
                          ? AppColors.primary
                          : Colors.grey.shade200,
                      disabledBackgroundColor: Colors.grey.shade200,
                      elevation: _isChatCallAvailable(c) ? 2 : 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ],
    );
  }

  void _showCancelDialog(Consultation c) {
    final scaffoldContext = context; // capture the page context
    showDialog(
      context: scaffoldContext,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Icon(
          Icons.warning_amber_rounded,
          size: 48,
          color: AppColors.error,
        ),
        title: const Text(
          'Cancel Appointment',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to cancel this appointment?\n\nThis action cannot be undone and the booking will be permanently removed.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Keep'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    // Close the dialog first
                    Navigator.pop(dialogCtx);

                    try {
                      // Notify the doctor before deleting
                      final months = [
                        'Jan',
                        'Feb',
                        'Mar',
                        'Apr',
                        'May',
                        'Jun',
                        'Jul',
                        'Aug',
                        'Sep',
                        'Oct',
                        'Nov',
                        'Dec',
                      ];
                      final dateStr = c.consultationDate != null
                          ? '${months[c.consultationDate!.month - 1]} ${c.consultationDate!.day}'
                          : 'N/A';

                      await NotificationService().notifyDoctorBookingCancelled(
                        doctorID: c.doctorID,
                        patientName: c.patientName ?? 'A patient',
                        date: dateStr,
                        timeSlot: c.timeSlot ?? '',
                        consultationID: c.consultationID,
                      );

                      await _consultationService.deleteConsultation(
                        c.consultationID,
                      );

                      if (mounted) {
                        ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                          const SnackBar(
                            content: Text('Appointment cancelled and removed'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(
                          scaffoldContext,
                        ).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Yes, Cancel',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Returns true if the consultation starts within 30 minutes from now
  /// or has already started.
  bool _isChatCallAvailable(Consultation booking) {
    if (booking.consultationDate == null || booking.timeSlot == null) {
      return false;
    }
    final slotTime = _parseTimeSlot(booking.timeSlot!);
    if (slotTime == null) return false;

    final consultDate = booking.consultationDate!;
    final appointmentDateTime = DateTime(
      consultDate.year,
      consultDate.month,
      consultDate.day,
      slotTime.hour,
      slotTime.minute,
    );

    final now = DateTime.now();
    final diff = appointmentDateTime.difference(now).inMinutes;
    return diff <= 30;
  }

  /// Parses a time slot string like "10:00 AM" into a TimeOfDay.
  TimeOfDay? _parseTimeSlot(String slot) {
    try {
      final parts = slot.trim().split(' ');
      if (parts.length != 2) return null;
      final timeParts = parts[0].split(':');
      if (timeParts.length != 2) return null;

      int hour = int.parse(timeParts[0]);
      final int minute = int.parse(timeParts[1]);
      final period = parts[1].toUpperCase();

      if (period == 'PM' && hour != 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;

      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return null;
    }
  }
}
