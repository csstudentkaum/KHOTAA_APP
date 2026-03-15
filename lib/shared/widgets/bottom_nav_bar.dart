import 'package:flutter/material.dart';
import '../../app/app_theme.dart';

class KhotaaBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const KhotaaBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _outlinedIcons = [
    Icons.home_outlined,
    Icons.camera_alt_outlined,
    Icons.bluetooth,
    Icons.calendar_month_outlined,
    Icons.person_outline,
  ];

  static const _filledIcons = [
    Icons.home,
    Icons.camera_alt,
    Icons.bluetooth,
    Icons.calendar_month,
    Icons.person,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_outlinedIcons.length, (i) {
              final active = i == currentIndex;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.primary.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    active ? _filledIcons[i] : _outlinedIcons[i],
                    size: 26,
                    color: active ? AppColors.primary : AppColors.textHint,
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
