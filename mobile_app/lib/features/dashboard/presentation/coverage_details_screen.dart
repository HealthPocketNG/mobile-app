import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:healthpocket/app/app_router.dart';
import 'package:healthpocket/core/theme/app_ui_density.dart';
import 'package:healthpocket/features/dashboard/domain/coverage_guide.dart';
import 'package:healthpocket/features/dashboard/presentation/price_estimate_sheet.dart';

abstract final class CoverV2 {
  static const navy = Color(0xFF0F1B4C);
  static const muted = Color(0xFF5B6477);
  static const teal = Color(0xFF0B7F7A);
  static const mint = Color(0xFFEEF9F7);
  static const line = Color(0xFFE8EDF0);
  static const grey = Color(0xFFF0F3F5);
  static const green = Color(0xFF1E8E4E);
  static const amber = Color(0xFF9A6200);
  static const assets = 'assets/dashboard/v2/coverage/';
}

TextStyle coverText(double size, FontWeight weight, Color color) => TextStyle(
  fontFamily: 'Inter',
  fontSize: AppUiDensity.font(size),
  fontWeight: weight,
  color: color,
);

String coverMoney(int amount, {bool spaced = false}) =>
    '₦${spaced ? ' ' : ''}${amount.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',')}';

class CoverageDetailsScreen extends StatefulWidget {
  const CoverageDetailsScreen({
    required this.balanceKobo,
    this.designPreview = false,
    super.key,
  });
  final int balanceKobo;
  final bool designPreview;
  @override
  State<CoverageDetailsScreen> createState() => _CoverageDetailsScreenState();
}

class _CoverageDetailsScreenState extends State<CoverageDetailsScreen> {
  CoverageCategory? category;

