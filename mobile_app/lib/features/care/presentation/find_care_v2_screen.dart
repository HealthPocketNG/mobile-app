import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:healthpocket/core/widgets/app_bottom_navigation.dart';
import 'package:healthpocket/core/widgets/healthpocket_state_view.dart';
import 'package:healthpocket/features/care/data/demo_care_directory_repository.dart';
import 'package:healthpocket/features/care/domain/care_provider.dart';
import 'package:healthpocket/features/care/presentation/care_v2_common.dart';
import 'package:healthpocket/features/care/presentation/care_v2_payment_flow.dart';
import 'package:healthpocket/features/care/presentation/care_v2_partner_sheet.dart';
import 'package:healthpocket/features/care/presentation/non_partner_payment_screen.dart';
import 'package:healthpocket/features/savings/application/savings_store.dart';
import 'package:url_launcher/url_launcher.dart';

enum DemoLocationStatus { notRequested, granted, denied, unavailable }

enum _CareFilter { all, partners, pharmacies, clinics, hospitals, other }

class FindCareScreen extends StatefulWidget {
  const FindCareScreen({
    super.key,
    this.repository = const DemoCareDirectoryRepository(),
    this.demoRequestsEnabled = false,
    this.savingsStore,
  });
  final CareDirectoryRepository repository;
  final bool demoRequestsEnabled;
  final SavingsStore? savingsStore;

  @override
  State<FindCareScreen> createState() => _FindCareScreenState();
}

class _FindCareScreenState extends State<FindCareScreen> {
  final _search = TextEditingController();
  List<CareProvider> _providers = [];
  _CareFilter _filter = _CareFilter.all;
  DemoLocationStatus _locationStatus = DemoLocationStatus.notRequested;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final providers = await widget.repository.getProviders();
      if (mounted) setState(() => _providers = providers);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _clearFilters() => setState(() {
    _search.clear();
    _filter = _CareFilter.all;
  });

