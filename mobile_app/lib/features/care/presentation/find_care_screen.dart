import 'package:flutter/material.dart';
import 'package:healthpocket/core/theme/app_colors.dart';
import 'package:healthpocket/core/theme/app_spacing.dart';
import 'package:healthpocket/core/widgets/app_bottom_navigation.dart';
import 'package:healthpocket/core/widgets/app_primary_button.dart';
import 'package:healthpocket/features/care/data/demo_care_directory_repository.dart';
import 'package:healthpocket/features/care/domain/care_provider.dart';
import 'package:healthpocket/features/care/presentation/demo_care_journey_screen.dart';
import 'package:healthpocket/features/savings/application/savings_store.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

enum DemoLocationStatus { notRequested, granted, denied, unavailable }

class FindCareScreen extends StatefulWidget {
  const FindCareScreen({super.key, this.repository = const DemoCareDirectoryRepository(), this.demoRequestsEnabled = false, this.savingsStore});
  final CareDirectoryRepository repository;
  final bool demoRequestsEnabled;
  final SavingsStore? savingsStore;
  @override
  State<FindCareScreen> createState() => _FindCareScreenState();
}

class _FindCareScreenState extends State<FindCareScreen> {
  final _search = TextEditingController();
  List<CareProvider> _providers = [];
  CareProviderType? _type;
  bool _loading = true;
  bool _failed = false;
  DemoLocationStatus _locationStatus = DemoLocationStatus.notRequested;
  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _search.dispose(); super.dispose(); }
  Future<void> _load() async {
    setState(() { _loading = true; _failed = false; });
    try {
      final providers = await widget.repository.getProviders();
      if (mounted) setState(() => _providers = providers);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
  void _clearFilters() => setState(() { _search.clear(); _type = null; });
  void _open(CareProvider provider) => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => _ProviderDetails(
    provider: provider, providers: _providers, enabled: widget.demoRequestsEnabled, savingsStore: widget.savingsStore,
  )));
  @override
  Widget build(BuildContext context) {
    final results = filterCareProviders(_providers, query: _search.text, type: _type);
    if (_locationStatus == DemoLocationStatus.granted) results.sort((a, b) => a.mockDistanceKm.compareTo(b.mockDistanceKm));
    final partners = results.where((item) => item.isPartner).toList();
    final other = results.where((item) => !item.isPartner).toList();
    return Scaffold(
      bottomNavigationBar: const AppBottomNavigation(currentIndex: 3),
      body: SafeArea(child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.xl),
          children: [
            Text('Find Care', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: AppSpacing.xs),
            const Text('Partnered care, closer to you.', style: TextStyle(color: AppColors.inkMuted)),
            const SizedBox(height: AppSpacing.md),
            _LocationCard(status: _locationStatus, onChanged: (value) => setState(() => _locationStatus = value)),
            const SizedBox(height: AppSpacing.md),
            TextField(controller: _search, onChanged: (_) => setState(() {}), decoration: const InputDecoration(hintText: 'Search hospitals, clinics or pharmacies...', prefixIcon: Icon(LucideIcons.search))),
            const SizedBox(height: AppSpacing.md),
            _FilterChips(selected: _type, onSelected: (value) => setState(() => _type = value)),
            const SizedBox(height: AppSpacing.lg),
            if (_loading) const Padding(padding: EdgeInsets.all(AppSpacing.xl), child: Center(child: CircularProgressIndicator()))
            else if (_failed) _Feedback(icon: LucideIcons.wifiOff, message: 'Could not load the directory. Please try again.', action: 'Retry', onTap: _load)
            else if (results.isEmpty) _Feedback(icon: LucideIcons.mapPinOff, message: _providers.isEmpty ? 'No demo partner centres are available right now.' : 'No providers match your search. Try another filter.', action: 'Clear filters', onTap: _clearFilters)
            else ...[
              Text(results.length.toString() + ' providers', style: const TextStyle(color: AppColors.inkMuted, fontSize: 12)),
              const SizedBox(height: AppSpacing.sm),
              const _Heading('Nearby HealthPocket Partners'),
              const SizedBox(height: AppSpacing.sm),
              if (partners.isEmpty) const Padding(padding: EdgeInsets.all(AppSpacing.md), child: Text('No HealthPocket partners match this filter.', style: TextStyle(color: AppColors.inkMuted)))
              else ...partners.map((item) => _ProviderTile(provider: item, showDistance: _locationStatus == DemoLocationStatus.granted, onTap: () => _open(item))),
              if (other.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                const _Heading('Other Partners Nearby'),
                const SizedBox(height: AppSpacing.sm),
                ...other.map((item) => _ProviderTile(provider: item, showDistance: _locationStatus == DemoLocationStatus.granted, onTap: () => _open(item))),
              ],
            ],
          ],
        ),
      )),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.status, required this.onChanged});
  final DemoLocationStatus status;
  final ValueChanged<DemoLocationStatus> onChanged;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(14)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(LucideIcons.mapPin, color: AppColors.primary, size: 19),
        const SizedBox(width: AppSpacing.sm),
        const Expanded(child: Text('Abraka, Delta State', style: TextStyle(fontWeight: FontWeight.w700))),
        TextButton(onPressed: () => _options(context), child: const Text('Change')),
      ]),
      if (status == DemoLocationStatus.notRequested)
        TextButton(onPressed: () => onChanged(DemoLocationStatus.granted), child: const Text('Use mock location'))
      else
        Text(_locationMessage(status), style: const TextStyle(color: AppColors.inkMuted, fontSize: 12)),
    ]),
  );
  void _options(BuildContext context) => showModalBottomSheet<void>(context: context, builder: (context) => SafeArea(child: Padding(
    padding: const EdgeInsets.all(AppSpacing.lg),
    child: Wrap(children: [
      const Text('Location', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      ListTile(title: const Text('Use mock location'), onTap: () { onChanged(DemoLocationStatus.granted); Navigator.pop(context); }),
      ListTile(title: const Text('Simulate denied'), onTap: () { onChanged(DemoLocationStatus.denied); Navigator.pop(context); }),
      ListTile(title: const Text('Simulate unavailable'), onTap: () { onChanged(DemoLocationStatus.unavailable); Navigator.pop(context); }),
    ]),
  )));
}
String _locationMessage(DemoLocationStatus status) => switch (status) {
  DemoLocationStatus.granted => 'Demo location enabled · distances use mock coordinates.',
  DemoLocationStatus.denied => 'Location permission denied. Search and filters still work.',
  DemoLocationStatus.unavailable => 'Location is unavailable. Search and filters still work.',
  DemoLocationStatus.notRequested => 'Location has not been requested.',
};

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onSelected});
  final CareProviderType? selected; final ValueChanged<CareProviderType?> onSelected;
  @override
  Widget build(BuildContext context) => SizedBox(height: 38, child: ListView(scrollDirection: Axis.horizontal, children: [
    _Filter(label: 'All', active: selected == null, onTap: () => onSelected(null)),
    _Filter(label: 'Hospitals', active: selected == CareProviderType.hospital, onTap: () => onSelected(CareProviderType.hospital)),
    _Filter(label: 'Clinics', active: selected == CareProviderType.clinic, onTap: () => onSelected(CareProviderType.clinic)),
    _Filter(label: 'Pharmacies', active: selected == CareProviderType.pharmacy, onTap: () => onSelected(CareProviderType.pharmacy)),
    _Filter(label: 'Diagnostics', active: selected == CareProviderType.diagnostics, onTap: () => onSelected(CareProviderType.diagnostics)),
  ]));
}
class _Filter extends StatelessWidget {
  const _Filter({required this.label, required this.active, required this.onTap});
  final String label; final bool active; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(right: AppSpacing.sm), child: Material(
    color: active ? AppColors.primary : AppColors.surfaceMuted, borderRadius: BorderRadius.circular(12),
    child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Center(child: Text(label, style: TextStyle(color: active ? Colors.white : AppColors.ink, fontWeight: FontWeight.w700, fontSize: 13))))),
  ));
}

