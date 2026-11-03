class CoverageGuide {
  const CoverageGuide({
    required this.title,
    required this.subtitle,
    required this.referenceCost,
    required this.asset,
    this.category = CoverageCategory.medicines,
    this.detailAsset,
    this.includedServices = const [],
  });

  final String title;
  final String subtitle;
  final int referenceCost;
  final String asset;
  final CoverageCategory category;
  final String? detailAsset;
  final List<String> includedServices;
}

enum CoverageCategory { medicines, tests, visits, dental, eyes }

const coverageCatalog = [
  CoverageGuide(
    title: 'Malaria treatment',
    subtitle: 'Test and medication',
    referenceCost: 4500,
    asset: 'assets/dashboard/v2/coverage/malaria.svg',
    detailAsset: 'assets/dashboard/v2/coverage/malaria-large.svg',
    includedServices: ['Consultation', 'Malaria test', 'Prescribed medication'],
  ),
  CoverageGuide(
    title: 'Basic tests',
    subtitle: 'e.g. blood test',
    referenceCost: 6000,
    asset: 'assets/dashboard/v2/coverage/basic-tests.svg',
    category: CoverageCategory.tests,
  ),
  CoverageGuide(
    title: 'First aid essentials',
    subtitle: 'Bandages, antiseptic and more',
    referenceCost: 3200,
    asset: 'assets/dashboard/v2/coverage/first-aid.svg',
  ),
  CoverageGuide(
    title: 'GP consultation',
    subtitle: 'Doctor visit',
    referenceCost: 5000,
    asset: 'assets/dashboard/v2/coverage/gp-consultation.svg',
    category: CoverageCategory.visits,
  ),
  CoverageGuide(
    title: 'Dental scaling',
    subtitle: 'Cleaning and polishing',
    referenceCost: 14000,
    asset: 'assets/dashboard/v2/coverage/dental-scaling.svg',
    category: CoverageCategory.dental,
  ),
  CoverageGuide(
    title: 'Spectacles (basic)',
    subtitle: 'Eye test and frames',
    referenceCost: 20000,
    asset: '',
    category: CoverageCategory.eyes,
  ),
];

const dashboardCoverageGuides = [
  CoverageGuide(
    title: 'Malaria treatment',
    subtitle: 'Consultation + medicine',
    referenceCost: 4500,
    asset: 'assets/dashboard/malariaTreatment.svg',
  ),
  CoverageGuide(
    title: 'Basic tests',
    subtitle: 'e.g. blood test',
    referenceCost: 6000,
    asset: 'assets/dashboard/basicTest.svg',
  ),
  CoverageGuide(
    title: 'First aid essentials',
    subtitle: 'Everyday care kit',
    referenceCost: 3200,
    asset: 'assets/dashboard/firstAid.svg',
  ),
];

List<CoverageGuide> eligibleDashboardCoverageForBalance(int balanceKobo) =>
    dashboardCoverageGuides
        .where((guide) => balanceKobo >= guide.referenceCost * 100)
        .toList(growable: false);