  void _open(CareProvider provider) => Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => _CareProviderDetailsV2(
        provider: provider,
        savingsStore: widget.savingsStore,
      ),
    ),
  );

  void _showLocationOptions() => showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Location', style: careText(20, FontWeight.w700, CareV2.navy)),
            for (final choice in <(String, DemoLocationStatus)>[
              ('Use mock location', DemoLocationStatus.granted),
              ('Simulate denied', DemoLocationStatus.denied),
              ('Simulate unavailable', DemoLocationStatus.unavailable),
              ('Reset location', DemoLocationStatus.notRequested),
            ])
              ListTile(
                title: Text(choice.$1),
                onTap: () {
                  setState(() => _locationStatus = choice.$2);
                  Navigator.pop(sheetContext);
                },
              ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final queried = filterCareProviders(_providers, query: _search.text);
    final filtered = queried
        .where(
          (provider) => switch (_filter) {
            _CareFilter.all => true,
            _CareFilter.partners => provider.isPartner,
            _CareFilter.pharmacies =>
              provider.type == CareProviderType.pharmacy,
            _CareFilter.clinics => provider.type == CareProviderType.clinic,
            _CareFilter.hospitals => provider.type == CareProviderType.hospital,
            _CareFilter.other => !provider.isPartner,
          },
        )
        .toList();
    if (_locationStatus == DemoLocationStatus.granted) {
      filtered.sort(
        (a, b) => a.displayDistanceKm.compareTo(b.displayDistanceKm),
      );
    }
    final partners = filtered.where((provider) => provider.isPartner).toList();
    final other = filtered.where((provider) => !provider.isPartner).toList();
    final firstLocation = _providers.where((item) => item.active).firstOrNull;
    final locationLabel = firstLocation == null
        ? 'Explore nearby care'
        : '${firstLocation.state}, Nigeria';

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.1,
      child: Scaffold(
        backgroundColor: Colors.white,
        bottomNavigationBar: const AppBottomNavigation(
          currentIndex: 2,
          assetRootOverride: CareV2.assets,
          iconFiles: [
            'find-197ef.svg',
            'find-23576.svg',
            'find-da4ca.svg',
            'find-8450b.svg',
            'find-1cb7b.svg',
          ],
          useAssetColorsOverride: false,
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Find Care',
                            style: careText(26, FontWeight.w700, CareV2.teal),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Healthcare, near you.',
                            style: careText(13, FontWeight.w400, CareV2.muted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Notifications',
                      onPressed: () =>
                          Navigator.pushNamed(context, '/notifications'),
                      icon: SvgPicture.asset(
                        '${CareV2.assets}find-cc5dd.svg',
                        width: 26,
                        height: 26,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => Navigator.pushNamed(context, '/profile'),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: Color(0xFFB5EDE5),
                          shape: BoxShape.circle,
                        ),
                        child: SvgPicture.asset(
                          '${CareV2.assets}find-ff6bb.svg',
                          width: 22,
                          height: 22,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: CareV2.mint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      SvgPicture.asset(
                        '${CareV2.assets}find-663bf.svg',
                        width: 13,
                        height: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          locationLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: careText(14, FontWeight.w500, CareV2.navy),
                        ),
                      ),
                      TextButton(
                        onPressed: _showLocationOptions,
                        child: Text(
                          'Change',
                          style: careText(13, FontWeight.w500, CareV2.teal),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_locationStatus != DemoLocationStatus.notRequested) ...[
                  const SizedBox(height: 5),
                  Text(switch (_locationStatus) {
                    DemoLocationStatus.granted =>
                      'Demo location enabled. Distances are illustrative.',
                    DemoLocationStatus.denied =>
                      'Location permission denied. Browse providers manually.',
                    DemoLocationStatus.unavailable =>
                      'Location is unavailable. Browse providers manually.',
                    DemoLocationStatus.notRequested => '',
                  }, style: careText(11, FontWeight.w400, CareV2.muted)),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  height: 44,
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    style: careText(13, FontWeight.w400, CareV2.navy),
                    decoration: InputDecoration(
                      hintText: 'Search for clinics, pharmacies...',
                      hintStyle: careText(
                        13,
                        FontWeight.w400,
                        const Color(0xFF8A93A3),
                      ),
                      filled: true,
                      fillColor: CareV2.soft,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.all(13),
                        child: SvgPicture.asset(
                          '${CareV2.assets}find-4e7cf.svg',
                          width: 15.81,
                          height: 18,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 32,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final option in <(_CareFilter, String)>[
                        (_CareFilter.all, 'All'),
                        (_CareFilter.partners, 'Partners'),
                        (_CareFilter.pharmacies, 'Pharmacies'),
                        (_CareFilter.clinics, 'Clinics'),
                        (_CareFilter.hospitals, 'Hospitals'),
                      ]) ...[
                        _CareFilterChip(
                          label: option.$2,
                          selected: _filter == option.$1,
                          onTap: () => setState(() => _filter = option.$1),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (_loading)
                  const HealthPocketStateView(
                    kind: HealthPocketStateKind.loading,
                    title: 'Loading...',
                    message: 'Finding quality care near you.',
                  )
                else if (_failed)
                  HealthPocketStateView(
                    kind: HealthPocketStateKind.error,
                    title: 'Something went wrong',
                    message: 'Could not load the directory. Please try again.',
                    primaryActionLabel: 'Retry',
                    onPrimaryAction: _load,
                    compact: true,
                  )
                else if (filtered.isEmpty)
                  HealthPocketStateView(
                    kind: HealthPocketStateKind.noResults,
                    title: _providers.isEmpty
                        ? 'No partners nearby'
                        : 'No providers found',
                    message: _providers.isEmpty
                        ? 'No active healthcare providers are available in this area right now.'
                        : 'No providers match your search. Try another filter.',
                    primaryActionLabel: _providers.isEmpty
                        ? 'Try a different location'
                        : 'Clear filters',
                    onPrimaryAction: _providers.isEmpty
                        ? _showLocationOptions
                        : _clearFilters,
                    secondaryActionLabel: _providers.isEmpty
                        ? 'View all partners'
                        : null,
                    onSecondaryAction: _providers.isEmpty
                        ? _clearFilters
                        : null,
                    compact: true,
                  )
                else ...[
                  if (partners.isNotEmpty) ...[
                    _CareSectionHeading(
                      title: 'HealthPocket Partners',
                      onInfo: () => showCareV2PartnerSheet(context),
                      onSeeAll: () =>
                          setState(() => _filter = _CareFilter.partners),
                    ),
                    const SizedBox(height: 4),
                    for (var index = 0; index < partners.length; index++)
                      _CareProviderTileV2(
                        provider: partners[index],
                        badgeAsset: index == 0
                            ? 'find-a9c44.svg'
                            : 'find-a2092.svg',
                        onTap: () => _open(partners[index]),
                      ),
                  ],
                  if (other.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    _CareSectionHeading(
                      title: 'Other Healthcare Providers',
                      onSeeAll: () =>
                          setState(() => _filter = _CareFilter.other),
                    ),
                    const SizedBox(height: 4),
                    for (final provider in other)
                      _CareProviderTileV2(
                        provider: provider,
                        badgeAsset: 'find-a9c44.svg',
                        onTap: () => _open(provider),
                      ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CareFilterChip extends StatelessWidget {
  const _CareFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      height: 32,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: selected ? CareV2.teal : CareV2.soft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: careText(
          12,
          selected ? FontWeight.w600 : FontWeight.w400,
          selected ? Colors.white : CareV2.navy,
        ),
      ),
    ),
  );
}

class _CareSectionHeading extends StatelessWidget {
  const _CareSectionHeading({
    required this.title,
    required this.onSeeAll,
    this.onInfo,
  });
  final String title;
  final VoidCallback onSeeAll;
  final VoidCallback? onInfo;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: careText(15, FontWeight.w700, CareV2.navy)),
      ),
      if (onInfo != null)
        IconButton(
          tooltip: 'What is a HealthPocket Partner?',
          onPressed: onInfo,
          visualDensity: VisualDensity.compact,
          icon: const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: CareV2.teal,
          ),
        ),
      TextButton(
        onPressed: onSeeAll,
        child: Text(
          'See all',
          style: careText(12, FontWeight.w400, CareV2.muted),
        ),
      ),
    ],
  );
}

class _CareProviderTileV2 extends StatelessWidget {
  const _CareProviderTileV2({
    required this.provider,
    required this.badgeAsset,
    required this.onTap,
  });
  final CareProvider provider;
  final String badgeAsset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(minHeight: 86),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: CareV2.outline)),
      ),
      child: Row(
        children: [
          CareProviderAvatarV2(provider: provider),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: careText(14, FontWeight.w600, CareV2.navy),
                ),
                const SizedBox(height: 2),
                Text(
                  '${careType(provider.type)}${provider.displayDistanceKm > 0 ? ' · ${provider.displayDistanceKm.toStringAsFixed(1)} km' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: careText(12, FontWeight.w400, CareV2.muted),
                ),
                const SizedBox(height: 3),
                CarePartnerBadgeV2(
                  provider: provider,
                  iconAsset: badgeAsset,
                  short: true,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SvgPicture.asset(
            '${CareV2.assets}find-48cd9.svg',
            width: 16,
            height: 16,
          ),
        ],
      ),
    ),
  );
}