class _ProviderTile extends StatelessWidget {
  const _ProviderTile({required this.provider, required this.showDistance, required this.onTap});
  final CareProvider provider; final bool showDistance; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: AppSpacing.sm), child: Material(
    color: AppColors.surface, borderRadius: BorderRadius.circular(16),
    child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
      _Logo(provider: provider), const SizedBox(width: 12),
      Expanded(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(provider.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        Text(_typeName(provider.type) + (showDistance ? ' · ' + provider.mockDistanceKm.toStringAsFixed(1) + ' km' : ''), style: const TextStyle(color: AppColors.inkMuted, fontSize: 12)),
        const SizedBox(height: 5),
        Row(children: [_OpenPill(open: provider.isOpen && provider.active), if (provider.isPartner) ...[const SizedBox(width: 6), const _Badge()]]),
      ])),
      const Icon(LucideIcons.chevronRight, size: 19, color: AppColors.inkMuted),
    ]))),
  ));
}
class _Logo extends StatelessWidget {
  const _Logo({required this.provider, this.large = false}); final CareProvider provider; final bool large;
  @override
  Widget build(BuildContext context) {
    final icon = switch (provider.type) { CareProviderType.pharmacy => LucideIcons.pill, CareProviderType.hospital => LucideIcons.building2, CareProviderType.clinic => LucideIcons.stethoscope, CareProviderType.diagnostics => LucideIcons.flaskConical };
    return Container(width: large ? 66 : 48, height: large ? 66 : 48, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primarySoft, border: Border.all(color: AppColors.outline)), child: Icon(icon, color: AppColors.primary, size: large ? 29 : 22));
  }
}
class _OpenPill extends StatelessWidget { const _OpenPill({required this.open}); final bool open; @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: open ? const Color(0xFFE3F7EB) : AppColors.secondarySoft, borderRadius: BorderRadius.circular(10)), child: Text(open ? 'Open' : 'Closed', style: TextStyle(color: open ? AppColors.success : AppColors.secondary, fontWeight: FontWeight.w700, fontSize: 10))); }
class _Badge extends StatelessWidget { const _Badge(); @override Widget build(BuildContext context) => const Row(mainAxisSize: MainAxisSize.min, children: [Icon(LucideIcons.badgeCheck, color: AppColors.primary, size: 14), SizedBox(width: 3), Text('HealthPocket Partner', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 10))]); }
class _Heading extends StatelessWidget { const _Heading(this.label); final String label; @override Widget build(BuildContext context) => Text(label, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)); }
class _Feedback extends StatelessWidget { const _Feedback({required this.icon, required this.message, required this.action, required this.onTap}); final IconData icon; final String message, action; final VoidCallback onTap; @override Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(AppSpacing.xl), child: Column(children: [Icon(icon, color: AppColors.primary, size: 38), const SizedBox(height: AppSpacing.md), Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.inkMuted)), TextButton(onPressed: onTap, child: Text(action))]))); }