  @override
  Widget build(BuildContext context) {
    final balance = widget.balanceKobo ~/ 100;
    final visible = coverageCatalog
        .where((item) => category == null || item.category == category)
        .toList();
    final covered = visible
        .where((item) => item.referenceCost <= balance)
        .toList();
    final saving = visible
        .where((item) => item.referenceCost > balance)
        .toList();
    final totalCovered = coverageCatalog
        .where((item) => item.referenceCost <= balance)
        .length;
    return CoverScaffold(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        children: [
          const CoverBack(),
          const SizedBox(height: 17),
          Text(
            'What can my balance cover?',
            style: coverText(24, FontWeight.w700, CoverV2.teal),
          ),
          const SizedBox(height: 2),
          Text(
            'See how far your balance can go on everyday\nhealthcare.',
            style: coverText(13, FontWeight.w400, CoverV2.muted),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => showPriceEstimateSheet(context),
            child: Container(
              height: 86,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  colors: [Color(0xFF0A7F7B), Color(0xFF0E9A93)],
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your balance',
                          style: coverText(12.5, FontWeight.w400, Colors.white),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            coverMoney(balance, spaced: true),
                            style: coverText(26, FontWeight.w700, Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x2EFFFFFF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'Covers $totalCovered of ${coverageCatalog.length}',
                      style: coverText(12, FontWeight.w400, Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: CoverageCategory.values.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final value = index == 0
                    ? null
                    : CoverageCategory.values[index - 1];
                final selected = value == category;
                final label = value == null
                    ? 'All'
                    : switch (value) {
                        CoverageCategory.medicines => 'Medicines',
                        CoverageCategory.tests => 'Tests',
                        CoverageCategory.visits => 'Visits',
                        CoverageCategory.dental => 'Dental',
                        CoverageCategory.eyes => 'Eyes',
                      };
                return InkWell(
                  onTap: () => setState(() => category = value),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: selected ? CoverV2.teal : CoverV2.grey,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      label,
                      style: coverText(
                        12,
                        selected ? FontWeight.w600 : FontWeight.w400,
                        selected ? Colors.white : CoverV2.navy,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (covered.isNotEmpty) ...[
            const SizedBox(height: 18),
            CoverSection(
              'Covered by your balance',
              '${covered.length} ${covered.length == 1 ? 'item' : 'items'}',
            ),
            for (final item in covered)
              CoverageRow(
                item: item,
                balance: balance,
                onTap: () => openItem(item),
              ),
          ],
          if (saving.isNotEmpty) ...[
            const SizedBox(height: 18),
            const CoverSection('Almost there', 'Save a little more'),
            for (final item in saving)
              CoverageRow(
                item: item,
                balance: balance,
                onTap: () => openItem(item),
              ),
          ],
        ],
      ),
    );
  }

  void openItem(CoverageGuide item) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => CoverageItemScreen(
        guide: item,
        balanceKobo: widget.balanceKobo,
        designPreview: widget.designPreview,
      ),
    ),
  );
}

class CoverageItemScreen extends StatelessWidget {
  const CoverageItemScreen({
    required this.guide,
    required this.balanceKobo,
    this.designPreview = false,
    super.key,
  });
  final CoverageGuide guide;
  final int balanceKobo;
  final bool designPreview;

  @override
  Widget build(BuildContext context) {
    final balance = balanceKobo ~/ 100;
    final covered = balance >= guide.referenceCost;
    final remaining = guide.referenceCost - balance;
    void goSavings() => Navigator.pushNamed(context, AppRoute.savings.path);
    return CoverScaffold(
      bottom: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () => Navigator.pushNamed(
                  context,
                  covered ? AppRoute.findCare.path : AppRoute.savings.path,
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: CoverV2.teal,
                  shape: const StadiumBorder(),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      covered ? 'Find Care' : 'Add Money',
                      style: coverText(15, FontWeight.w600, Colors.white),
                    ),
                    const SizedBox(width: 10),
                    SvgPicture.asset('${CoverV2.assets}find-care.svg'),
                  ],
                ),
              ),
            ),
            if (!covered) ...[
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: TextButton(
                  onPressed: goSavings,
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFE4F6F3),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    'Set a Savings Plan',
                    style: coverText(15, FontWeight.w600, CoverV2.teal),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        children: [
          const CoverBack(),
          const SizedBox(height: 16),
          Row(
            children: [
              CoverIcon(item: guide, size: 72),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        guide.title,
                        style: coverText(22, FontWeight.w700, CoverV2.navy),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      guide.subtitle,
                      maxLines: 2,
                      style: coverText(13, FontWeight.w400, CoverV2.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: covered ? 20 : 10),
          CoverCostCard(guide: guide, balance: balance),
          if (covered) ...[
            if (guide.includedServices.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                "What's usually included",
                style: coverText(14, FontWeight.w700, CoverV2.navy),
              ),
              const SizedBox(height: 4),
              for (final service in guide.includedServices)
                SizedBox(
                  height: 30,
                  child: Row(
                    children: [
                      SvgPicture.asset('${CoverV2.assets}included-check.svg'),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          service,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: coverText(13.5, FontWeight.w400, CoverV2.navy),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
            ] else
              const SizedBox(height: 20),
            Text(
              'Where you can get it',
              style: coverText(14, FontWeight.w700, CoverV2.navy),
            ),
            if (designPreview && guide.title == 'Malaria treatment') ...[
              const CoverProvider(
                'LC',
                'Lagoon Clinic',
                'Clinic · 0.8 km',
                '4.8 (124)',
              ),
              const CoverProvider(
                'HP',
                'HealthPlus Pharmacy',
                'Pharmacy · 1.2 km',
                '4.6 (89)',
              ),
            ] else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Find available care near you.',
                  style: coverText(12, FontWeight.w400, CoverV2.muted),
                ),
              ),
            const SizedBox(height: 16),
          ] else ...[
            const SizedBox(height: 20),
            Text(
              'Ways to get there',
              style: coverText(14, FontWeight.w700, CoverV2.navy),
            ),
            const SizedBox(height: 10),
            CoverSavingOption(
              'add-money.svg',
              'Add money',
              'Top up your balance now',
              goSavings,
            ),
            const SizedBox(height: 10),
            CoverSavingOption(
              'save-weekly.svg',
              'Save weekly',
              "At ₦500 a week, you'd get there in about\n${(remaining / 500).ceil()} weeks",
              goSavings,
            ),
            const SizedBox(height: 10),
          ],
          const CoverPriceNotice(),
        ],
      ),
    );
  }
}

class CoverScaffold extends StatelessWidget {
  const CoverScaffold({required this.child, this.bottom, super.key});
  final Widget child;
  final Widget? bottom;
  @override
  Widget build(BuildContext context) => MediaQuery.withClampedTextScaling(
    maxScaleFactor: 1.1,
    child: Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(bottom: false, child: child),
      bottomNavigationBar: bottom == null
          ? null
          : SafeArea(top: false, child: bottom!),
    ),
  );
}

