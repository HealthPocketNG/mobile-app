enum CareProviderType { clinic, hospital, pharmacy }

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
  });
  final String id, name, state;
  final CareProviderType type;
  final List<String> services;
  final String? address, openingHours, phone;
  final bool isDemo;
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
          provider.name.toLowerCase().contains(query.trim().toLowerCase()) &&
          (state == null || provider.state == state) &&
          (type == null || provider.type == type),
    )
    .toList();
