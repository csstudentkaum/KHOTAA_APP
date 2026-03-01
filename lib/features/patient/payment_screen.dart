import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'payment_success_screen.dart';

// ── Figma palette ───────────────────────────────────────────────────
const _kTeal = Color(0xFF64ADB3);

/// Payment screen — card payment form with teal header
class PaymentScreen extends StatefulWidget {
  final String doctorName;
  final String date;
  final String time;

  const PaymentScreen({
    super.key,
    required this.doctorName,
    this.date = '',
    this.time = '',
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  int _methodIndex = 0; // 0 = Card, 1 = Apple Pay
  final _cardController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _cardController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _pickExpiryDate() {
    final now = DateTime.now();
    int selectedMonth = now.month;
    int selectedYear = now.year;

    const monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];

    showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 310,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            // Top bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              height: 50,
              decoration: const BoxDecoration(
                color: Color(0xFFF7F7F7),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel',
                      style: TextStyle(fontSize: 16, color: Color(0xFF999999)),
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      final mm = selectedMonth.toString().padLeft(2, '0');
                      final yy = (selectedYear % 100).toString().padLeft(2, '0');
                      setState(() => _expiryController.text = '$mm / $yy');
                      Navigator.pop(context);
                    },
                    child: const Text('Done',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _kTeal),
                    ),
                  ),
                ],
              ),
            ),
            // Cupertino wheel pickers
            Expanded(
              child: Row(
                children: [
                  // Month
                  Expanded(
                    flex: 2,
                    child: CupertinoPicker(
                      scrollController: FixedExtentScrollController(
                        initialItem: now.month - 1,
                      ),
                      itemExtent: 40,
                      selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
                        background: _kTeal.withValues(alpha: 0.08),
                      ),
                      onSelectedItemChanged: (i) => selectedMonth = i + 1,
                      children: List.generate(12, (i) => Center(
                        child: Text(
                          monthNames[i],
                          style: const TextStyle(fontSize: 18, color: Color(0xFF1A1A1A)),
                        ),
                      )),
                    ),
                  ),
                  // Year
                  Expanded(
                    flex: 1,
                    child: CupertinoPicker(
                      scrollController: FixedExtentScrollController(initialItem: 0),
                      itemExtent: 40,
                      selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
                        background: _kTeal.withValues(alpha: 0.08),
                      ),
                      onSelectedItemChanged: (i) => selectedYear = now.year + i,
                      children: List.generate(15, (i) => Center(
                        child: Text(
                          (now.year + i).toString(),
                          style: const TextStyle(fontSize: 18, color: Color(0xFF1A1A1A)),
                        ),
                      )),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          // ── Teal header ──────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              bottom: 32,
            ),
            decoration: const BoxDecoration(
              color: _kTeal,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: Column(
              children: [
                // Back + title row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.chevron_left,
                            size: 30, color: Colors.white),
                      ),
                      const Expanded(
                        child: Text(
                          'Payment',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            fontStyle: FontStyle.italic,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // ── Amount ──
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SvgPicture.asset(
                      'assets/icons/riyal_icon.svg',
                      width: 22,
                      height: 26,
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      '120.00',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Form body ──────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Doctor Channeling Payment Method',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // ── Payment method toggle ──
                  Row(
                    children: [
                      Expanded(child: _methodChip('Card Payment', 0)),
                      const SizedBox(width: 12),
                      Expanded(child: _methodChip('Apple Pay', 1)),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // ── Card Payment form / Apple Pay ──
                  if (_methodIndex == 0) ...[
                    // Card Number
                    _label('Card Number'),
                    const SizedBox(height: 10),
                    _inputField(
                      controller: _cardController,
                      hint: 'XXXX XXXX XXXX XXXX',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 22),

                    // Expiry + CVV row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('Expiry Date'),
                              const SizedBox(height: 10),
                              GestureDetector(
                                onTap: _pickExpiryDate,
                                child: AbsorbPointer(
                                  child: _inputField(
                                    controller: _expiryController,
                                    hint: 'MM / YY',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('CVV'),
                              const SizedBox(height: 10),
                              _inputField(
                                controller: _cvvController,
                                hint: '***',
                                keyboardType: TextInputType.number,
                                obscure: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),

                    // Name
                    _label('Name'),
                    const SizedBox(height: 10),
                    _inputField(
                      controller: _nameController,
                      hint: 'Cardholder Name',
                    ),
                    const SizedBox(height: 36),

                    // Pay Now button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PaymentSuccessScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kTeal,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        child: const Text('Pay Now'),
                      ),
                    ),
                  ] else ...[
                    // ── Apple Pay UI ──
                    const SizedBox(height: 20),
                    Center(
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.apple,
                          size: 52,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Center(
                      child: Text(
                        'Pay with Apple Pay',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Confirm the payment of SAR 120.00\nusing your Apple Pay account',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: const Color(0xFF888888),
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PaymentSuccessScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A1A1A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.apple, size: 24, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'Pay',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _methodChip(String label, int index) {
    final selected = _methodIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _methodIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 13),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _kTeal : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _kTeal : const Color(0xFFE0E0E0),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF666666),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xFF444444),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    bool obscure = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscure,
        style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A1A)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 15),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        ),
      ),
    );
  }
}
