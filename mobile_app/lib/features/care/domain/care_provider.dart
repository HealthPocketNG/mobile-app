enum CareProviderType { clinic, hospital, pharmacy, diagnostics }

class CareProvider {
  const CareProvider({
    required this.id,
    required this.name,
    required this.state,
    required this.type,
    required this.services,
    this.address,
    this.openingHours,
    this.phone,
    this.isDemo = true,
    this.active = true,
    this.city = 'Demo city',
    this.mockDistanceKm = 0,
    this.isPartner = true,
    this.isOpen = true,
    this.closingTime,
    this.description,
  });
  final String id, name, state;
  final CareProviderType type;
  final List<String> services;
  final String? address, openingHours, phone;
  final bool isDemo;
  final bool active;
  final String city;
  final double mockDistanceKm;
  final bool isPartner;
  final bool isOpen;
  final String? closingTime;
  final String? description;
}

abstract interface class CareDirectoryRepository {
  Future<List<CareProvider>> getProviders();
}

List<CareProvider> filterCareProviders(
  List<CareProvider> providers, {
  String query = '',
  String? state,
  CareProviderType? type,
}) => providers
    .where(
      (provider) =>
          (provider.name.toLowerCase().contains(query.trim().toLowerCase()) ||
              _typeSearchLabel(provider.type).contains(query.trim().toLowerCase()) ||
              provider.services.any(
                (service) => service.toLowerCase().contains(query.trim().toLowerCase()),
              )) &&
          (state == null || provider.state == state) &&
          (type == null || provider.type == type),
    )
    .toList();

String _typeSearchLabel(CareProviderType type) => switch (type) {
  CareProviderType.clinic => 'clinic',
  CareProviderType.hospital => 'hospital',
  CareProviderType.pharmacy => 'pharmacy',
  CareProviderType.diagnostics => 'diagnostics',
};
