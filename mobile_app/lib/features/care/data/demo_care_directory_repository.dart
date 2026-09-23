import 'package:healthpocket/features/care/domain/care_provider.dart';

class DemoCareDirectoryRepository implements CareDirectoryRepository {
  const DemoCareDirectoryRepository();
  @override
  Future<List<CareProvider>> getProviders() async => const [
    CareProvider(
      id: 'demo_clinic_001',
      city: 'Ikeja',
      mockDistanceKm: 2.4,
      name: 'Demo Community Clinic',
      state: 'Lagos',
      type: CareProviderType.clinic,
      address: 'Abraka Road, Delta State',
      closingTime: '8:00 PM',
      description: 'A fictional neighbourhood clinic for beta experience testing.',
      services: ['Consultation', 'Health & Wellness'],
    ),
    CareProvider(
      id: 'demo_pharmacy_001',
      city: 'Yaba',
      mockDistanceKm: 12.5,
      name: 'Demo Neighbourhood Pharmacy',
      state: 'Lagos',
      type: CareProviderType.pharmacy,
      address: 'Oghaire Street, Abraka, Delta State',
      closingTime: '8:00 PM',
      description: 'A fictional local pharmacy listing for beta experience testing.',
      services: ['Prescription Drugs', 'OTC Medicines', 'Health & Wellness'],
    ),
    CareProvider(
      id: 'demo_hospital_001',
      city: 'Port Harcourt',
      mockDistanceKm: 440,
      name: 'Demo Health Hospital',
      state: 'Rivers',
      type: CareProviderType.hospital,
      isPartner: false,
      services: ['Example outpatient care'],
    ),
    CareProvider(
      id: 'demo_clinic_002',
      city: 'Abuja',
      mockDistanceKm: 530,
      active: false,
      name: 'Demo Capital Clinic',
      state: 'Abuja (FCT)',
      type: CareProviderType.clinic,
      services: ['Example consultations'],
    ),
  ];
}
