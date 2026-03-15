import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../app/app_theme.dart';

/// Doctor working hours management screen
class WorkingHoursScreen extends StatefulWidget {
  const WorkingHoursScreen({super.key});

  @override
  State<WorkingHoursScreen> createState() => _WorkingHoursScreenState();
}

class _WorkingHoursScreenState extends State<WorkingHoursScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  // Day configs: enabled, start time, end time
  final Map<String, _DayConfig> _days = {
    'Sunday': _DayConfig(enabled: true, start: '12:00 AM', end: '11:59 PM'),
    'Monday': _DayConfig(enabled: true, start: '12:00 AM', end: '11:59 PM'),
    'Tuesday': _DayConfig(enabled: true, start: '12:00 AM', end: '11:59 PM'),
    'Wednesday': _DayConfig(enabled: true, start: '12:00 AM', end: '11:59 PM'),
    'Thursday': _DayConfig(enabled: true, start: '12:00 AM', end: '11:59 PM'),
    'Friday': _DayConfig(enabled: false, start: '09:00 AM', end: '05:00 PM'),
    'Saturday': _DayConfig(enabled: false, start: '09:00 AM', end: '05:00 PM'),
  };

  static const _allTimeOptions = [
    '12:00 AM',
    '12:30 AM',
    '01:00 AM',
    '01:30 AM',
    '02:00 AM',
    '02:30 AM',
    '03:00 AM',
    '03:30 AM',
    '04:00 AM',
    '04:30 AM',
    '05:00 AM',
    '05:30 AM',
    '06:00 AM',
    '06:30 AM',
    '07:00 AM',
    '07:30 AM',
    '08:00 AM',
    '08:30 AM',
    '09:00 AM',
    '09:30 AM',
    '10:00 AM',
    '10:30 AM',
    '11:00 AM',
    '11:30 AM',
    '12:00 PM',
    '12:30 PM',
    '01:00 PM',
    '01:30 PM',
    '02:00 PM',
    '02:30 PM',
    '03:00 PM',
    '03:30 PM',
    '04:00 PM',
    '04:30 PM',
    '05:00 PM',
    '05:30 PM',
    '06:00 PM',
    '06:30 PM',
    '07:00 PM',
    '07:30 PM',
    '08:00 PM',
    '08:30 PM',
    '09:00 PM',
    '09:30 PM',
    '10:00 PM',
    '10:30 PM',
    '11:00 PM',
    '11:30 PM',
    '11:59 PM',
  ];

  @override
  void initState() {
    super.initState();
    _loadWorkingHours();
  }

  Future<void> _loadWorkingHours() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data();
        final hours = data?['workingHours'] as Map<String, dynamic>?;

        if (hours != null) {
          for (final day in _days.keys) {
            final dayData = hours[day] as Map<String, dynamic>?;
            if (dayData != null) {
              _days[day]!.enabled = dayData['enabled'] ?? false;
              _days[day]!.start = dayData['start'] ?? '09:00 AM';
              _days[day]!.end = dayData['end'] ?? '05:00 PM';
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading working hours: $e');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _saveWorkingHours() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      final hoursMap = <String, dynamic>{};
      for (final entry in _days.entries) {
        hoursMap[entry.key] = {
          'enabled': entry.value.enabled,
          'start': entry.value.start,
          'end': entry.value.end,
        };
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'workingHours': hoursMap},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Working hours saved'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showTimePicker(String day, bool isStart) {
    final current = isStart ? _days[day]!.start : _days[day]!.end;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${isStart ? "Start" : "End"} Time — $day',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(),
              SizedBox(
                height: 300,
                child: ListView.builder(
                  itemCount: _allTimeOptions.length,
                  itemBuilder: (_, i) {
                    final time = _allTimeOptions[i];
                    final isSelected = time == current;
                    return ListTile(
                      title: Text(
                        time,
                        style: TextStyle(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textPrimary,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: AppColors.primary)
                          : null,
                      onTap: () {
                        setState(() {
                          if (isStart) {
                            _days[day]!.start = time;
                          } else {
                            _days[day]!.end = time;
                          }
                        });
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
          'Working Hours',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Info card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primary.withAlpha(40),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Set your available days and hours. Patients will only be able to book during these times.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.primary,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Day cards
                      ..._days.entries.map(
                        (e) => _buildDayCard(e.key, e.value),
                      ),
                    ],
                  ),
                ),
                // Save button
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveWorkingHours,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Save Changes',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildDayCard(String day, _DayConfig config) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: config.enabled
              ? AppColors.primary.withAlpha(40)
              : AppColors.divider,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  day,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: config.enabled
                        ? AppColors.textPrimary
                        : AppColors.textHint,
                  ),
                ),
              ),
              Switch(
                value: config.enabled,
                activeColor: AppColors.primary,
                onChanged: (val) {
                  setState(() => config.enabled = val);
                },
              ),
            ],
          ),
          if (config.enabled) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _timeButton(
                    label: 'From',
                    value: config.start,
                    onTap: () => _showTimePicker(day, true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _timeButton(
                    label: 'To',
                    value: config.end,
                    onTap: () => _showTimePicker(day, false),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _timeButton({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.inputBorder),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.textHint),
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.access_time, size: 16, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

class _DayConfig {
  bool enabled;
  String start;
  String end;

  _DayConfig({required this.enabled, required this.start, required this.end});
}
