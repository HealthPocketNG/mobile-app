import 'package:healthpocket/features/care/domain/care_provider.dart';

class DemoCareDirectoryRepository implements CareDirectoryRepository {
  const DemoCareDirectoryRepository();
  @override
  Future<List<CareProvider>> getProviders() async => const [
    CareProvider(
      id: 'demo-clinic',
      name: 'Demo Community Clinic',
      state: 'Lagos',
      type: CareProviderType.clinic,
      services: ['Example consultations', 'Example check-ups'],
    ),
    CareProvider(
      id: 'demo-pharmacy',
      name: 'Demo Neighbourhood Pharmacy',
      state: 'Lagos',
      type: CareProviderType.pharmacy,
      services: ['Example prescription support'],
    ),
    CareProvider(
      id: 'demo-hospital',
      name: 'Demo Health Hospital',
      state: 'Rivers',
      type: CareProviderType.hospital,
      services: ['Example outpatient care'],
    ),
    CareProvider(
      id: 'demo-abuja',
      name: 'Demo Capital Clinic',
      state: 'Abuja (FCT)',
      type: CareProviderType.clinic,
      services: ['Example consultations'],
    ),
  ];
}