class _CareProviderDetailsV2 extends StatelessWidget {
  const _CareProviderDetailsV2({
    required this.provider,
    required this.savingsStore,
  });
  final CareProvider provider;
  final SavingsStore? savingsStore;

  void _pay(BuildContext context) {
    if (!provider.active) return;
    if (provider.isPartner && provider.isDemo) {
      Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => CareV2PaymentFlow(
            provider: provider,
            savingsStore: savingsStore,
          ),
        ),
      );
    } else if (!provider.isPartner) {
      Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => NonPartnerPaymentScreen(
            provider: provider,
            savingsStore: savingsStore,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Partner payments are not available in this build yet.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => MediaQuery.withClampedTextScaling(
    maxScaleFactor: 1.1,
    child: Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            SizedBox(
              height: 200,
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFCBE8EE), Color(0xFFE6F3F1)],
                      ),
                    ),
                  ),
                  Center(
                    child: Transform.rotate(
                      angle: -4 * math.pi / 180,
                      child: Container(
                        width: math.min(
                          MediaQuery.sizeOf(context).width - 80,
                          250,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: CareV2.teal,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              provider.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: careText(
                                20,
                                FontWeight.w700,
                                Colors.white,
                              ),
                            ),
                            Text(
                              careType(provider.type).toUpperCase(),
                              style: careText(
                                14,
                                FontWeight.w500,
                                Colors.white,
                              ).copyWith(letterSpacing: 3),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    top: 20,
                    child: Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: 'Back',
                        onPressed: () => Navigator.pop(context),
                        icon: SvgPicture.asset(
                          '${CareV2.assets}detail-b0774.svg',
                          width: 18,
                          height: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -28),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CareProviderSummaryV2(
                      provider: provider,
                      badgeAsset: 'detail-c11d5.svg',
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${careType(provider.type)} · ${provider.city}, ${provider.state}',
                      style: careText(12, FontWeight.w400, CareV2.muted),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${provider.isOpen && provider.active ? 'Open' : 'Closed'}${provider.closingTime == null ? '' : ' · Closes ${provider.closingTime}'}',
                      style: careText(
                        12,
                        FontWeight.w600,
                        provider.isOpen && provider.active
                            ? const Color(0xFF2FA866)
                            : const Color(0xFFE8405F),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _CareQuickAction(
                            label: 'Call',
                            asset: 'detail-bed23.svg',
                            onTap: provider.effectivePhone == null
                                ? null
                                : () => launchUrl(
                                    Uri(
                                      scheme: 'tel',
                                      path: provider.effectivePhone,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _CareQuickAction(
                            label: 'Directions',
                            asset: 'detail-b79f3.svg',
                            onTap: provider.directionsUri == null
                                ? null
                                : () => launchUrl(
                                    provider.directionsUri!,
                                    mode: LaunchMode.externalApplication,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _CareQuickAction(
                            label: 'Save',
                            asset: 'detail-00fe3.svg',
                            onTap: () => ScaffoldMessenger.of(context)
                                .showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Saved providers are not available in this build yet.',
                                    ),
                                  ),
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'About',
                      style: careText(14, FontWeight.w700, CareV2.navy),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      provider.description ??
                          'Care services from this directory provider.',
                      style: careText(
                        12.5,
                        FontWeight.w400,
                        CareV2.muted,
                      ).copyWith(height: 1.5),
                    ),
                    if (provider.isDemo) ...[
                      const SizedBox(height: 8),
                      Text(
                        'No booking, payment, or real care authorization is available in this beta directory.',
                        style: careText(11, FontWeight.w400, CareV2.muted),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Text(
                      'Services',
                      style: careText(14, FontWeight.w700, CareV2.navy),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final service in provider.services)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: CareV2.soft,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              service,
                              style: careText(
                                11.5,
                                FontWeight.w400,
                                CareV2.muted,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        SvgPicture.asset(
                          '${CareV2.assets}detail-bc031.svg',
                          width: 20,
                          height: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            provider.address ??
                                '${provider.city}, ${provider.state}',
                            style: careText(12.5, FontWeight.w400, CareV2.navy),
                          ),
                        ),
                        const SizedBox(width: 10),
                        InkWell(
                          onTap: provider.directionsUri == null
                              ? null
                              : () => launchUrl(
                                  provider.directionsUri!,
                                  mode: LaunchMode.externalApplication,
                                ),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 96,
                            height: 52,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE6ECEF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SvgPicture.asset(
                                  '${CareV2.assets}detail-b049d.svg',
                                  width: 16,
                                  height: 16,
                                ),
                                Text(
                                  'View on map',
                                  style: careText(
                                    9.5,
                                    FontWeight.w400,
                                    CareV2.muted,
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
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: CareV2Button(
            label: 'Pay ${provider.name}',
            arrowAsset: 'detail-ed152.svg',
            onPressed: provider.active ? () => _pay(context) : null,
          ),
        ),
      ),
    ),
  );
}

class _CareQuickAction extends StatelessWidget {
  const _CareQuickAction({
    required this.label,
    required this.asset,
    this.onTap,
  });
  final String label;
  final String asset;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      height: 56,
      decoration: BoxDecoration(
        color: CareV2.mint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset('${CareV2.assets}$asset', width: 20, height: 20),
          const SizedBox(height: 4),
          Text(label, style: careText(11, FontWeight.w400, CareV2.teal)),
        ],
      ),
    ),
  );
}
