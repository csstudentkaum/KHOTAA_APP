import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:flutter_svg/flutter_svg.dart'; // re-enable when amount is wired up
import '../../app/app_theme.dart';
import 'payment_success_screen.dart';

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
  final _cardController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _nameController = TextEditingController();

  // Detected card type from number prefix
  String? _cardType;

  void _detectCardType(String number) {
    final digits = number.replaceAll(RegExp(r'\s'), '');
    setState(() {
      if (digits.isEmpty) {
        _cardType = null;
      } else if (digits.startsWith('4')) {
        _cardType = 'visa';
      } else if (digits.startsWith('5')) {
        _cardType = 'mastercard';
      } else if (digits.startsWith('9')) {
        _cardType = 'mada';
      }
    });
  }

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
                    child: Text('Done',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.primary),
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
                        background: AppColors.primary.withValues(alpha: 0.08),
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
                        background: AppColors.primary.withValues(alpha: 0.08),
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
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Teal header ──────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              bottom: 32,
            ),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.85),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: SizedBox(
              height: 110,
              child: Stack(
              alignment: Alignment.center,
              children: [
                // Back arrow
                Positioned(
                  left: 4,
                  top: 0,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.chevron_left,
                        size: 30, color: Colors.white),
                  ),
                ),
                // Centered title
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    'Payment',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      fontStyle: FontStyle.italic,
                      color: Colors.white,
                    ),
                  ),
                ),
                // ── Amount (commented out until real salary is wired up) ──
                // Row(
                //   mainAxisSize: MainAxisSize.min,
                //   children: [
                //     SvgPicture.asset('assets/icons/riyal_icon.svg',
                //         width: 22, height: 26,
                //         colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn)),
                //     const SizedBox(width: 4),
                //     const Text('120.00',
                //         style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold,
                //             color: Colors.white, letterSpacing: 0.5)),
                //   ],
                // ),
              ],
              ),
            ),
          ),

          // ── Form body ──────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Card Details',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Card Number
                    _label('Card Number'),
                    const SizedBox(height: 10),
                    _inputField(
                      controller: _cardController,
                      hint: 'XXXX XXXX XXXX XXXX',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(16)],
                      onChanged: _detectCardType,
                      suffix: _cardType != null ? _activeCardIcon() : null,
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
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
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
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: const Text('Pay Now'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────

  Widget _activeCardIcon() {
    Color color;
    switch (_cardType) {
      case 'visa':
        color = const Color(0xFF1A1F71);
      case 'mastercard':
        color = const Color(0xFFEB001B);
      case 'mada':
        color = AppColors.primary;
      default:
        return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Icon(Icons.credit_card, size: 22, color: color),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    bool obscure = false,
    ValueChanged<String>? onChanged,
    Widget? suffix,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscure,
        onChanged: onChanged,
        inputFormatters: inputFormatters,
        style: TextStyle(fontSize: 15, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: AppColors.textHint, fontSize: 15),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          suffixIcon: suffix,
        ),
      ),
    );
  }
}
