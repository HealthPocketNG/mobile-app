import 'package:flutter/material.dart';
import 'package:healthpocket/features/care/presentation/demo_care_journey_screen.dart';
import 'package:healthpocket/core/widgets/app_bottom_navigation.dart';
import 'package:healthpocket/features/care/data/demo_care_directory_repository.dart';
import 'package:healthpocket/features/care/domain/care_provider.dart';

enum DemoLocationStatus { notRequested, granted, denied, unavailable }

class FindCareScreen extends StatefulWidget {
  const FindCareScreen({
    super.key,
    this.repository = const DemoCareDirectoryRepository(),
    this.demoRequestsEnabled = false,
  });
  final CareDirectoryRepository repository;
  final bool demoRequestsEnabled;
  @override
  State<FindCareScreen> createState() => _FindCareScreenState();
}

class _FindCareScreenState extends State<FindCareScreen> {
  final _search = TextEditingController();
  List<CareProvider> _providers = [];
  String? _state;
  CareProviderType? _type;
  bool _loading = true;
  bool _failed = false;
  DemoLocationStatus _locationStatus = DemoLocationStatus.notRequested;
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
      if (mounted) {
        setState(() {
          _providers = providers;
          if (!providers.any((p) => p.state == _state)) {
            _state = null;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _failed = true);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = filterCareProviders(
      _providers,
      query: _search.text,
      state: _state,
      type: _type,
    );
    if (_locationStatus == DemoLocationStatus.granted) {
      results.sort((a, b) => a.mockDistanceKm.compareTo(b.mockDistanceKm));
    }
    final states = _providers.map((p) => p.state).toSet().toList()..sort();
    return Scaffold(
      appBar: AppBar(title: const Text('Find care')),
      bottomNavigationBar: const AppBottomNavigation(currentIndex: 4),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Demo directory — available offline. These fictional listings are for testing only, not confirmed partners. Do not travel to or request care from these listings.',
            ),
            const SizedBox(height: 16),
            _LocationStatusCard(
              status: _locationStatus,
              onChanged: (status) =>
                  setState(() => _locationStatus = status),
            ),
            TextField(
              controller: _search,
              decoration: const InputDecoration(
                labelText: 'Search provider name',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            DropdownButton<String>(
              isExpanded: true,
              value: _state,
              hint: const Text('All states'),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('All states'),
                ),
                ...states.map(
                  (state) => DropdownMenuItem(value: state, child: Text(state)),
                ),
              ],
              onChanged: (value) => setState(() => _state = value),
            ),
            DropdownButton<CareProviderType>(
              isExpanded: true,
              value: _type,
              hint: const Text('All provider types'),
              items: [
                const DropdownMenuItem<CareProviderType>(
                  value: null,
                  child: Text('All provider types'),
                ),
                ...CareProviderType.values.map(
                  (type) => DropdownMenuItem(
                    value: type,
                    child: Text(_typeLabel(type)),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _type = value),
            ),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_failed) ...[
              const Text('Could not load the directory. Please try again.'),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ] else ...[
              Text('${results.length} providers'),
              if (results.isEmpty) ...[
                Text(
                  _providers.isEmpty
                      ? 'No demo partner centres are available right now.'
                      : 'No providers match your search. Try another state or provider type.',
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _search.clear();
                    _state = null;
                    _type = null;
                  }),
                  child: const Text('Clear filters'),
                ),
              ],
              ...results.map(
                (provider) => Card(
                  child: ListTile(
                    title: Text(provider.name),
                    subtitle: Text('${provider.city}, ${provider.state} • '
                        '${_typeLabel(provider.type)} • '
                        '${provider.services.first} • '
                        '${provider.active ? 'Active beta partner' : 'Inactive'}'
                        '${_locationStatus == DemoLocationStatus.granted ? ' • ${provider.mockDistanceKm <= 25 ? 'Nearby' : 'Farther away'} • ${provider.mockDistanceKm.toStringAsFixed(1)} km' : ''}'
                        '${provider.isDemo ? ' • Demo beta' : ''}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => _ProviderDetails(
                          provider: provider,
                          providers: _providers,
                          demoRequestsEnabled: widget.demoRequestsEnabled,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _typeLabel(CareProviderType type) => switch (type) {
  CareProviderType.clinic => 'Clinic',
  CareProviderType.hospital => 'Hospital',
  CareProviderType.pharmacy => 'Pharmacy',
};

class _ProviderDetails extends StatelessWidget {
  const _ProviderDetails({
    required this.provider,
    required this.providers,
    required this.demoRequestsEnabled,
  });
  final CareProvider provider;
  final List<CareProvider> providers;
  final bool demoRequestsEnabled;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Provider details')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(provider.name, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        if (provider.isDemo)
          const Text(
            'Fictional demo provider. No booking, payment, or real care authorization is available. This is not evidence of a partnership.',
          ),
        const SizedBox(height: 16),
        Text('${_typeLabel(provider.type)} • ${provider.city}, ${provider.state}'),
        Text('Operating status: ${provider.active ? 'Active beta partner' : 'Inactive'}'),
        const SizedBox(height: 16),
        Text('Address: ${provider.address ?? 'Not provided — demo listing'}'),
        Text('Opening hours: ${provider.openingHours ?? 'Not provided'}'),
        Text('Contact: ${provider.phone ?? 'Not provided'}'),
        const SizedBox(height: 16),
        const Text('Services'),
        ...provider.services.map(
          (service) => Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(service),
          ),
        ),
        const SizedBox(height: 24),
        if (demoRequestsEnabled && provider.active)
          FilledButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => DemoCareJourneyScreen(
                  providers: providers,
                  selectedProviderId: provider.id,
                ),
              ),
            ),
            child: Text('Pay ${provider.name} — demo authorization'),
          ),
        if (!provider.active)
          const Text('This demo provider is inactive, so authorization is unavailable.'),
      ],
    ),
  );
}

class _LocationStatusCard extends StatelessWidget {
  const _LocationStatusCard({required this.status, required this.onChanged});
  final DemoLocationStatus status;
  final ValueChanged<DemoLocationStatus> onChanged;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(switch (status) {
                DemoLocationStatus.notRequested =>
                  'Location has not been requested. Choose a demo state below.',
                DemoLocationStatus.granted =>
                  'Demo location enabled. Distances use mock coordinates; precise location is not collected or saved.',
                DemoLocationStatus.denied =>
                  'Location permission denied. Search and state filters still work.',
                DemoLocationStatus.unavailable =>
                  'Location is unavailable. Search and state filters still work.',
              }),
              if (status == DemoLocationStatus.notRequested)
                FilledButton(
                  onPressed: () => onChanged(DemoLocationStatus.granted),
                  child: const Text('Use mock location'),
                ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: () => onChanged(DemoLocationStatus.denied),
                    child: const Text('Simulate denied'),
                  ),
                  TextButton(
                    onPressed: () => onChanged(DemoLocationStatus.unavailable),
                    child: const Text('Simulate unavailable'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}
