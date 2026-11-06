import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:healthpocket/features/care/domain/care_provider.dart';
import 'package:healthpocket/features/care/presentation/care_v2_common.dart';

class CareArea {
  const CareArea(this.name, this.state);
  final String name;
  final String state;
  String get label => '$name, $state';
}

const carePopularAreas = <CareArea>[
  CareArea('Victoria Island', 'Lagos'),
  CareArea('Ikeja', 'Lagos'),
  CareArea('Lekki', 'Lagos'),
  CareArea('Port Harcourt', 'Rivers'),
  CareArea('Abraka', 'Delta'),
  CareArea('Enugu', 'Enugu'),
];

class CareV2LocationPermission extends StatelessWidget {
  const CareV2LocationPermission({
    required this.onManual,
    required this.onAllow,
    super.key,
  });
  final VoidCallback onManual;
  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          children: [
            const Spacer(flex: 2),
            Image.asset(
              '${CareV2.assets}location-c82bf.png',
              width: 186,
              height: 193,
              fit: BoxFit.cover,
            ),
            const SizedBox(height: 16),
            Text(
              'Find care near you',
              textAlign: TextAlign.center,
              style: careText(20, FontWeight.w700, CareV2.navy),
            ),
            const SizedBox(height: 8),
            Text(
              'Allow location access so we can show HealthPocket partners and healthcare providers close to you.',
              textAlign: TextAlign.center,
              style: careText(
                13.5,
                FontWeight.w400,
                CareV2.muted,
              ).copyWith(height: 1.5),
            ),
            const Spacer(flex: 3),
            CareV2Button(label: 'Allow Location', onPressed: onAllow),
            const SizedBox(height: 12),
            _CareSecondaryButton(
              label: 'Enter Location Manually',
              onPressed: onManual,
            ),
          ],
        ),
      ),
    ),
  );
}

class CareV2ChangeLocation extends StatefulWidget {
  const CareV2ChangeLocation({
    required this.current,
    required this.onUseCurrent,
    super.key,
  });
  final CareArea? current;
  final VoidCallback onUseCurrent;

  @override
  State<CareV2ChangeLocation> createState() => _CareV2ChangeLocationState();
}

