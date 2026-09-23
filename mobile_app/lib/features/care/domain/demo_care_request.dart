import 'dart:math';

import 'package:healthpocket/features/care/domain/care_provider.dart';

enum DemoAuthorizationStatus { created, rejected, cancelled, expired }

int? parseCareAmount(String raw) {
  if (!RegExp(r'^\d{1,7}(\.\d{1,2})?$').hasMatch(raw.trim())) return null;
  final parts = raw.trim().split('.');
  final kobo = int.parse(parts[0]) * 100 +
      (parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0);
  return kobo > 0 && kobo <= 100000000 ? kobo : null;
}

String? parseDemoProviderQr(String raw) {
  final match = RegExp(r'^hp://provider/([a-z0-9_]+)$').firstMatch(raw);
  if (match != null && match.end == raw.length) return match.group(1);
  final uri = Uri.tryParse(raw);
  if (uri == null ||
      uri.scheme != 'healthpocket' ||
      uri.host != 'pay' ||
      uri.queryParameters.length != 1) {
    return null;
  }
  final providerId = uri.queryParameters['providerId'];
  return providerId != null && RegExp(r'^[a-z0-9_]+$').hasMatch(providerId)
      ? providerId
      : null;
}

class DemoAuthorizationResult {
  const DemoAuthorizationResult(this.status, this.message, {this.reference});
  final DemoAuthorizationStatus status;
  final String message;
  final String? reference;
}

/// Temporary design state only. It never touches savings or contribution data.
class DemoAuthorizationSession {
  DemoAuthorizationSession({
    required List<CareProvider> providers,
    required this.selectedProviderId,
    required this.amountKobo,
  }) : providers = List.unmodifiable(providers) {
    if (amountKobo <= 0 || amountKobo > 100000000) {
      throw ArgumentError('Invalid amount');
    }
    selectedProvider;
  }

  final List<CareProvider> providers;
  final String selectedProviderId;
  final int amountKobo;
  DemoAuthorizationResult? _result;
  DemoAuthorizationResult? get result => _result;
  CareProvider get selectedProvider => providers.firstWhere(
        (provider) => provider.id == selectedProviderId && provider.isDemo,
      );

  DemoAuthorizationResult resolve(String raw) {
    if (_result != null) return _result!;
    final scannedId = parseDemoProviderQr(raw);
    final scanned = providers
        .where((provider) => provider.id == scannedId && provider.isDemo)
        .firstOrNull;
    String? rejection;
    if (scannedId == null) {
      rejection = 'This is not a valid HealthPocket demo QR code.';
    } else if (scanned == null) {
      rejection = 'This provider was not found in the demo directory.';
    } else if (!scanned.active || !selectedProvider.active) {
      rejection = 'This demo provider is inactive. Choose an active centre.';
    } else if (!scanned.isPartner || !selectedProvider.isPartner) {
      rejection = 'This QR is not linked to a valid HealthPocket partner.';
    } else if (scannedId != selectedProviderId) {
      rejection =
          'QR code mismatch. This code belongs to another HealthPocket partner.';
    }
    return _result = rejection != null
        ? DemoAuthorizationResult(DemoAuthorizationStatus.rejected, rejection)
        : DemoAuthorizationResult(
            DemoAuthorizationStatus.created,
            'Demo authorization created',
            reference: 'DEMO-${List.generate(8, (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0')).join()}',
          );
  }

  DemoAuthorizationResult cancel() => _result ??=
      const DemoAuthorizationResult(
        DemoAuthorizationStatus.cancelled,
        'Demo scan cancelled. No authorization was created.',
      );

  void clear() => _result = null;
}
