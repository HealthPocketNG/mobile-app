enum CareRequestStatus {
  requested,
  authorized,
  careApproved,
  serviceCompleted,
  pendingSettlement,
  settled,
  cancelled,
}

extension CareStatusLabel on CareRequestStatus {
  String get label => switch (this) {
    CareRequestStatus.requested => 'Requested',
    CareRequestStatus.authorized => 'Authorized',
    CareRequestStatus.careApproved => 'Care approved',
    CareRequestStatus.serviceCompleted => 'Service completed',
    CareRequestStatus.pendingSettlement => 'Pending settlement',
    CareRequestStatus.settled => 'Settled',
    CareRequestStatus.cancelled => 'Cancelled',
  };
}

String? parseDemoProviderQr(String raw) {
  // A QR is a provider identifier only, never an executable URL or authorization.
  if (!RegExp(r'^healthpocket-demo:provider:demo-[a-z]+$').hasMatch(raw)) {
    return null;
  }
  return raw.substring('healthpocket-demo:provider:'.length);
}

int? parseCareAmount(String raw) {
  if (!RegExp(r'^\d{1,7}(\.\d{1,2})?$').hasMatch(raw.trim())) return null;
  final parts = raw.trim().split('.');
  final kobo =
      int.parse(parts[0]) * 100 +
      (parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0);
  return kobo > 0 && kobo <= 100000000 ? kobo : null;
}

class DemoCareRequest {
  DemoCareRequest({
    required this.id,
    required this.providerName,
    required this.amountKobo,
  });
  final String id, providerName;
  final int amountKobo;
  CareRequestStatus get status => _events.last.$1;
  final List<(CareRequestStatus, DateTime)> _events = [
    (CareRequestStatus.requested, DateTime.now()),
  ];
  List<(CareRequestStatus, DateTime)> get events => List.unmodifiable(_events);
  void advance(CareRequestStatus expected) {
    if (status != expected || status.index >= CareRequestStatus.settled.index) {
      throw StateError('Invalid or stale transition');
    }
    _events.add((CareRequestStatus.values[status.index + 1], DateTime.now()));
  }

  void cancel() {
    if (status != CareRequestStatus.requested) {
      throw StateError('Only pending requests can be cancelled');
    }
    _events.add((CareRequestStatus.cancelled, DateTime.now()));
  }
}