class CoverBack extends StatelessWidget {
  const CoverBack({super.key});
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: InkWell(
      onTap: () => Navigator.of(context).pop(),
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        width: 20,
        height: 20,
        child: SvgPicture.asset('${CoverV2.assets}back.svg'),
      ),
    ),
  );
}

class CoverSection extends StatelessWidget {
  const CoverSection(this.title, this.trailing, {super.key});
  final String title;
  final String trailing;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: coverText(15, FontWeight.w700, CoverV2.navy)),
      ),
      Text(trailing, style: coverText(12, FontWeight.w400, CoverV2.muted)),
    ],
  );
}

class CoverageRow extends StatelessWidget {
  const CoverageRow({
    required this.item,
    required this.balance,
    required this.onTap,
    super.key,
  });
  final CoverageGuide item;
  final int balance;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final covered = balance >= item.referenceCost;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 70),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: CoverV2.line)),
        ),
        child: Row(
          children: [
            CoverIcon(item: item, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: coverText(14.5, FontWeight.w600, CoverV2.navy),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: coverText(12, FontWeight.w400, CoverV2.muted),
                  ),
                  if (!covered) ...[
                    const SizedBox(height: 7),
                    CoverProgress(balance / item.referenceCost),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 82,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    coverMoney(item.referenceCost),
                    maxLines: 1,
                    style: coverText(14.5, FontWeight.w700, CoverV2.navy),
                  ),
                  const SizedBox(height: 3),
                  if (covered)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SvgPicture.asset('${CoverV2.assets}covered.svg'),
                          const SizedBox(width: 4),
                          Text(
                            'Covered',
                            style: coverText(
                              11,
                              FontWeight.w400,
                              CoverV2.green,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Text(
                      '${coverMoney(item.referenceCost - balance)} more',
                      maxLines: 1,
                      style: coverText(11, FontWeight.w500, CoverV2.amber),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CoverIcon extends StatelessWidget {
  const CoverIcon({required this.item, required this.size, super.key});
  final CoverageGuide item;
  final double size;
  @override
  Widget build(BuildContext context) {
    final large = size > 50;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: CoverV2.mint,
        borderRadius: BorderRadius.circular(large ? 20 : 14),
      ),
      child: item.category == CoverageCategory.eyes
          ? CoverGlasses(size: large ? 44 : 30)
          : SvgPicture.asset(
              large ? (item.detailAsset ?? item.asset) : item.asset,
              width: large ? 44 : 30,
              height: large ? 44 : 30,
            ),
    );
  }
}

class CoverGlasses extends StatelessWidget {
  const CoverGlasses({required this.size, super.key});
  final double size;
  @override
  Widget build(BuildContext context) {
    final prefix = size == 44 ? 'glasses-large-' : 'glasses-';
    final ratio = size / 30;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          for (final name in ['path-01', 'path-02'])
            Positioned(
              left: 0.984 * ratio,
              top: 10.317 * ratio,
              child: SvgPicture.asset('${CoverV2.assets}$prefix$name.svg'),
            ),
          Positioned(
            left: 3.5 * ratio,
            top: 11.4 * ratio,
            child: SvgPicture.asset('${CoverV2.assets}${prefix}path-03.svg'),
          ),
          Positioned(
            left: 17.667 * ratio,
            top: 11.4 * ratio,
            child: SvgPicture.asset('${CoverV2.assets}${prefix}path-06.svg'),
          ),
        ],
      ),
    );
  }
}

class CoverProgress extends StatelessWidget {
  const CoverProgress(this.value, {super.key});
  final double value;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(3),
    child: LinearProgressIndicator(
      value: value.clamp(0.0, 1.0),
      minHeight: 6,
      backgroundColor: CoverV2.grey,
      valueColor: const AlwaysStoppedAnimation(Color(0xFF13A39B)),
    ),
  );
}

