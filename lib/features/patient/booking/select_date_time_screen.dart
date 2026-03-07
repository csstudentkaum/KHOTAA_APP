import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../app/app_theme.dart';
import '../../../models/doctor_model.dart';
import '../../../services/consultation_service.dart';

/// Select Date and Time screen for booking
class SelectDateTimeScreen extends StatefulWidget {
  final DoctorModel doctor;

  const SelectDateTimeScreen({super.key, required this.doctor});

  @override
  State<SelectDateTimeScreen> createState() => _SelectDateTimeScreenState();
}

class _SelectDateTimeScreenState extends State<SelectDateTimeScreen> {
  final ConsultationService _consultationService = ConsultationService();

  DateTime _selectedDate = DateTime.now();
  String? _selectedTimeSlot;
  List<String> _availableSlots = [];
  bool _isLoadingSlots = false;
  bool _isBooking = false;

  int _currentMonth = DateTime.now().month;
  int _currentYear = DateTime.now().year;

  /// Doctor's working hours loaded from Firestore (null = not loaded yet / no custom hours)
  Map<String, dynamic>? _workingHours;

  static const _dayNames = [
    '', // 0 unused
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  void initState() {
    super.initState();
    _loadWorkingHours();
  }

  Future<void> _loadWorkingHours() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.doctor.id)
          .get();

