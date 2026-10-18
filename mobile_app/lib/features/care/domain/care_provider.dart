import 'dart:math' as math;

enum CareProviderType { clinic, hospital, pharmacy, diagnostics, other }

enum CarePartnerStatus { partner, nonPartner }

class CareCoordinates {
  const CareCoordinates({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  bool get isValid =>
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;

  double distanceKmTo(CareCoordinates other) {
    const earthRadiusKm = 6371.0088;
    final latitudeDelta = _radians(other.latitude - latitude);
    final longitudeDelta = _radians(other.longitude - longitude);
    final firstLatitude = _radians(latitude);
    final secondLatitude = _radians(other.latitude);
    final haversine =
        math.pow(math.sin(latitudeDelta / 2), 2) +
        math.cos(firstLatitude) *
            math.cos(secondLatitude) *
            math.pow(math.sin(longitudeDelta / 2), 2);
    return earthRadiusKm * 2 * math.asin(math.sqrt(haversine));
  }

  Uri get googleMapsDirectionsUri => Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': '$latitude,$longitude',
  });

  static double _radians(double degrees) => degrees * math.pi / 180;
}

class CareProviderContact {
  const CareProviderContact({this.phone, this.email, this.website});

  final String? phone;
  final String? email;
  final Uri? website;
}

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
    this.coordinates,
    this.contact = const CareProviderContact(),
    this.logoUrl,
    this.imageUrls = const [],
    this.locationCells = const [],
    this.distanceKm,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String state;
  final CareProviderType type;
  final List<String> services;
  final String? address;
  final String? openingHours;
  final String? phone;
  final bool isDemo;
  final bool active;
  final String city;
  final double mockDistanceKm;
  final bool isPartner;
  final bool isOpen;
  final String? closingTime;
  final String? description;
  final CareCoordinates? coordinates;
  final CareProviderContact contact;
  final Uri? logoUrl;
  final List<Uri> imageUrls;
  final List<String> locationCells;
  final double? distanceKm;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CarePartnerStatus get partnerStatus =>
      isPartner ? CarePartnerStatus.partner : CarePartnerStatus.nonPartner;

  String? get effectivePhone => contact.phone ?? phone;

  Uri? get directionsUri => coordinates?.googleMapsDirectionsUri;

  double get displayDistanceKm => distanceKm ?? mockDistanceKm;

  CareProvider copyWithDistance(double value) => CareProvider(
    id: id,
    name: name,
    state: state,
    type: type,
    services: services,
    address: address,
    openingHours: openingHours,
    phone: phone,
    isDemo: isDemo,
    active: active,
    city: city,
    mockDistanceKm: mockDistanceKm,
    isPartner: isPartner,
    isOpen: isOpen,
    closingTime: closingTime,
    description: description,
    coordinates: coordinates,
    contact: contact,
    logoUrl: logoUrl,
    imageUrls: imageUrls,
    locationCells: locationCells,
    distanceKm: value,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

abstract interface class CareDirectoryRepository {
  Future<List<CareProvider>> getProviders();
}

abstract interface class QueryableCareDirectoryRepository
    implements CareDirectoryRepository {
  Future<List<CareProvider>> searchProviders(CareProviderQuery query);
}

class CareProviderQuery {
  const CareProviderQuery({
    this.search = '',
    this.state,
    this.city,
    this.type,
    this.partnerStatus,
    this.origin,
    this.radiusKm = 25,
    this.limit = 100,
  });

  final String search;
  final String? state;
  final String? city;
  final CareProviderType? type;
  final CarePartnerStatus? partnerStatus;
  final CareCoordinates? origin;
  final double radiusKm;
  final int limit;
}

List<CareProvider> filterCareProviders(
  List<CareProvider> providers, {
  String query = '',
  String? state,
  String? city,
  CareProviderType? type,
  CarePartnerStatus? partnerStatus,
  CareCoordinates? origin,
  double? radiusKm,
}) {
  final normalizedQuery = query.trim().toLowerCase();
  final results = providers
      .where((provider) {
        final locationMatches = origin == null || radiusKm == null
            ? true
            : provider.coordinates != null &&
                  origin.distanceKmTo(provider.coordinates!) <= radiusKm;
        return provider.active &&
            (normalizedQuery.isEmpty ||
                provider.name.toLowerCase().contains(normalizedQuery) ||
                provider.city.toLowerCase().contains(normalizedQuery) ||
                provider.state.toLowerCase().contains(normalizedQuery) ||
                (provider.address?.toLowerCase().contains(normalizedQuery) ??
                    false) ||
                _typeSearchLabel(provider.type).contains(normalizedQuery) ||
                provider.services.any(
                  (service) => service.toLowerCase().contains(normalizedQuery),
                )) &&
            (state == null || provider.state == state) &&
            (city == null || provider.city == city) &&
            (type == null || provider.type == type) &&
            (partnerStatus == null ||
                provider.partnerStatus == partnerStatus) &&
            locationMatches;
      })
      .map((provider) {
        if (origin == null || provider.coordinates == null) return provider;
        return provider.copyWithDistance(
          origin.distanceKmTo(provider.coordinates!),
        );
      })
      .toList();
  if (origin != null) {
    results.sort((a, b) => a.displayDistanceKm.compareTo(b.displayDistanceKm));
  }
  return results;
}

String careLocationCell(CareCoordinates coordinates) {
  if (!coordinates.isValid) {
    throw ArgumentError.value(coordinates, 'coordinates', 'Invalid location.');
  }
  final latitudeCell = ((coordinates.latitude + 90) * 4).floor();
  final longitudeCell = ((coordinates.longitude + 180) * 4).floor();
  return 'g_${latitudeCell}_$longitudeCell';
}

List<String> neighboringCareLocationCells(CareCoordinates coordinates) {
  final center = careLocationCell(coordinates).split('_');
  final latitudeCell = int.parse(center[1]);
  final longitudeCell = int.parse(center[2]);
  return [
    for (var latitudeOffset = -1; latitudeOffset <= 1; latitudeOffset++)
      for (var longitudeOffset = -1; longitudeOffset <= 1; longitudeOffset++)
        'g_${latitudeCell + latitudeOffset}_${longitudeCell + longitudeOffset}',
  ];
}

String _typeSearchLabel(CareProviderType type) => switch (type) {
  CareProviderType.clinic => 'clinic',
  CareProviderType.hospital => 'hospital',
  CareProviderType.pharmacy => 'pharmacy',
  CareProviderType.diagnostics => 'diagnostics',
  CareProviderType.other => 'healthcare',
};
