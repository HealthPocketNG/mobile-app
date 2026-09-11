import 'package:flutter/foundation.dart';
import 'package:healthpocket/features/profile/data/mock_profile_data.dart';
import 'package:healthpocket/features/profile/domain/user_profile.dart';

class ProfileStore extends ChangeNotifier {
  UserProfile _profile = MockProfileData.profile;
  NotificationPreferences _notifications = MockProfileData.notifications;
  bool _biometricUnlock = false;

  UserProfile get profile => _profile;
  NotificationPreferences get notifications => _notifications;
  bool get biometricUnlock => _biometricUnlock;

  void hydrate({
    required UserProfile profile,
    required NotificationPreferences notifications,
  }) {
    _profile = profile;
    _notifications = notifications;
    notifyListeners();
  }

  void beginRegistration({
    required String fullName,
    required String email,
    required String phoneNumber,
    bool emailVerified = false,
  }) {
    _profile = UserProfile(
      fullName: fullName,
      email: email,
      phoneNumber: phoneNumber,
      stateOfResidence: '',
      memberSince: DateTime.now(),
      emailVerified: emailVerified,
    );
    _notifications = MockProfileData.notifications;
    _biometricUnlock = false;
    notifyListeners();
  }

  void verifyEmailAddress() {
    if (_profile.emailVerified) return;
    _profile = _profile.copyWith(emailVerified: true);
    notifyListeners();
  }

  void verifyPhoneNumber() {
    if (_profile.phoneVerified) return;
    _profile = _profile.copyWith(phoneVerified: true);
    notifyListeners();
  }

  void updatePersonalInformation({
    required DateTime dateOfBirth,
    required String gender,
    required String residentialAddress,
    required String stateOfResidence,
    required String nextOfKinName,
    required String nextOfKinPhone,
  }) {
    _profile = _profile.copyWith(
      dateOfBirth: dateOfBirth,
      gender: gender,
      residentialAddress: residentialAddress,
      stateOfResidence: stateOfResidence,
      nextOfKinName: nextOfKinName,
      nextOfKinPhone: nextOfKinPhone,
    );
    notifyListeners();
  }

  void completeDemoKyc() {
    if (_profile.demoKycComplete) return;
    _profile = _profile.copyWith(demoKycComplete: true);
    notifyListeners();
  }

  void updateAccount({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String stateOfResidence,
  }) {
    _profile = _profile.copyWith(
      fullName: fullName,
      email: email,
      phoneNumber: phoneNumber,
      stateOfResidence: stateOfResidence,
      emailVerified: email == _profile.email && _profile.emailVerified,
      phoneVerified:
          phoneNumber == _profile.phoneNumber && _profile.phoneVerified,
    );
    notifyListeners();
  }

  void setBiometricUnlock(bool value) {
    _biometricUnlock = value;
    notifyListeners();
  }

  void setSavingsReminderNotifications(bool value) {
    _notifications = _notifications.copyWith(savingsReminders: value);
    notifyListeners();
  }

  void setFamilyActivityNotifications(bool value) {
    _notifications = _notifications.copyWith(familyActivity: value);
    notifyListeners();
  }

  void setHealthReminders(bool value) {
    _notifications = _notifications.copyWith(healthReminders: value);
    notifyListeners();
  }

  void setProductUpdates(bool value) {
    _notifications = _notifications.copyWith(productUpdates: value);
    notifyListeners();
  }
}
