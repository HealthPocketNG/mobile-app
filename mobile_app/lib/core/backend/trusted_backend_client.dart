enum TrustedBackendAction {
  walletEnsure('wallet.ensure'),
  fundingInitialize('funding.initialize'),
  fundingVerify('funding.verify'),
  savingsCreate('savings.create'),
  savingsUpdate('savings.update'),
  savingsPause('savings.pause'),
  savingsResume('savings.resume'),
  savingsCancel('savings.cancel'),
  familyCreate('family.create'),
  familyUpdate('family.update'),
  familyInviteCreate('family.invite_create'),
  familyInviteResolve('family.invite_resolve'),
  familyInviteRespond('family.invite_respond'),
  familyMembershipChange('family.membership_change'),
  familyOwnershipTransfer('family.ownership_transfer'),
  familyClose('family.close'),
  familyContributionInitialize('family.contribution_initialize'),
  familyContributionVerify('family.contribution_verify'),
  healthcarePartnerInitialize('healthcare.partner_initialize'),
  healthcareNonPartnerInitialize('healthcare.non_partner_initialize'),
  healthcareVerify('healthcare.verify'),
  coverageEvaluate('coverage.evaluate'),
  notificationsList('notifications.list'),
  notificationsMarkRead('notifications.mark_read'),
  notificationsMarkAllRead('notifications.mark_all_read'),
  notificationsRegisterDevice('notifications.register_device'),
  notificationsRemoveDevice('notifications.remove_device'),
  notificationsRefreshDevice('notifications.refresh_device'),
  activityList('activity.list'),
  activityDetail('activity.detail'),
  activityStatement('activity.statement'),
  receiptGet('receipt.get'),
  receiptExport('receipt.export');

  const TrustedBackendAction(this.wireName);

  final String wireName;
}

/// Stable frontend boundary for authenticated backend commands.
///
/// Feature repositories depend on this contract instead of importing the
/// Cloud Functions SDK or repeating callable action strings.
abstract interface class TrustedBackendClient {
  Future<Map<String, dynamic>> call(
    TrustedBackendAction action, {
    Map<String, Object?> payload = const {},
  });
}

/// Callable requests carry dates as explicit UTC ISO-8601 strings.
String backendUtcDate(DateTime value) => value.toUtc().toIso8601String();
