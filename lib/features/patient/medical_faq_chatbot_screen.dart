import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/app_theme.dart';

// ── Palette ─────────────────────────────────────────────────────────
const _kTeal = Color(0xFF64ADB3);
const _kDarkBlue = Color(0xFF3D6A99);

/// DFU-focused FAQ chatbot with medically verified information
/// sourced from IWGDF 2023 guidelines and Saudi MOH protocols.
/// Each answer includes a reference link for patient confidence.
class MedicalFaqChatbotScreen extends StatefulWidget {
  const MedicalFaqChatbotScreen({super.key});

  @override
  State<MedicalFaqChatbotScreen> createState() =>
      _MedicalFaqChatbotScreenState();
}

class _MedicalFaqChatbotScreenState extends State<MedicalFaqChatbotScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  String? _activeCategory;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() {
          _messages.add(
            const _ChatMessage(
              text:
                  'Hello! I\'m your Diabetic Foot Ulcer (DFU) Care Assistant.\n\n'
                  'I can answer questions about DFU infection, ischaemia, wound '
                  'management, and when to seek help — all based on international '
                  'medical guidelines.\n\n'
                  'Choose a topic below to get started.',
              isBot: true,
            ),
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onCategoryTap(String category) {
    setState(() {
      _activeCategory = category;
      _messages.add(_ChatMessage(text: category, isBot: false));
      _messages.add(
        _ChatMessage(
          text:
              'Here are common questions about $category in diabetic foot '
              'ulcers. Tap any question to learn more.',
          isBot: true,
        ),
      );
    });
    _scrollToBottom();
  }

  void _onQuestionTap(_FaqItem faq) {
    setState(() {
      _messages.add(_ChatMessage(text: faq.question, isBot: false));
      _messages.add(
        _ChatMessage(text: faq.answer, isBot: true, reference: faq.reference),
      );
    });
    _scrollToBottom();
  }

  void _onBackToTopics() {
    setState(() {
      _activeCategory = null;
      _messages.add(
        const _ChatMessage(text: 'Choose another topic below.', isBot: true),
      );
    });
    _scrollToBottom();
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // fallback: try in-app browser
      try {
        await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _kTeal,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white24,
              child: Icon(
                Icons.smart_toy_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DFU Care Assistant',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Text(
                  'Evidence-Based Medical FAQ',
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Disclaimer banner ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFFFFF8E1),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: Color(0xFFF9A825)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'For educational purposes only — always follow your doctor\'s advice.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF6D4C00)),
                  ),
                ),
              ],
            ),
          ),

          // ── Chat messages ──
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              itemCount: _messages.length,
              itemBuilder: (context, i) => _buildMessage(_messages[i]),
            ),
          ),

          // ── Category chips or question chips ──
          _buildInputArea(),
        ],
      ),
    );
  }

  // ── Message bubble ──────────────────────────────────────────────

  Widget _buildMessage(_ChatMessage msg) {
    final isBot = msg.isBot;
    return Padding(
      padding: EdgeInsets.only(
        bottom: 12,
        left: isBot ? 0 : 60,
        right: isBot ? 60 : 0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isBot
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        children: [
          if (isBot) ...[
            const CircleAvatar(
              radius: 14,
              backgroundColor: _kTeal,
              child: Icon(
                Icons.smart_toy_rounded,
                size: 14,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isBot
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isBot ? Colors.white : _kTeal.withOpacity(0.12),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isBot ? 4 : 16),
                      bottomRight: Radius.circular(isBot ? 16 : 4),
                    ),
                    boxShadow: isBot
                        ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    msg.text,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.45,
                      color: isBot ? AppColors.textPrimary : _kDarkBlue,
                    ),
                  ),
                ),
                // ── Reference link ──
                if (msg.reference != null) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => _openUrl(msg.reference!.url),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _kTeal.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _kTeal.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.menu_book_rounded,
                            size: 13,
                            color: _kTeal,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              msg.reference!.label,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: _kTeal,
                                fontWeight: FontWeight.w500,
                                decoration: TextDecoration.underline,
                                decorationColor: _kTeal.withOpacity(0.4),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.open_in_new,
                            size: 11,
                            color: _kTeal.withOpacity(0.6),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom input area ───────────────────────────────────────────

  Widget _buildInputArea() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: _activeCategory == null
              ? _buildCategoryChips()
              : _buildQuestionChips(),
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 3.4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: _categories.map((cat) {
        return ActionChip(
          avatar: Icon(cat.icon, size: 16, color: _kDarkBlue),
          label: Text(cat.name, overflow: TextOverflow.ellipsis),
          labelStyle: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: _kDarkBlue,
          ),
          backgroundColor: _kTeal.withOpacity(0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: _kTeal.withOpacity(0.2)),
          ),
          onPressed: () => _onCategoryTap(cat.name),
        );
      }).toList(),
    );
  }

  Widget _buildQuestionChips() {
    final faqs = _faqData[_activeCategory] ?? [];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _onBackToTopics,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(Icons.arrow_back_ios_new, size: 14, color: _kTeal),
                const SizedBox(width: 4),
                Text(
                  'All Topics',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: _kTeal,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 180),
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: faqs.map((faq) {
                return ActionChip(
                  label: Text(faq.question),
                  labelStyle: const TextStyle(fontSize: 12, color: _kDarkBlue),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: _kTeal.withOpacity(0.3)),
                  ),
                  onPressed: () => _onQuestionTap(faq),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Data models ─────────────────────────────────────────────────────

class _ChatMessage {
  final String text;
  final bool isBot;
  final _Reference? reference;
  const _ChatMessage({required this.text, required this.isBot, this.reference});
}

class _Category {
  final String name;
  final IconData icon;
  const _Category(this.name, this.icon);
}

class _FaqItem {
  final String question;
  final String answer;
  final _Reference reference;
  const _FaqItem(this.question, this.answer, this.reference);
}

class _Reference {
  final String label;
  final String url;
  const _Reference(this.label, this.url);
}

// ── Categories ──────────────────────────────────────────────────────

const _categories = [
  _Category('DFU & Infection', Icons.coronavirus_rounded),
  _Category('DFU & Ischaemia', Icons.bloodtype_rounded),
  _Category('Wound Management', Icons.healing_rounded),
  _Category('Risk & Prevention', Icons.shield_rounded),
  _Category('Daily Foot Care', Icons.directions_walk_rounded),
  _Category('When to Seek Help', Icons.local_hospital_rounded),
];

// ── References ──────────────────────────────────────────────────────

const _refIWGDF = _Reference(
  'IWGDF 2023 Guidelines',
  'https://iwgdfguidelines.org/guidelines-2023/',
);
const _refIWGDFInfection = _Reference(
  'IWGDF/IDSA 2023 — Infection Guideline',
  'https://iwgdfguidelines.org/infection-guideline-2023/',
);
const _refIWGDFPAD = _Reference(
  'IWGDF 2023 — PAD Guideline',
  'https://iwgdfguidelines.org/pad-guideline-2023/',
);
const _refIWGDFWound = _Reference(
  'IWGDF 2023 — Wound Healing Guideline',
  'https://iwgdfguidelines.org/wound-healing-2023/',
);
const _refIWGDFPrevention = _Reference(
  'IWGDF 2023 — Prevention Guideline',
  'https://iwgdfguidelines.org/prevention-guideline-2023/',
);
const _refSaudiMOH = _Reference(
  'Saudi MOH — Diabetes & Foot Care',
  'https://www.moh.gov.sa/en/awarenessplateform/ChronicDisease/Pages/Diabetes.aspx',
);
const _refIDSA = _Reference(
  'IWGDF/IDSA 2023 — Infection Guideline (PDF)',
  'https://iwgdfguidelines.org/wp-content/uploads/2023/07/IWGDF-2023-04-Infection-Guideline.pdf',
);

// ── FAQ Data (DFU-specific, IWGDF 2023 + Saudi MOH aligned) ────────

const Map<String, List<_FaqItem>> _faqData = {
  'DFU & Infection': [
    _FaqItem(
      'What is a DFU infection?',
      'A diabetic foot ulcer (DFU) infection occurs when bacteria invade '
          'the wound tissue. Unlike a simple cut, DFU infections are '
          'dangerous because diabetes weakens your immune system and '
          'reduces blood flow needed to fight the infection.\n\n'
          'DFU infections are classified by severity:\n'
          '• Mild — redness extends less than 2 cm from wound edge\n'
          '• Moderate — redness extends more than 2 cm, or deeper tissue involved\n'
          '• Severe — systemic signs (fever, high heart rate, confusion)',
      _refIWGDFInfection,
    ),
    _FaqItem(
      'How do I know if my DFU is infected?',
      'Look for at least 2 of the following signs around your ulcer:\n\n'
          '• Redness (erythema) spreading from the wound edge\n'
          '• Warmth when you touch the area around the ulcer\n'
          '• Swelling or hardness around the wound\n'
          '• Pain or tenderness (note: you may not feel this if you have neuropathy)\n'
          '• Pus or foul-smelling discharge\n\n'
          'Important: In diabetic patients, infection can be present even '
          'without fever or pain due to neuropathy. Any new redness or '
          'discharge should be checked by your doctor promptly.',
      _refIWGDFInfection,
    ),
    _FaqItem(
      'Why is a DFU infection dangerous?',
      'DFU infections can spread rapidly because:\n\n'
          '• High blood sugar feeds bacteria and weakens your immune response\n'
          '• The infection can spread from skin to deeper tissues, '
          'muscle, and bone (osteomyelitis)\n'
          '• If untreated, infection can become life-threatening (sepsis)\n'
          '• Infected DFUs are the leading cause of '
          'non-traumatic lower limb amputations in diabetic patients\n\n'
          'Early treatment with proper antibiotics and wound care is '
          'critical to avoid these outcomes.',
      _refIDSA,
    ),
    _FaqItem(
      'How is an infected DFU treated?',
      'Treatment depends on severity:\n\n'
          '• Mild infection — oral antibiotics + local wound care, '
          'usually managed as outpatient\n'
          '• Moderate infection — may need IV antibiotics, wound '
          'debridement (removing dead tissue), and close monitoring\n'
          '• Severe infection — hospitalization, IV antibiotics, '
          'possible surgical drainage, and multidisciplinary team care\n\n'
          'Never try to treat an infected DFU at home with herbs, honey, '
          'or over-the-counter creams. Antibiotic selection should be '
          'based on wound culture results whenever possible.',
      _refIWGDFInfection,
    ),
  ],
  'DFU & Ischaemia': [
    _FaqItem(
      'What is ischaemia in a DFU?',
      'Ischaemia means reduced blood flow to your foot. In diabetic '
          'patients, this is usually caused by Peripheral Arterial Disease '
          '(PAD) — a narrowing of the arteries that supply blood to your legs.\n\n'
          'About 50% of diabetic foot ulcer patients have some degree of '
          'ischaemia. When blood flow is reduced, the ulcer does not receive '
          'enough oxygen and nutrients to heal properly.',
      _refIWGDFPAD,
    ),
    _FaqItem(
      'How do I know if my DFU has ischaemia?',
      'Signs of ischaemia in your foot include:\n\n'
          '• Foot feels cold compared to the other foot\n'
          '• Skin looks pale, bluish, or dusky\n'
          '• Weak or absent pulse in the foot\n'
          '• Pain in your calf or foot when walking (claudication)\n'
          '• Pain at rest, especially at night in the toes\n'
          '• The ulcer wound looks dry, pale, or has a grey base\n'
          '• Very slow healing despite good wound care\n\n'
          'Important: If you have neuropathy, you may NOT feel the pain '
          'symptoms listed above. This is called "painless ischaemia" and '
          'makes it harder to detect. That is why visual signs (cold, pale, '
          'slow healing) and medical tests like ABI are essential.\n\n'
          'Your doctor can confirm with a simple ankle pressure test (ABI).',
      _refIWGDFPAD,
    ),
    _FaqItem(
      'What is an ABI test?',
      'ABI (Ankle-Brachial Index) is a painless test that checks blood '
          'flow to your feet:\n\n'
          '• A blood pressure cuff is placed on your ankle and arm\n'
          '• The pressures are compared — a ratio below 0.9 suggests PAD\n'
          '• Below 0.5 indicates severe ischaemia that may need urgent '
          'vascular intervention\n\n'
          'If you have a DFU, it is recommended that you have this test done. '
          'Other tests like toe pressure and transcutaneous oxygen (TcPO₂) '
          'may also be used for a more detailed assessment.',
      _refIWGDFPAD,
    ),
    _FaqItem(
      'Why is combined infection + ischaemia so dangerous?',
      'When a DFU has both infection AND ischaemia, it is the highest-risk '
          'scenario:\n\n'
          '• Antibiotics cannot reach the wound effectively because blood '
          'flow is reduced\n'
          '• The infection spreads faster in poorly oxygenated tissue\n'
          '• This combination carries the highest risk of amputation\n'
          '• It requires urgent multidisciplinary care — both a vascular '
          'specialist and infection specialist\n\n'
          'If you are told your ulcer has both problems, seek a specialized '
          'diabetic foot centre immediately — timing is critical.',
      _refIWGDFPAD,
    ),
  ],
  'Wound Management': [
    _FaqItem(
      'How should a DFU be cleaned?',
      'DFU wound cleaning is different from regular wound care:\n\n'
          '• Clean with saline (salt water) solution or clean running water\n'
          '• Do NOT use hydrogen peroxide, iodine, or alcohol — these '
          'damage the new tissue trying to grow\n'
          '• Dead tissue should be removed (debridement) — this must be '
          'done by a trained healthcare professional\n'
          '• Regular debridement helps healing by removing barriers to '
          'new tissue growth\n\n'
          'Never scrape or cut dead tissue yourself at home.',
      _refIWGDFWound,
    ),
    _FaqItem(
      'What dressing should be used on a DFU?',
      'Moist wound dressings are recommended for DFUs:\n\n'
          '• Foam dressings — absorb fluid, cushion the wound\n'
          '• Hydrogel — keeps the wound moist for dry wounds\n'
          '• Alginate — good for wounds with heavy drainage\n\n'
          'The specific dressing depends on your wound type, size, and '
          'amount of fluid. Your wound care nurse will select the best one.\n\n'
          'Do NOT use dry gauze directly on the wound — it sticks and '
          'damages new tissue when removed.',
      _refIWGDFWound,
    ),
    _FaqItem(
      'Does offloading really help DFU healing?',
      'Yes — offloading (removing pressure from the wound) is one of '
          'the MOST important treatments for DFUs on the bottom of the foot.\n\n'
          'Recommended approaches:\n'
          '• A Total Contact Cast (TCC) or irremovable knee-high walker — '
          'this is the gold standard\n'
          '• Even the best dressing will not heal a DFU if you keep '
          'walking on it without offloading\n'
          '• Studies show DFUs heal 2-3 times faster with proper offloading\n\n'
          'Ask your doctor about offloading devices for your specific ulcer.',
      _refIWGDFWound,
    ),
    _FaqItem(
      'Can I use home remedies on my DFU?',
      'No — using home remedies on diabetic foot ulcers is strongly '
          'discouraged:\n\n'
          '• Honey, turmeric, herbal pastes, and oils are NOT recommended\n'
          '• These have no proven benefit for DFUs and can introduce '
          'bacteria, causing infection\n'
          '• "Traditional" treatments can delay proper medical care, '
          'increasing the risk of complications\n\n'
          'Only use dressings and medications prescribed by your '
          'healthcare team.',
      _refSaudiMOH,
    ),
  ],
  'Risk & Prevention': [
    _FaqItem(
      'Who is at high risk for DFU?',
      'You are at higher risk for developing a DFU if you have:\n\n'
          '• Neuropathy (numbness or loss of feeling in your feet)\n'
          '• Peripheral Arterial Disease (poor blood flow)\n'
          '• A previous foot ulcer or amputation\n'
          '• Foot deformities (bunions, hammer toes, Charcot foot)\n'
          '• Poorly controlled blood sugar (HbA1c above 7-8%)\n'
          '• Kidney disease (especially on dialysis)\n'
          '• Smoking\n\n'
          'If you have any of these, you need more frequent foot check-ups.',
      _refIWGDFPrevention,
    ),
    _FaqItem(
      'How does blood sugar affect my DFU?',
      'High blood sugar directly harms DFU healing:\n\n'
          '• Weakens white blood cells — your body cannot fight infections\n'
          '• Damages small blood vessels — less oxygen reaches the wound\n'
          '• Causes neuropathy — you may not feel the ulcer getting worse\n'
          '• Impairs collagen production — new tissue forms slowly\n\n'
          'Keeping your HbA1c at your doctor\'s target (usually below 7%) '
          'significantly improves healing outcomes. Even small improvements '
          'in blood sugar control help.',
      _refIWGDFPrevention,
    ),
    _FaqItem(
      'Does smoking affect my DFU?',
      'Smoking is extremely harmful for DFU patients:\n\n'
          '• Nicotine constricts blood vessels, reducing blood flow to '
          'your feet by up to 40%\n'
          '• Carbon monoxide in smoke reduces oxygen in your blood\n'
          '• Smokers with DFU have significantly higher amputation rates\n'
          '• Smoking also reduces the effectiveness of antibiotics\n\n'
          'Quitting smoking is one of the single most impactful things you '
          'can do for your foot and overall health. Ask your doctor about '
          'smoking cessation support.',
      _refIWGDFPrevention,
    ),
    _FaqItem(
      'Can DFU come back after healing?',
      'Yes — recurrence is very common:\n\n'
          '• About 40% of DFUs recur within 1 year of healing\n'
          '• About 65% recur within 5 years\n\n'
          'To reduce recurrence:\n'
          '• Wear prescribed therapeutic footwear every day\n'
          '• Check your feet daily for any new pressure spots\n'
          '• Keep regular follow-up with your foot care team\n'
          '• Maintain your blood sugar target\n'
          '• Never walk barefoot\n\n'
          'A healed ulcer site remains vulnerable — treat it with extra care.',
      _refIWGDFPrevention,
    ),
  ],
  'Daily Foot Care': [
    _FaqItem(
      'How should I check my feet for DFU signs?',
      'Daily foot inspection is your first line of defence:\n\n'
          '• Check every day at the same time (e.g. before bed)\n'
          '• Look at the top, bottom, sides, and between all toes\n'
          '• Use a mirror or ask someone to help with the soles\n'
          '• Look for: redness, blisters, cuts, calluses, colour changes, '
          'swelling, or any open areas\n'
          '• Feel for hot spots — an area warmer than the rest may '
          'indicate early tissue damage\n\n'
          'If you have neuropathy, you may not feel a developing ulcer. '
          'Visual checks are essential.',
      _refIWGDFPrevention,
    ),
    _FaqItem(
      'What footwear should a DFU patient use?',
      'Proper footwear is critical for DFU prevention and healing:\n\n'
          '• Wear closed-toe, closed-heel shoes at ALL times — never barefoot\n'
          '• Shoes should be wide enough, with no internal seams that rub\n'
          '• Therapeutic or orthopaedic shoes may be prescribed\n'
          '• Custom insoles help redistribute pressure\n'
          '• Always check inside shoes before wearing — look for objects, '
          'rough spots, or bunched-up lining\n\n'
          'Therapeutic footwear is recommended as a key intervention '
          'to prevent new ulcers and recurrence.',
      _refIWGDFPrevention,
    ),
    _FaqItem(
      'How should I care for my feet daily?',
      'Basic daily foot care for DFU patients:\n\n'
          '• Wash feet with lukewarm water (test with elbow, not feet)\n'
          '• Do NOT soak feet — this over-softens the skin\n'
          '• Dry carefully, especially between toes\n'
          '• Apply fragrance-free moisturiser to tops and bottoms\n'
          '• Do NOT put cream between toes (causes fungal infection)\n'
          '• Cut nails straight across — file sharp edges\n'
          '• If nails are thick or you have poor vision, see a podiatrist\n'
          '• Do NOT use corn or callus removers — see your doctor instead',
      _refSaudiMOH,
    ),
  ],
  'When to Seek Help': [
    _FaqItem(
      'When should I see my doctor urgently?',
      'See your doctor within 24 hours if you notice:\n\n'
          '• New redness, swelling, or warmth around your ulcer\n'
          '• Increased pain (or new pain if you have neuropathy)\n'
          '• Pus or bad smell from the wound\n'
          '• Change in wound colour (darker or grey)\n'
          '• Wound getting bigger despite treatment\n'
          '• New numbness or tingling in the foot\n\n'
          'Do NOT wait to see if it gets better on its own — DFU '
          'complications progress quickly.',
      _refIWGDFInfection,
    ),
    _FaqItem(
      'When should I go to the emergency room?',
      'Go to the emergency room immediately if you have:\n\n'
          '• Fever (above 38°C / 100.4°F) with a foot wound\n'
          '• Red streaks spreading up your leg from the wound\n'
          '• Foot turning black, dark purple, or very cold\n'
          '• Sudden severe pain in a previously painless wound\n'
          '• Feeling confused, dizzy, or very unwell\n'
          '• Not able to bear weight on the affected foot\n\n'
          'These are signs of severe infection or critical ischaemia '
          'that require emergency treatment.',
      _refIWGDFInfection,
    ),
    _FaqItem(
      'How often should DFU patients have check-ups?',
      'Recommended foot check-up frequency based on risk:\n\n'
          '• Low risk (no neuropathy) — once a year\n'
          '• Moderate risk (neuropathy only) — every 3-6 months\n'
          '• High risk (neuropathy + PAD or deformity) — every 1-3 months\n'
          '• Very high risk (active ulcer or history of amputation) — '
          'every 1-4 weeks\n\n'
          'If you have an active DFU, you should be seen by a foot care '
          'professional at least every 2-4 weeks until the wound heals.',
      _refIWGDFPrevention,
    ),
    _FaqItem(
      'What is a diabetic foot care team?',
      'A specialized diabetic foot care team includes:\n\n'
          '• Endocrinologist — manages your diabetes and blood sugar\n'
          '• Vascular surgeon — assesses and treats blood flow problems\n'
          '• Podiatrist — specialized foot care and offloading\n'
          '• Orthopaedic surgeon — bone/joint issues, Charcot foot\n'
          '• Wound care nurse — dressing changes, wound monitoring\n'
          '• Orthotist — custom footwear and insoles\n\n'
          'Multidisciplinary team care is strongly recommended for '
          'all moderate-to-severe DFUs. Studies show it reduces amputations '
          'by over 50%. Ask your doctor for a referral if available.',
      _refIWGDF,
    ),
  ],
};
