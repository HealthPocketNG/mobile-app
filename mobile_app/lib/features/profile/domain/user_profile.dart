class UserProfile {
  const UserProfile({
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.stateOfResidence,
    required this.memberSince,
    this.dateOfBirth,
    this.gender,
    this.residentialAddress = '',
    this.nextOfKinName = '',
    this.nextOfKinPhone = '',
    this.emailVerified = false,
    this.phoneVerified = false,
    this.demoKycComplete = false,
  });

  final String fullName;
  final String email;
  final String phoneNumber;
  final String stateOfResidence;
  final DateTime memberSince;
  final DateTime? dateOfBirth;
  final String? gender;
  final String residentialAddress;
  final String nextOfKinName;
  final String nextOfKinPhone;
  final bool emailVerified;
  final bool phoneVerified;
  final bool demoKycComplete;

  UserProfile copyWith({
    String? fullName,
    String? email,
    String? phoneNumber,
    String? stateOfResidence,
    DateTime? dateOfBirth,
    String? gender,
    String? residentialAddress,
    String? nextOfKinName,
    String? nextOfKinPhone,
    bool? emailVerified,
    bool? phoneVerified,
    bool? demoKycComplete,
  }) {
    return UserProfile(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      stateOfResidence: stateOfResidence ?? this.stateOfResidence,
      memberSince: memberSince,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      residentialAddress: residentialAddress ?? this.residentialAddress,
      nextOfKinName: nextOfKinName ?? this.nextOfKinName,
      nextOfKinPhone: nextOfKinPhone ?? this.nextOfKinPhone,
      emailVerified: emailVerified ?? this.emailVerified,
      phoneVerified: phoneVerified ?? this.phoneVerified,
      demoKycComplete: demoKycComplete ?? this.demoKycComplete,
    );
  }
}

class NotificationPreferences {
  const NotificationPreferences({
    required this.savingsReminders,
    required this.familyActivity,
    required this.healthReminders,
    required this.productUpdates,
  });

  final bool savingsReminders;
  final bool familyActivity;
  final bool healthReminders;
  final bool productUpdates;

  NotificationPreferences copyWith({
    bool? savingsReminders,
    bool? familyActivity,
    bool? healthReminders,
    bool? productUpdates,
  }) {
    return NotificationPreferences(
      savingsReminders: savingsReminders ?? this.savingsReminders,
      familyActivity: familyActivity ?? this.familyActivity,
      healthReminders: healthReminders ?? this.healthReminders,
      productUpdates: productUpdates ?? this.productUpdates,
    );
  }
}
