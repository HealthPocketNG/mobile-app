import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:healthpocket/core/data/backend_ids.dart';
import 'package:healthpocket/core/data/repository_contracts.dart';
import 'package:healthpocket/core/logging/backend_logger.dart';
import 'package:healthpocket/features/profile/domain/profile_photo.dart';

class FirebaseProfilePhotoRepository implements ProfilePhotoRepository {
  FirebaseProfilePhotoRepository(this._storage, {BackendLogger? logger})
    : _logger = logger ?? BackendLogger.instance;

  static const _extensions = <String, String>{
    'image/jpeg': 'jpg',
    'image/png': 'png',
    'image/webp': 'webp',
  };

  final FirebaseStorage _storage;
  final BackendLogger _logger;

  @override
  Future<String> upload({
    required String userId,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final uid = BackendIds.requireUserId(userId);
    final extension = _extensions[contentType];
    if (extension == null) {
      throw ArgumentError.value(contentType, 'contentType');
    }
    ProfilePhotoPolicy.validate(bytes, contentType);
    final path = 'users/$uid/profile/${BackendIds.newRequestKey()}.$extension';
    return _logger.trace<String>(
      repository: 'profile_photo',
      operation: 'upload',
      entity: 'profile_photo',
      action: () async {
        await _storage
            .ref(path)
            .putData(
              bytes,
              SettableMetadata(
                contentType: contentType,
                cacheControl: 'private,max-age=3600',
              ),
            );
        return path;
      },
    );
  }

  @override
  Future<String?> getDownloadUrl({
    required String userId,
    required String? storagePath,
  }) async {
    if (storagePath == null || storagePath.isEmpty) return null;
    _requireOwnedPath(userId, storagePath);
    return _storage.ref(storagePath).getDownloadURL();
  }

  @override
  Future<void> delete({
    required String userId,
    required String storagePath,
  }) async {
    _requireOwnedPath(userId, storagePath);
    await _logger.trace<void>(
      repository: 'profile_photo',
      operation: 'delete',
      entity: 'profile_photo',
      action: () => _storage.ref(storagePath).delete(),
    );
  }

  void _requireOwnedPath(String userId, String path) {
    final uid = BackendIds.requireUserId(userId);
    final prefix = 'users/$uid/profile/';
    final fileName = path.startsWith(prefix)
        ? path.substring(prefix.length)
        : '';
    if (fileName.isEmpty || fileName.contains('/') || fileName.contains('\\')) {
      throw ArgumentError.value(path, 'storagePath');
    }
  }
}