class CoverCostCard extends StatelessWidget {
  const CoverCostCard({required this.guide, required this.balance, super.key});
  final CoverageGuide guide;
  final int balance;
  @override
  Widget build(BuildContext context) {
    final covered = balance >= guide.referenceCost;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CoverV2.mint,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Estimated cost',
            style: coverText(12.5, FontWeight.w400, CoverV2.muted),
          ),
          const SizedBox(height: 2),
          Text(
            coverMoney(guide.referenceCost, spaced: true),
            style: coverText(30, FontWeight.w700, CoverV2.teal),
          ),
          SizedBox(height: covered ? 4 : 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: covered
                  ? const Color(0xFFE3F6EA)
                  : const Color(0xFFFFEBC8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              covered
                  ? 'Covered by your balance'
                  : '${coverMoney(guide.referenceCost - balance)} to go',
              style: coverText(
                11.5,
                FontWeight.w500,
                covered ? CoverV2.green : CoverV2.amber,
              ),
            ),
          ),
          SizedBox(height: covered ? 2 : 10),
          if (!covered) ...[
            CoverProgress(balance / guide.referenceCost),
            const SizedBox(height: 6),
          ],
          Text(
            covered
                ? 'Your ${coverMoney(balance)} covers this ${balance ~/ guide.referenceCost} times.'
                : '${coverMoney(balance)} of ${coverMoney(guide.referenceCost)} saved',
            style: coverText(12.5, FontWeight.w400, CoverV2.muted),
          ),
        ],
      ),
    );
  }
}

class CoverProvider extends StatelessWidget {
  const CoverProvider(
    this.initials,
    this.name,
    this.metadata,
    this.rating, {
    super.key,
  });
  final String initials;
  final String name;
  final String metadata;
  final String rating;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => Navigator.pushNamed(context, AppRoute.findCare.path),
    child: Container(
      height: 78,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: CoverV2.line)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: initials == 'LC'
                ? const Color(0xFFCDEFEA)
                : const Color(0xFFD9E8FF),
            child: Text(
              initials,
              style: coverText(
                13,
                FontWeight.w700,
                initials == 'LC' ? CoverV2.teal : const Color(0xFF2B5BD7),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: coverText(14, FontWeight.w600, CoverV2.navy),
                ),
                const SizedBox(height: 2),
                Text(
                  metadata,
                  style: coverText(12, FontWeight.w400, CoverV2.muted),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '★',
                        style: coverText(
                          12,
                          FontWeight.w400,
                          const Color(0xFFC98A12),
                        ),
                      ),
                      Text(
                        rating,
                        style: coverText(11.5, FontWeight.w400, CoverV2.muted),
                      ),
                      const SizedBox(width: 8),
                      SvgPicture.asset('${CoverV2.assets}partner.svg'),
                      const SizedBox(width: 4),
                      Text(
                        'HP Partner',
                        style: coverText(10.5, FontWeight.w400, CoverV2.teal),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SvgPicture.asset('${CoverV2.assets}chevron.svg'),
        ],
      ),
    ),
  );
}

class CoverSavingOption extends StatelessWidget {
  const CoverSavingOption(
    this.icon,
    this.title,
    this.description,
    this.onTap, {
    super.key,
  });
  final String icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: CoverV2.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFE4F6F3),
              shape: BoxShape.circle,
            ),
            child: SvgPicture.asset('${CoverV2.assets}$icon'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: coverText(14, FontWeight.w600, CoverV2.navy),
                ),
                Text(
                  description,
                  style: coverText(12, FontWeight.w400, CoverV2.muted),
                ),
              ],
            ),
          ),
          SvgPicture.asset('${CoverV2.assets}chevron.svg'),
        ],
      ),
    ),
  );
}

class CoverPriceNotice extends StatelessWidget {
  const CoverPriceNotice({super.key});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => showPriceEstimateSheet(context),
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: CoverV2.grey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SvgPicture.asset('${CoverV2.assets}price-info.svg'),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Prices are estimates based on partner rates. The final cost depends on the provider.',
              style: coverText(
                11.5,
                FontWeight.w400,
                CoverV2.muted,
              ).copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    ),
  );
}
