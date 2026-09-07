import 'package:flutter/material.dart';

class DashboardGoal {
  const DashboardGoal({
    required this.title,
    required this.targetAmount,
    required this.currentAmount,
    required this.icon,
    required this.color,
  });

  final String title;
  final int targetAmount;
  final int currentAmount;
  final IconData icon;
  final Color color;

  double get progress => targetAmount == 0 ? 0 : currentAmount / targetAmount;
}

class DashboardActivity {
  const DashboardActivity({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isCredit,
  });

  final String title;
  final String subtitle;
  final int? amount;
  final bool isCredit;
}

abstract final class MockDashboardData {
  static const firstName = 'Samson';
  static const totalSaved = 42300;
  static const targetAmount = 150000;

  static const goals = [
    DashboardGoal(
      title: 'Hospital bills',
      targetAmount: 150000,
      currentAmount: 42300,
      icon: Icons.local_hospital_outlined,
      color: Color(0xFF087A76),
    ),
    DashboardGoal(
      title: 'Medicines',
      targetAmount: 60000,
      currentAmount: 18000,
      icon: Icons.medication_outlined,
      color: Color(0xFFD24D68),
    ),
    DashboardGoal(
      title: 'Tests & scans',
      targetAmount: 40000,
      currentAmount: 12000,
      icon: Icons.science_outlined,
      color: Color(0xFF317D9A),
    ),
  ];

  static const activities = [
    DashboardActivity(
      title: 'Goal contribution',
      subtitle: 'Family Health Fund • Today',
      amount: 5000,
      isCredit: true,
    ),
    DashboardActivity(
      title: 'Savings goal created',
      subtitle: 'Family Health Fund • 2 days ago',
      amount: null,
      isCredit: false,
    ),
  ];
}
