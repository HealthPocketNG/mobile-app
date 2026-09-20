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
    asset: 'assets/dashboard/malariaTreatment.png',
  ),
  CoverageGuide(
    title: 'Basic tests',
    subtitle: 'e.g. blood test',
    referenceCost: 6000,
    asset: 'assets/dashboard/basicTest.png',
  ),
  CoverageGuide(
    title: 'First aid essentials',
    subtitle: 'Everyday care kit',
    referenceCost: 3200,
    asset: 'assets/dashboard/firstAid.png',
  ),
  CoverageGuide(
    title: 'Prescription medicine',
    subtitle: 'Common prescriptions',
    referenceCost: 8500,
    asset: 'assets/dashboard/prescriptionMedicine.png',
  ),
  CoverageGuide(
    title: 'Maternity care',
    subtitle: 'Antenatal essentials',
    referenceCost: 25000,
    asset: 'assets/dashboard/maternity.png',
  ),
  CoverageGuide(
    title: 'Dental care',
    subtitle: 'Routine dental visit',
    referenceCost: 12000,
    asset: 'assets/dashboard/dentalCare.png',
  ),
];