class _CareV2ChangeLocationState extends State<CareV2ChangeLocation> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matches = carePopularAreas
        .where(
          (area) => area.label.toLowerCase().contains(
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
              asset: 'change-16de2.svg',
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 6),
            Text(
              'Change location',
              style: careText(26, FontWeight.w700, CareV2.teal),
            ),
            const SizedBox(height: 2),
            Text(
              'Find care near the place you choose.',
              style: careText(13, FontWeight.w400, CareV2.muted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search city or area',
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
                    '${CareV2.assets}change-21be9.svg',
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
            const SizedBox(height: 12),
            InkWell(
              onTap: widget.onUseCurrent,
              child: SizedBox(
                height: 48,
                child: Row(
                  children: [
                    SvgPicture.asset(
                      '${CareV2.assets}change-f32ae.svg',
                      width: 22,
                      height: 22,
                    ),
                    const SizedBox(width: 14),
                    Text(
                      'Use my current location',
                      style: careText(14, FontWeight.w600, CareV2.teal),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Popular areas',
              style: careText(13, FontWeight.w700, CareV2.muted),
            ),
            const SizedBox(height: 4),
            for (final area in matches)
              InkWell(
                onTap: () => Navigator.pop(context, area),
                child: Container(
                  height: 58,
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: CareV2.outline)),
                  ),
                  child: Row(
                    children: [
                      SvgPicture.asset(
                        '${CareV2.assets}change-b4211.svg',
                        width: 22,
                        height: 22,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              area.name,
                              style: careText(14, FontWeight.w400, CareV2.navy),
                            ),
                            Text(
                              area.state,
                              style: careText(
                                12,
                                FontWeight.w400,
                                CareV2.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.current?.name == area.name &&
                          widget.current?.state == area.state)
                        SvgPicture.asset(
                          '${CareV2.assets}change-ae37d.svg',
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
                  'No areas found',
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

class CareV2Search extends StatefulWidget {
  const CareV2Search({required this.providers, super.key});
  final List<CareProvider> providers;

  @override
  State<CareV2Search> createState() => _CareV2SearchState();
}

class _CareV2SearchState extends State<CareV2Search> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _query.text.trim();
    final topic = text.isNotEmpty && 'malaria'.startsWith(text.toLowerCase())
        ? 'malaria'
        : text;
    final results = text.isEmpty
        ? <CareProvider>[]
        : filterCareProviders(widget.providers, query: text);
    final suggestions = text.isEmpty
        ? <String>[]
        : <String>['$topic treatment', '$topic test'];
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _query,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    style: careText(13, FontWeight.w400, CareV2.navy),
                    decoration: InputDecoration(
                      hintText: 'Search care',
                      filled: true,
                      fillColor: CareV2.soft,
                      prefixIcon: Padding(
                        padding: const EdgeInsets.all(13),
                        child: SvgPicture.asset(
                          '${CareV2.assets}search-21be9.svg',
                          width: 18,
                          height: 18,
                        ),
                      ),
                      suffixIcon: text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: () => setState(_query.clear),
                              icon: SvgPicture.asset(
                                '${CareV2.assets}search-487a1.svg',
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
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: careText(13, FontWeight.w500, CareV2.teal),
                  ),
                ),
              ],
            ),
            if (text.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Suggestions',
                style: careText(13, FontWeight.w700, CareV2.muted),
              ),
              const SizedBox(height: 4),
              for (final suggestion in suggestions)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: SvgPicture.asset(
                    '${CareV2.assets}search-21be9.svg',
                    width: 18,
                    height: 18,
                  ),
                  title: Text(
                    suggestion,
                    style: careText(13, FontWeight.w600, CareV2.navy),
                  ),
                  onTap: () => setState(() {
                    _query.text = suggestion;
                    _query.selection = TextSelection.collapsed(
                      offset: suggestion.length,
                    );
                  }),
                ),
              const SizedBox(height: 10),
              Text(
                'Providers that offer $topic care',
                style: careText(13, FontWeight.w700, CareV2.muted),
              ),
              const SizedBox(height: 4),
              for (final provider in results)
                InkWell(
                  onTap: () => Navigator.pop(context, provider),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 58),
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
                                style: careText(
                                  14,
                                  FontWeight.w600,
                                  CareV2.navy,
                                ),
                              ),
                              Text(
                                '${careType(provider.type)} · ${provider.displayDistanceKm.toStringAsFixed(1)} km',
                                style: careText(
                                  12,
                                  FontWeight.w400,
                                  CareV2.muted,
                                ),
                              ),
                              if (provider.rating != null)
                                Text(
                                  '★ ${provider.rating!.toStringAsFixed(1)}${provider.ratingCount == null ? '' : ' (${provider.ratingCount})'}',
                                  style: careText(
                                    11.5,
                                    FontWeight.w400,
                                    CareV2.muted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        SvgPicture.asset(
                          '${CareV2.assets}search-48cd9.svg',
                          width: 16,
                          height: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              if (results.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'No providers match this search.',
                    style: careText(13, FontWeight.w400, CareV2.muted),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class CareV2NoResults extends StatelessWidget {
  const CareV2NoResults({
    required this.onChangeLocation,
    required this.onViewAll,
    super.key,
  });
  final VoidCallback onChangeLocation;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(
      minHeight: (MediaQuery.sizeOf(context).height - 360)
          .clamp(320, 700)
          .toDouble(),
    ),
    child: Column(
      children: [
        const SizedBox(height: 24),
        Image.asset(
          '${CareV2.assets}noresults-ddd18.png',
          width: 175,
          height: 176,
        ),
        const SizedBox(height: 18),
        Text(
          'No partners nearby',
          textAlign: TextAlign.center,
          style: careText(20, FontWeight.w700, CareV2.navy),
        ),
        const SizedBox(height: 8),
        Text(
          "We couldn't find any HealthPocket\npartners near your current location.",
          textAlign: TextAlign.center,
          style: careText(
            13.5,
            FontWeight.w400,
            CareV2.muted,
          ).copyWith(height: 1.5),
        ),
        const SizedBox(height: 48),
        CareV2Button(
          label: 'Try a different location',
          onPressed: onChangeLocation,
        ),
        const SizedBox(height: 10),
        _CareSecondaryButton(label: 'View all providers', onPressed: onViewAll),
        const SizedBox(height: 12),
      ],
    ),
  );
}

class _CareSecondaryButton extends StatelessWidget {
  const _CareSecondaryButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 46,
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: CareV2.mint,
        foregroundColor: CareV2.teal,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      ),
      child: Text(label, style: careText(15, FontWeight.w600, CareV2.teal)),
    ),
  );
}
