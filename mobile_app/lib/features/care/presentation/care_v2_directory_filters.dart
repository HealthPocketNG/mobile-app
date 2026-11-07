import 'package:flutter/material.dart';
import 'package:healthpocket/features/care/domain/care_provider.dart';
import 'package:healthpocket/features/care/presentation/care_v2_common.dart';

class CareDirectoryFilters {
  const CareDirectoryFilters({
    this.types = const {},
    this.maxDistanceKm,
    this.minRating,
    this.openNow = false,
    this.partnersOnly = false,
  });
  final Set<CareProviderType> types;
  final double? maxDistanceKm;
  final double? minRating;
  final bool openNow;
  final bool partnersOnly;

  bool matches(CareProvider provider) =>
      (types.isEmpty || types.contains(provider.type)) &&
      (maxDistanceKm == null ||
          (provider.displayDistanceKm > 0 &&
              provider.displayDistanceKm <= maxDistanceKm!)) &&
      (minRating == null ||
          (provider.rating != null && provider.rating! >= minRating!)) &&
      (!openNow || provider.isOpen) &&
      (!partnersOnly || provider.isPartner);
}

Future<CareDirectoryFilters?> showCareV2Filters(
  BuildContext context,
  CareDirectoryFilters current,
) => showModalBottomSheet<CareDirectoryFilters>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.white,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  builder: (_) => _CareFiltersSheet(current: current),
);

class _CareFiltersSheet extends StatefulWidget {
  const _CareFiltersSheet({required this.current});
  final CareDirectoryFilters current;

  @override
  State<_CareFiltersSheet> createState() => _CareFiltersSheetState();
}

class _CareFiltersSheetState extends State<_CareFiltersSheet> {
  late Set<CareProviderType> _types = {...widget.current.types};
  late double _distance = widget.current.maxDistanceKm ?? 5;
  late double? _rating = widget.current.minRating;
  late bool _openNow = widget.current.openNow;
  late bool _partnersOnly = widget.current.partnersOnly;
  bool _distanceEnabled = true;

  void _reset() => setState(() {
    _types = {};
    _distance = 5;
    _distanceEnabled = false;
    _rating = null;
    _openNow = false;
    _partnersOnly = false;
  });

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD5DBE0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Filters',
                    style: careText(20, FontWeight.w700, CareV2.navy),
                  ),
                ),
                TextButton(
                  onPressed: _reset,
                  child: Text(
                    'Reset',
                    style: careText(13, FontWeight.w500, CareV2.teal),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Provider type',
              style: careText(13, FontWeight.w600, CareV2.navy),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final choice in const <(CareProviderType, String)>[
                  (CareProviderType.hospital, 'Hospitals'),
                  (CareProviderType.clinic, 'Clinics'),
                  (CareProviderType.pharmacy, 'Pharmacies'),
                  (CareProviderType.diagnostics, 'Labs'),
                ])
                  _FilterPill(
                    label: choice.$2,
                    selected: _types.contains(choice.$1),
                    onTap: () => setState(() {
                      if (!_types.add(choice.$1)) _types.remove(choice.$1);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Distance',
                    style: careText(13, FontWeight.w600, CareV2.navy),
                  ),
                ),
                Text(
                  _distanceEnabled
                      ? 'Within ${_distance.round()} km'
                      : 'Any distance',
                  style: careText(12, FontWeight.w400, CareV2.muted),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: CareV2.teal,
                inactiveTrackColor: CareV2.soft,
                thumbColor: CareV2.teal,
                overlayColor: CareV2.mint,
                trackHeight: 5,
              ),
              child: Slider(
                value: _distance,
                min: 1,
                max: 15,
                divisions: 14,
                onChanged: (value) => setState(() {
                  _distance = value;
                  _distanceEnabled = true;
                }),
              ),
            ),
            Text(
              'Minimum rating',
              style: careText(13, FontWeight.w600, CareV2.navy),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _FilterPill(
                  label: 'Any',
                  selected: _rating == null,
                  onTap: () => setState(() => _rating = null),
                ),
                _FilterPill(
                  label: '4.0+',
                  selected: _rating == 4,
                  onTap: () => setState(() => _rating = 4),
                ),
                _FilterPill(
                  label: '4.5+',
                  selected: _rating == 4.5,
                  onTap: () => setState(() => _rating = 4.5),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _FilterSwitch(
              label: 'Open now',
              value: _openNow,
              onChanged: (value) => setState(() => _openNow = value),
            ),
            _FilterSwitch(
              label: 'HealthPocket partners only',
              value: _partnersOnly,
              onChanged: (value) => setState(() => _partnersOnly = value),
            ),
            const SizedBox(height: 12),
            CareV2Button(
              label: 'Show Results',
              onPressed: () => Navigator.pop(
                context,
                CareDirectoryFilters(
                  types: _types,
                  maxDistanceKm: _distanceEnabled ? _distance : null,
                  minRating: _rating,
                  openNow: _openNow,
                  partnersOnly: _partnersOnly,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
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
      height: 30,
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

class _FilterSwitch extends StatelessWidget {
  const _FilterSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 42,
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: careText(14, FontWeight.w400, CareV2.navy)),
        ),
        Switch(
          value: value,
          activeTrackColor: CareV2.teal,
          onChanged: onChanged,
        ),
      ],
    ),
  );
}
