import 'package:flutter/material.dart';

class HealthcareCostGuide {
  const HealthcareCostGuide({
    required this.title,
    required this.referenceCost,
    required this.icon,
    required this.color,
  });

  final String title;
  final int referenceCost;
  final IconData icon;
  final Color color;
}

abstract final class MockDashboardData {
  static const firstName = 'Samson';

  static const coverageGuides = [
    HealthcareCostGuide(
      title: 'Hospital visit',
      referenceCost: 15000,
      icon: Icons.local_hospital_outlined,
      color: Color(0xFF087A76),
    ),
    HealthcareCostGuide(
      title: 'Medicines',
      referenceCost: 25000,
      icon: Icons.medication_outlined,
      color: Color(0xFFD24D68),
    ),
    HealthcareCostGuide(
      title: 'Tests & scans',
      referenceCost: 40000,
      icon: Icons.science_outlined,
      color: Color(0xFF317D9A),
    ),
  ];
}
