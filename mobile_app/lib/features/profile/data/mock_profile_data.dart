import 'package:healthpocket/features/profile/domain/user_profile.dart';

abstract final class MockProfileData {
  static final profile = UserProfile(
    fullName: 'Samson Adebayo',
    email: 'samsonadebola@gmail.com',
    phoneNumber: '+234 803 123 4567',
    stateOfResidence: 'Lagos',
    memberSince: DateTime(2026, 9),
    dateOfBirth: DateTime(1990, 5, 12),
    gender: 'male',
    residentialAddress: '12 Adeola Street, Yaba',
    nextOfKinName: 'Grace Adebayo',
    nextOfKinPhone: '+234 805 987 6543',
    emailVerified: true,
    phoneVerified: true,
    demoKycComplete: true,
  );

  static const notifications = NotificationPreferences(
    savingsReminders: true,
    familyActivity: true,
    healthReminders: true,
    productUpdates: false,
  );
}