      if (doc.exists && mounted) {
        setState(() {
          _workingHours = doc.data()?['workingHours'] as Map<String, dynamic>?;
        });
      }
    } catch (_) {}

    if (!mounted) return;

    // After loading working hours, auto-select the first available date
    _autoSelectFirstWorkingDay();
    _loadAvailableSlots();
  }

  /// Check if a date is a working day for this doctor
  bool _isWorkingDay(DateTime date) {
    if (_workingHours == null) return true; // no custom hours → all days open
    final dayName = _dayNames[date.weekday];
    final dayData = _workingHours![dayName] as Map<String, dynamic>?;
    return dayData != null && dayData['enabled'] == true;
  }

  /// Auto-select the nearest working day from today
  void _autoSelectFirstWorkingDay() {
    if (!mounted) return;
    DateTime candidate = DateTime.now();
    for (int i = 0; i < 60; i++) {
      if (_isWorkingDay(candidate)) {
        setState(() {
          _selectedDate = candidate;
          _currentMonth = candidate.month;
          _currentYear = candidate.year;
        });
        return;
      }
      candidate = candidate.add(const Duration(days: 1));
    }
  }

  Future<void> _loadAvailableSlots() async {
    if (!mounted) return;
    setState(() {
      _isLoadingSlots = true;
      _selectedTimeSlot = null;
    });

    try {
      final slots = await _consultationService.getAvailableTimeSlots(
        widget.doctor.id,
        _selectedDate,
      );
      if (mounted) {
        setState(() {
          _availableSlots = slots;
          _isLoadingSlots = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading slots: $e');
      if (mounted) {
        setState(() {
          _availableSlots = [];
          _isLoadingSlots = false;
        });
      }
    }
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
    _loadAvailableSlots();
  }

  Future<void> _bookAppointment() async {
    if (_selectedTimeSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a time slot')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to book an appointment')),
      );
      return;
    }

    setState(() => _isBooking = true);

    try {
      // Check if patient already has an active consultation
      final hasActive = await _consultationService.hasActiveConsultation(
        user.uid,
      );
      if (hasActive) {
        if (mounted) {
          setState(() => _isBooking = false);
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              icon: const Icon(
                Icons.info_outline,
                color: Colors.orange,
                size: 48,
              ),
              title: const Text('Active Booking Exists'),
              content: const Text(
                'You already have an active consultation. Please wait until it is completed before booking a new one.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return;
      }

      // Get patient name
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final patientName = userDoc.exists
          ? '${userDoc.data()?['firstName'] ?? ''} ${userDoc.data()?['lastName'] ?? ''}'
          : 'Patient';

      debugPrint(' Booking with patientID (auth uid): ${user.uid}');
      debugPrint(' Booking with doctorID (doc.id): ${widget.doctor.id}');

      await _consultationService.createConsultation(
        patientID: user.uid,
        doctorID: widget.doctor.id,
        patientName: patientName.trim(),
        doctorName: 'Dr. ${widget.doctor.firstName} ${widget.doctor.lastName}',
        consultationDate: _selectedDate,
        timeSlot: _selectedTimeSlot!,
      );

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      debugPrint('Error booking: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to book: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isBooking = false);
      }
    }
  }

  void _showSuccessDialog() {
    final navContext = context; // capture page context
    showDialog(
      context: navContext,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                color: AppColors.success,
                size: 60,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Booking Successful!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Your appointment with Dr. ${widget.doctor.firstName} has been booked for ${_formatDate(_selectedDate)} at $_selectedTimeSlot',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogCtx); // Close dialog
                  Navigator.pop(navContext); // Go back to doctor detail
                  Navigator.pop(navContext); // Go back to doctors list
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Select Date and Time',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Calendar
                  _buildCalendar(),
                  const SizedBox(height: 24),

                  // Available time slots
                  const Text(
                    'Available Time Slot',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTimeSlots(),
                ],
              ),
            ),
          ),

          // Book button
          _buildBottomButton(),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          // Month and year header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _getMonthName(_currentMonth),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$_currentYear',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Day labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                .map(
                  (day) => SizedBox(
                    width: 36,
                    child: Center(
                      child: Text(
                        day,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),

          // Calendar grid
          _buildCalendarGrid(),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDayOfMonth = DateTime(_currentYear, _currentMonth, 1);
    final lastDayOfMonth = DateTime(_currentYear, _currentMonth + 1, 0);
    final daysInMonth = lastDayOfMonth.day;

    // Get the weekday of the first day (1 = Monday, 7 = Sunday)
    int startWeekday = firstDayOfMonth.weekday;

    // Calculate days from previous month to show
    final prevMonth = _currentMonth == 1 ? 12 : _currentMonth - 1;
    final prevYear = _currentMonth == 1 ? _currentYear - 1 : _currentYear;
    final daysInPrevMonth = DateTime(prevYear, prevMonth + 1, 0).day;

    List<Widget> dayWidgets = [];

    // Previous month days
    for (int i = startWeekday - 1; i > 0; i--) {
      final day = daysInPrevMonth - i + 1;
      dayWidgets.add(_buildDayCell(day, isCurrentMonth: false));
    }

    // Current month days
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_currentYear, _currentMonth, day);
      final isSelected = _isSameDay(date, _selectedDate);
      final isToday = _isSameDay(date, DateTime.now());
      final isPast = date.isBefore(DateTime.now()) && !isToday;
      final isOff = !_isWorkingDay(date);

      dayWidgets.add(
        _buildDayCell(
          day,
          isSelected: isSelected,
          isToday: isToday,
          isPast: isPast,
          isDayOff: isOff,
          onTap: (isPast || isOff) ? null : () => _selectDate(date),
        ),
      );
    }

    // Next month days to fill the grid
    final remainingCells = 7 - (dayWidgets.length % 7);
    if (remainingCells < 7) {
      for (int i = 1; i <= remainingCells; i++) {
        dayWidgets.add(_buildDayCell(i, isCurrentMonth: false));
      }
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 7,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: dayWidgets,
    );
  }

  Widget _buildDayCell(
    int day, {
    bool isCurrentMonth = true,
    bool isSelected = false,
    bool isToday = false,
    bool isPast = false,
    bool isDayOff = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : isToday
              ? AppColors.primary.withOpacity(0.1)
              : isDayOff && isCurrentMonth
              ? Colors.grey.withOpacity(0.08)
              : null,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            '$day',
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : !isCurrentMonth || isPast
                  ? AppColors.textHint
                  : isDayOff
                  ? AppColors.textHint
                  : AppColors.textPrimary,
              fontWeight: isSelected || isToday
                  ? FontWeight.bold
                  : FontWeight.normal,
              decoration: isDayOff && isCurrentMonth && !isPast
                  ? TextDecoration.lineThrough
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  Widget _buildTimeSlots() {
    if (_isLoadingSlots) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_availableSlots.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'No available slots for this date',
            style: TextStyle(color: AppColors.textHint),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _availableSlots.map((slot) {
        final isSelected = _selectedTimeSlot == slot;
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedTimeSlot = slot;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.divider,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              slot,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBottomButton() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _isBooking || _selectedTimeSlot == null
                ? null
                : _bookAppointment,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: _isBooking
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Set Appointment',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ),
    );
  }
}
