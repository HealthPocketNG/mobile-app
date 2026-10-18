import 'package:flutter_test/flutter_test.dart';
import 'package:healthpocket/features/care/domain/care_provider.dart';

void main() {
  const lagos = CareCoordinates(latitude: 6.5244, longitude: 3.3792);
  const ikeja = CareCoordinates(latitude: 6.6018, longitude: 3.3515);

  CareProvider provider({
    String id = 'provider-1',
    CareProviderType type = CareProviderType.clinic,
    bool active = true,
    bool partner = true,
    CareCoordinates coordinates = ikeja,
  }) => CareProvider(
    id: id,
    name: 'Community Care',
    state: 'Lagos',
    city: 'Ikeja',
    type: type,
    services: const ['Consultation'],
    active: active,
    isPartner: partner,
    coordinates: coordinates,
  );

  test('calculates distance, neighboring cells and Google Maps directions', () {
    final distance = lagos.distanceKmTo(ikeja);
    expect(distance, inInclusiveRange(8, 10));
    expect(careLocationCell(ikeja), 'g_386_733');
    expect(neighboringCareLocationCells(ikeja), hasLength(9));
    expect(
      ikeja.googleMapsDirectionsUri.queryParameters,
      containsPair('destination', '6.6018,3.3515'),
    );
  });

  test('filters active providers by category, partnership and radius', () {
    final providers = [
      provider(),
      provider(id: 'other', partner: false, type: CareProviderType.other),
      provider(id: 'inactive', active: false),
      provider(
        id: 'far-away',
        coordinates: const CareCoordinates(latitude: 9.0765, longitude: 7.3986),
      ),
    ];

    expect(
      filterCareProviders(
        providers,
        type: CareProviderType.clinic,
        partnerStatus: CarePartnerStatus.partner,
        origin: lagos,
        radiusKm: 25,
      ).map((item) => item.id),
      ['provider-1'],
    );
    expect(
      filterCareProviders(providers, type: CareProviderType.other).single.id,
      'other',
    );
  });
}
