import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:healthpocket/features/care/presentation/care_v2_common.dart';

class CareBankOption {
  const CareBankOption(
    this.code,
    this.name,
    this.initials,
    this.background,
    this.foreground,
  );
  final String code;
  final String name;
  final String initials;
  final Color background;
  final Color foreground;
}

const carePreviewBanks = <CareBankOption>[
  CareBankOption(
    '044',
    'Access Bank',
    'AB',
    Color(0xFFD9E8FF),
    Color(0xFF2B5BD7),
  ),
  CareBankOption('058', 'GTBank', 'GT', Color(0xFFFFEBC8), Color(0xFF9A6200)),
  CareBankOption(
    'preview_first',
    'First Bank',
    'FB',
    Color(0xFFCDEFEA),
    CareV2.teal,
  ),
  CareBankOption('033', 'UBA', 'UB', Color(0xFFFFDDE5), Color(0xFFE8405F)),
  CareBankOption(
    'preview_zenith',
    'Zenith Bank',
    'ZB',
    Color(0xFFE6DEFB),
    Color(0xFF5B3FC4),
  ),
  CareBankOption(
    'preview_kuda',
    'Kuda',
    'KD',
    Color(0xFFE6DEFB),
    Color(0xFF5B3FC4),
  ),
  CareBankOption('preview_opay', 'Opay', 'OP', Color(0xFFCDEFEA), CareV2.teal),
  CareBankOption(
    'preview_moniepoint',
    'Moniepoint',
    'MP',
    Color(0xFFD9E8FF),
    Color(0xFF2B5BD7),
  ),
  CareBankOption(
    'preview_wema',
    'Wema Bank',
    'WB',
    Color(0xFFE6DEFB),
    Color(0xFF5B3FC4),
  ),
];

class CareV2BankSelection extends StatefulWidget {
  const CareV2BankSelection({required this.selectedCode, super.key});
  final String selectedCode;

  @override
  State<CareV2BankSelection> createState() => _CareV2BankSelectionState();
}

class _CareV2BankSelectionState extends State<CareV2BankSelection> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matches = carePreviewBanks
        .where(
          (bank) => bank.name.toLowerCase().contains(
            _search.text.trim().toLowerCase(),
          ),
        )
        .toList();
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
          children: [
            CareV2Back(
              asset: 'bank-16de2.svg',
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 6),
            Text(
              'Select Bank',
              style: careText(26, FontWeight.w700, CareV2.teal),
            ),
            const SizedBox(height: 2),
            Text(
              "Choose the provider's bank.",
              style: careText(13, FontWeight.w400, CareV2.muted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              style: careText(13, FontWeight.w400, CareV2.navy),
              decoration: InputDecoration(
                hintText: 'Search banks',
                hintStyle: careText(
                  13,
                  FontWeight.w400,
                  const Color(0xFF8A93A3),
                ),
                filled: true,
                fillColor: CareV2.soft,
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(13),
                  child: SvgPicture.asset(
                    '${CareV2.assets}bank-21be9.svg',
                    width: 18,
                    height: 18,
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 8),
            for (final bank in matches)
              InkWell(
                onTap: () => Navigator.pop(context, bank),
                child: Container(
                  height: 56,
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: CareV2.outline)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: bank.background,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          bank.initials,
                          style: careText(12, FontWeight.w700, bank.foreground),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          bank.name,
                          style: careText(14, FontWeight.w400, CareV2.navy),
                        ),
                      ),
                      if (widget.selectedCode == bank.code)
                        SvgPicture.asset(
                          '${CareV2.assets}bank-ae37d.svg',
                          width: 22,
                          height: 22,
                        ),
                    ],
                  ),
                ),
              ),
            if (matches.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No banks found',
                  textAlign: TextAlign.center,
                  style: careText(13, FontWeight.w400, CareV2.muted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
