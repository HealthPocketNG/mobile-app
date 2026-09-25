import 'package:flutter/material.dart';
import 'package:healthpocket/core/theme/app_colors.dart';

class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({required this.name, this.radius = 32, super.key});

  final String name;
  final double radius;

  static String initialsFor(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final initials = initialsFor(name);
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primarySoft,
      child: initials.isEmpty
          ? Icon(
              Icons.person_outline_rounded,
              color: AppColors.primary,
              size: radius,
            )
          : Text(
              initials,
              style: TextStyle(
                color: AppColors.primaryDark,
                fontSize: radius * .58,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }
}