class _ProviderDetails extends StatelessWidget {
  const _ProviderDetails({required this.provider, required this.providers, required this.enabled, required this.savingsStore});
  final CareProvider provider; final List<CareProvider> providers; final bool enabled; final SavingsStore? savingsStore;
  @override
  Widget build(BuildContext context) => Scaffold(body: SafeArea(child: Column(children: [
    Container(height: 150, width: double.infinity, decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFBEEDEA), AppColors.primary])), child: Stack(children: [
      Positioned(top: 6, left: 6, child: _RoundButton(icon: LucideIcons.arrowLeft, onTap: () => Navigator.pop(context))),
      const Positioned(right: 54, top: 6, child: _RoundButton(icon: LucideIcons.heart)),
      const Positioned(right: 6, top: 6, child: _RoundButton(icon: LucideIcons.share2)),
      const Center(child: Icon(LucideIcons.cross, size: 54, color: Colors.white70)),
    ])),
    Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.md), children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Logo(provider: provider, large: true), const SizedBox(width: AppSpacing.md),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(provider.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          Text(_typeName(provider.type) + ' · ' + provider.city, style: const TextStyle(color: AppColors.inkMuted)),
          if (provider.isPartner) const Padding(padding: EdgeInsets.only(top: 6), child: _Badge()),
        ])),
      ]),
      const SizedBox(height: AppSpacing.md),
      Text((provider.isOpen && provider.active ? 'Open' : 'Closed') + (provider.closingTime == null ? '' : ' · Closes ' + provider.closingTime!), style: TextStyle(color: provider.isOpen && provider.active ? AppColors.success : AppColors.secondary, fontWeight: FontWeight.w700)),
      const SizedBox(height: AppSpacing.md),
      const Row(children: [Expanded(child: _Action(icon: LucideIcons.phone, label: 'Call')), SizedBox(width: 8), Expanded(child: _Action(icon: LucideIcons.navigation, label: 'Directions')), SizedBox(width: 8), Expanded(child: _Action(icon: LucideIcons.heart, label: 'Save'))]),
      const SizedBox(height: AppSpacing.lg),
      const _Heading('About'), const SizedBox(height: AppSpacing.xs),
      Text(provider.description ?? 'Fictional demo provider. No booking, payment, or real care authorization is available. This is not evidence of a partnership.', style: const TextStyle(color: AppColors.inkMuted)),
      if (provider.isDemo) const Padding(padding: EdgeInsets.only(top: 8), child: Text('No booking, payment, or real care authorization is available in this beta directory.', style: TextStyle(color: AppColors.inkMuted, fontSize: 12))),
      const SizedBox(height: AppSpacing.lg), const _Heading('Services'), const SizedBox(height: AppSpacing.sm),
      Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: provider.services.map((item) => Chip(label: Text(item), backgroundColor: AppColors.surfaceMuted, side: BorderSide.none, labelStyle: const TextStyle(fontSize: 12))).toList()),
      const SizedBox(height: AppSpacing.lg),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(LucideIcons.mapPin, color: AppColors.primary, size: 20), const SizedBox(width: AppSpacing.sm), Expanded(child: Text(provider.address ?? provider.city + ', ' + provider.state, style: const TextStyle(color: AppColors.inkMuted)))]),
    ])),
    Padding(padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md), child: AppPrimaryButton(label: 'Pay ' + provider.name + '  →', onPressed: enabled && provider.active && provider.isPartner ? () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => DemoCareJourneyScreen(providers: providers, selectedProviderId: provider.id, savingsStore: savingsStore))) : null)),
  ])));
}
class _RoundButton extends StatelessWidget { const _RoundButton({required this.icon, this.onTap}); final IconData icon; final VoidCallback? onTap; @override Widget build(BuildContext context) => Material(color: Colors.white, shape: const CircleBorder(), child: IconButton(onPressed: onTap, icon: Icon(icon, size: 20, color: AppColors.ink))); }
class _Action extends StatelessWidget { const _Action({required this.icon, required this.label}); final IconData icon; final String label; @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(12)), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: AppColors.primary, size: 20), const SizedBox(height: 4), Text(label, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 12))])); }
String _typeName(CareProviderType type) => switch (type) { CareProviderType.clinic => 'Clinic', CareProviderType.hospital => 'Hospital', CareProviderType.pharmacy => 'Pharmacy', CareProviderType.diagnostics => 'Diagnostics' };
