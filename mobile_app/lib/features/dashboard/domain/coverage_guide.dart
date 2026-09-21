class CoverageGuide {
  const CoverageGuide({
    required this.title,
    required this.subtitle,
    required this.referenceCost,
    required this.asset,
  });

  final String title;
  final String subtitle;
  final int referenceCost;
  final String asset;
}

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
