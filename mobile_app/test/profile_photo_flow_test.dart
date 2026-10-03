import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:healthpocket/app/app_state.dart';
import 'package:healthpocket/core/data/repository_contracts.dart';
import 'package:healthpocket/features/auth/data/app_pin_repository.dart';
import 'package:healthpocket/features/auth/data/in_memory_auth_repository.dart';
import 'package:healthpocket/features/auth/domain/auth_user.dart';
import 'package:healthpocket/features/profile/domain/profile_photo.dart';
import 'package:healthpocket/features/profile/domain/user_profile.dart';

void main() {
  test('photo validation checks both file signature and size', () {
    final jpeg = Uint8List.fromList([0xff, 0xd8, 0xff, 0xd9]);
    expect(ProfilePhotoPolicy.detectContentType(jpeg), 'image/jpeg');
    expect(
      () => ProfilePhotoPolicy.validate(jpeg, 'image/jpeg'),
      returnsNormally,
    );
    expect(
      () => ProfilePhotoPolicy.validate(jpeg, 'image/png'),
      throwsArgumentError,
    );
    expect(
      () => ProfilePhotoPolicy.validate(
        Uint8List(ProfilePhotoPolicy.maximumBytes + 1),
        'image/jpeg',
      ),
      throwsArgumentError,
    );
  });

  test(
    'photo replacement persists the new reference then removes the old file',
    () async {
      final auth = InMemoryAuthRepository();
      final profiles = _MemoryProfileRepository();
      final photos = _MemoryProfilePhotoRepository();
      final appState = AppState(
        authRepository: auth,
        pinRepository: SecureAppPinRepository(
          storage: MemorySecureValueStore(),
        ),
        profileRepository: profiles,
        profilePhotoRepository: photos,
      );
      addTearDown(appState.dispose);
      addTearDown(auth.dispose);

      final signedIn = await auth.signInWithGoogle();
      await appState.acceptAuthentication(signedIn!);

      await appState.updateProfilePhoto(
        bytes: Uint8List.fromList([0xff, 0xd8, 0xff, 0xd9]),
        contentType: 'image/jpeg',
      );
      final firstPath = appState.profileStore.profile.profileImagePath;
      expect(firstPath, isNotNull);
      expect(profiles.data.profile.profileImagePath, firstPath);
      expect(photos.deleted, isEmpty);

      await appState.updateProfilePhoto(
        bytes: Uint8List.fromList([0x89, 0x50, 0x4e, 0x47]),
        contentType: 'image/png',
      );
      final secondPath = appState.profileStore.profile.profileImagePath;
      expect(secondPath, isNot(firstPath));
      expect(photos.deleted, contains(firstPath));

      await appState.removeProfilePhoto();
      expect(appState.profileStore.profile.profileImagePath, isNull);
      expect(profiles.data.profile.profileImagePath, isNull);
      expect(photos.deleted, contains(secondPath));
    },
  );
}

class _MemoryProfileRepository implements ProfileRepository {
  _MemoryProfileRepository()
    : data = UserProfileDocumentData(
        profile: UserProfile(
          fullName: 'Amara Okafor',
          email: 'amara@example.com',
          phoneNumber: '08000000000',
          stateOfResidence: 'Lagos',
          memberSince: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
          emailVerified: true,
        ),
        notifications: const NotificationPreferences(
          savingsReminders: true,
          familyActivity: true,
          healthReminders: true,
          productUpdates: false,
        ),
        kycStatus: KycStatus.notStarted,
        onboardingStatus: AccountOnboardingStatus.complete,
      );

  UserProfileDocumentData data;

  @override
  Future<UserProfileDocumentData?> getProfile(String userId) async => data;

  @override
  Future<ProfileProvisioningResult> getOrCreateProfile(AuthUser user) async =>
      ProfileProvisioningResult(data: data, wasCreated: false);

  @override
  Future<void> saveProfile({
    required String userId,
    required UserProfile profile,
    required NotificationPreferences notifications,
    required AccountOnboardingStatus onboardingStatus,
  }) async {
    data = UserProfileDocumentData(
      profile: profile,
      notifications: notifications,
      kycStatus: data.kycStatus,
      onboardingStatus: onboardingStatus,
    );
  }

  @override
  Stream<UserProfileDocumentData?> watchProfile(String userId) =>
      Stream.value(data);
}

class _MemoryProfilePhotoRepository implements ProfilePhotoRepository {
  var uploads = 0;
  final List<String> deleted = [];

  @override
  Future<void> delete({
    required String userId,
    required String storagePath,
  }) async {
    deleted.add(storagePath);
  }

  @override
  Future<String?> getDownloadUrl({
    required String userId,
    required String? storagePath,
  }) async => storagePath == null ? null : 'https://example.test/$storagePath';

  @override
  Future<String> upload({
    required String userId,
    required Uint8List bytes,
    required String contentType,
  }) async {
    uploads++;
    final token = uploads.toString().padLeft(32, '0');
    final extension = contentType == 'image/png' ? 'png' : 'jpg';
    return 'users/$userId/profile/$token.$extension';
  }
}
