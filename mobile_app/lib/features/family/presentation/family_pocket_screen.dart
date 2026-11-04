import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:healthpocket/core/theme/app_colors.dart';
import 'package:healthpocket/core/theme/app_spacing.dart';
import 'package:healthpocket/core/widgets/app_bottom_navigation.dart';
import 'package:healthpocket/core/widgets/app_primary_button.dart';
import 'package:healthpocket/features/family/application/family_pocket_store.dart';
import 'package:healthpocket/features/family/domain/family_pocket.dart';
import 'package:healthpocket/features/family/presentation/family_v2_screens.dart';
import 'package:healthpocket/features/family/presentation/family_v2_details.dart';
import 'package:healthpocket/features/family/presentation/family_v2_invites.dart';

typedef CreateFamilyPocket = Future<void> Function({
  required String name,
  String? description,
  FamilyContributionFrequency frequency,
  int defaultContributionAmountKobo,
});
typedef InviteFamilyMember = Future<void> Function({
  required String name,
  required String email,
  required bool canContribute,
  required bool isBeneficiary,
});
typedef RespondToFamilyInvitation = Future<void> Function(
  FamilyInvitation invitation, {
  required bool accept,
});

class FamilyPocketScreen extends StatefulWidget {
  const FamilyPocketScreen({
    required this.store,
    super.key,
    this.onCreatePocket,
    this.onInviteMember,
    this.onRespondToInvitation,
    this.onCancelInvitation,
    this.onRemoveMember,
    this.onRecordDevelopmentContribution,
    this.onUpdatePocket,
    this.onLeavePocket,
    this.onRefresh,
    this.developmentContributionsEnabled = true,
    this.designPreview = false,
  });

  final FamilyPocketStore store;
  final CreateFamilyPocket? onCreatePocket;
  final InviteFamilyMember? onInviteMember;
  final RespondToFamilyInvitation? onRespondToInvitation;
  final Future<void> Function(FamilyInvitation invitation)? onCancelInvitation;
  final Future<void> Function(String memberId)? onRemoveMember;
  final Future<void> Function(int amountNaira)? onRecordDevelopmentContribution;
  final Future<void> Function({
    String? name,
    FamilyContributionFrequency? frequency,
    int? defaultContributionAmountKobo,
  })?
  onUpdatePocket;
  final Future<void> Function()? onLeavePocket;
  final Future<void> Function()? onRefresh;
  final bool developmentContributionsEnabled;
  final bool designPreview;

  @override
  State<FamilyPocketScreen> createState() => _FamilyPocketScreenState();
}

class _FamilyPocketScreenState extends State<FamilyPocketScreen> {
  bool _submitting = false;
  bool _showInvites = false;
  bool _showPocketDetails = false;

  FamilyPocketStore get store => widget.store;

  Future<bool> _runAction(
    BuildContext context,
    Future<void> Function() action, {
    String? successMessage,
  }) async {
    if (_submitting) return false;
    setState(() => _submitting = true);
    try {
      await action();
      if (successMessage != null && context.mounted) {
        _showMessage(context, successMessage);
      }
      return true;
    } catch (_) {
      if (context.mounted) {
        _showMessage(
          context,
          'That change could not be saved. Check your connection and try again.',
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _createPocket(BuildContext context) async {
    final draft = await Navigator.of(context).push<FamilyPocketDraft>(
      MaterialPageRoute(builder: (_) => const FamilyCreatePocketV2()),
    );
    if (draft == null || !context.mounted) return;
    final created = await _runAction(context, () async {
      final create = widget.onCreatePocket;
      if (create == null) {
        store.createPocket(
          name: draft.name,
          description: draft.description,
          frequency: draft.frequency,
          defaultContributionAmountKobo: draft.defaultAmountKobo,
        );
      } else {
        await create(
          name: draft.name,
          description: draft.description,
          frequency: draft.frequency,
          defaultContributionAmountKobo: draft.defaultAmountKobo,
        );
      }
    });
    if (!created || !context.mounted || store.selectedPocket == null) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (contactsContext) => FamilyContactsV2(
          onContinue: () => _openInviteMembers(contactsContext),
        ),
      ),
    );
  }

  Future<bool> _inviteMember(
    BuildContext context, {
    String initialName = '',
    bool showDetailsAfter = true,
  }) async {
    final invite = await showModalBottomSheet<_InviteDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _InviteMemberSheet(initialName: initialName),
    );
    if (invite == null || !context.mounted) return false;
    final recorded = await _runAction(context, () async {
      final persistInvite = widget.onInviteMember;
      if (persistInvite == null) {
        final invited = store.inviteMember(
          name: invite.name,
          email: invite.email,
          canContribute: invite.canContribute,
          isBeneficiary: invite.isBeneficiary,
        );
        if (!invited) throw StateError('Not a Family Pocket admin.');
      } else {
        await persistInvite(
          name: invite.name,
          email: invite.email,
          canContribute: invite.canContribute,
          isBeneficiary: invite.isBeneficiary,
        );
      }
    }, successMessage: 'Invitation recorded');
    if (recorded && mounted && showDetailsAfter) {
      setState(() => _showPocketDetails = true);
    }
    return recorded;
  }

  void _openInviteMembers(BuildContext context) {
    final pocket = store.selectedPocket;
    if (pocket == null) return;
    Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute(
        builder: (inviteContext) => FamilyInviteMembersV2(
          pocket: pocket,
          showSampleContacts: widget.designPreview,
          onInvite: (name) => _inviteMember(
            inviteContext,
            initialName: name,
            showDetailsAfter: false,
          ),
          onDone: () => _showSuccess(inviteContext),
          onSkip: () => _showSuccess(inviteContext),
          onShareLink: () => showModalBottomSheet<void>(
            context: inviteContext,
            isScrollControlled: true,
            backgroundColor: Colors.white,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            builder: (_) => const FamilyShareInviteSheetV2(),
          ),
        ),
      ),
    );
  }

  void _showSuccess(BuildContext context) {
    final pocket = store.selectedPocket;
    if (pocket == null) return;
    Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute(
        builder: (successContext) => FamilyPocketSuccessV2(
          pocket: pocket,
          onInviteMore: () => _openInviteMembers(successContext),
          onGoToPocket: () {
            if (mounted) setState(() => _showPocketDetails = true);
            Navigator.of(successContext).popUntil(
              (route) =>
                  route.settings.name == '/family-pocket' || route.isFirst,
            );
          },
        ),
      ),
    );
  }

  Future<void> _recordContribution(BuildContext context) async {
    final pocket = store.selectedPocket;
    if (pocket == null) return;
    final amount = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _FamilyContributionSheet(pocketName: pocket.name),
    );
    if (amount == null || !context.mounted) return;
    await _runAction(context, () async {
      final persistContribution = widget.onRecordDevelopmentContribution;
      if (persistContribution == null) {
        store.recordContribution(amount);
      } else {
        await persistContribution(amount);
      }
    }, successMessage: 'Development contribution recorded — no money moved');
  }

  Future<void> _removeMember(BuildContext context, FamilyMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove family member?'),
        content: Text(
          '${member.name} will lose access to this Family Pocket. Their previous contributions will remain in the history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove member'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _runAction(context, () async {
      final remove = widget.onRemoveMember;
      if (remove == null) {
        if (!store.removeMember(member.id)) {
          throw StateError('Member cannot be removed.');
        }
      } else {
        await remove(member.id);
      }
    }, successMessage: '${member.name} was removed.');
  }

  Future<bool> _respondToInvitation(
    BuildContext context,
    FamilyInvitation invitation, {
    required bool accept,
  }) async {
    return _runAction(context, () async {
      final respond = widget.onRespondToInvitation;
      if (respond == null) {
        if (!store.respondToInvitation(invitation.id, accept: accept)) {
          throw StateError('Invitation is no longer pending.');
        }
      } else {
        await respond(invitation, accept: accept);
      }
    }, successMessage: accept ? 'Family Pocket joined' : 'Invitation declined');
  }

  void _openInvitation(BuildContext context, FamilyInvitation invitation) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (routeContext) => FamilyInvitedV2(
          invitation: invitation,
          onRespond: (accept) async {
            final completed = await _respondToInvitation(
              routeContext,
              invitation,
              accept: accept,
            );
            if (completed && mounted) {
              setState(() => _showInvites = !accept);
            }
            return completed;
          },
        ),
      ),
    );
  }

  Future<void> _cancelInvitation(
    BuildContext context,
    FamilyInvitation invitation,
  ) async {
    await _runAction(context, () async {
      final cancel = widget.onCancelInvitation;
      if (cancel == null) {
        if (!store.cancelInvitation(invitation.id)) {
          throw StateError('Invitation is no longer pending.');
        }
      } else {
        await cancel(invitation);
      }
    }, successMessage: 'Invitation cancelled');
  }

  Future<void> _refresh(BuildContext context) async {
    final refresh = widget.onRefresh;
    if (refresh == null) return;
    try {
      await refresh();
    } catch (_) {
      if (context.mounted) {
        _showMessage(context, 'Family Pocket updates could not be refreshed.');
      }
    }
  }

  Future<bool> _updatePocket(
    BuildContext context, {
    String? name,
    FamilyContributionFrequency? frequency,
    int? defaultContributionAmountKobo,
  }) => _runAction(context, () async {
    final update = widget.onUpdatePocket;
    if (update == null) {
      store.updateSelectedPocket(
        name: name,
        frequency: frequency,
        defaultContributionAmountKobo: defaultContributionAmountKobo,
      );
    } else {
      await update(
        name: name,
        frequency: frequency,
        defaultContributionAmountKobo: defaultContributionAmountKobo,
      );
    }
  }, successMessage: 'Pocket updated');

  Future<bool> _leavePocket(BuildContext context) async {
    final left = await _runAction(context, () async {
      final leave = widget.onLeavePocket;
      if (leave == null) {
        store.leaveSelectedPocket();
      } else {
        await leave();
      }
    });
    if (left && mounted) setState(() => _showPocketDetails = false);
    return left;
  }

  void _openMembers(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (routeContext) => AnimatedBuilder(
          animation: store,
          builder: (context, _) {
            final pocket = store.selectedPocket;
            if (pocket == null) {
              return const Scaffold(
                body: Center(child: Text('Pocket unavailable')),
              );
            }
            return FamilyMembersV2(
              pocket: pocket,
              contributions: store.selectedContributions,
              currentUserId: store.currentUserId,
              canManage: store.canManageMembers,
              onInvite: () =>
                  _inviteMember(routeContext, showDetailsAfter: false),
              onRemove: (member) => _removeMember(routeContext, member),
            );
          },
        ),
      ),
    );
  }

  void _openManage(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (routeContext) => AnimatedBuilder(
          animation: store,
          builder: (context, _) {
            final pocket = store.selectedPocket;
            if (pocket == null) {
              return const Scaffold(
                body: Center(child: Text('Pocket unavailable')),
              );
            }
            return FamilyManagePocketV2(
              pocket: pocket,
              canManage: store.canManageMembers,
              canLeave: pocket.members.any(
                (member) =>
                    member.id == store.currentUserId &&
                    member.role != FamilyRole.owner,
              ),
              onUpdate: ({name, frequency, defaultContributionAmountKobo}) =>
                  _updatePocket(
                    routeContext,
                    name: name,
                    frequency: frequency,
                    defaultContributionAmountKobo:
                        defaultContributionAmountKobo,
                  ),
              onMembers: () => _openMembers(routeContext),
              onLeave: () => _leavePocket(routeContext),
              onCancelInvitation: (invitation) =>
                  _cancelInvitation(routeContext, invitation),
            );
          },
        ),
      ),
    );
  }

  void _openActivity(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            FamilyActivityV2(contributions: store.selectedContributions),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, child) {
        final pocket = store.selectedPocket;
        return Scaffold(
          body:
              pocket == null &&
                  store.loadStatus == FamilyPocketLoadStatus.loading
              ? const Center(child: CircularProgressIndicator())
              : pocket == null &&
                    store.loadStatus == FamilyPocketLoadStatus.failure
              ? _EmptyPocketView(
                  onCreate: () => _createPocket(context),
                  invitations: store.receivedInvitations,
                  submitting: _submitting,
                  onRespond: (invitation, accept) =>
                      _respondToInvitation(context, invitation, accept: accept),
                  loadFailed: true,
                  onRetry: widget.onRefresh == null
                      ? null
                      : () => _refresh(context),
                )
              : SafeArea(
                  top: true,
                  bottom: false,
                  child: RefreshIndicator(
                    onRefresh: () => _refresh(context),
                    child: ListView(
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      children: [
                        if (!_showPocketDetails)
                          FamilyPocketOverviewV2(
                            pockets: store.pockets,
                            totalBalanceKobo: store.totalBalanceKobo,
                            balanceForPocketKobo: store.balanceForPocketKobo,
                            invitations: store.receivedInvitations,
                            showInvites: _showInvites,
                            onTabChanged: (value) =>
                                setState(() => _showInvites = value),
                            onCreate: () => _createPocket(context),
                            onPocketTap: (item) {
                              store.selectPocket(item.id);
                              setState(() => _showPocketDetails = true);
                            },
                            onInvitationResponse: (invitation, accept) =>
                                _respondToInvitation(
                                  context,
                                  invitation,
                                  accept: accept,
                                ),
                            onInvitationTap: (invitation) =>
                                _openInvitation(context, invitation),
                            submitting: _submitting,
                            developmentContributionsEnabled:
                                widget.developmentContributionsEnabled,
                          ),
                        if (_showPocketDetails && pocket != null)
                          FamilyPocketDetailsV2(
                            pocket: pocket,
                            balanceKobo: widget.developmentContributionsEnabled
                                ? store.selectedBalanceKobo
                                : pocket.balanceKobo,
                            contributions: store.selectedContributions,
                            currentUserId: store.currentUserId,
                            onBack: () =>
                                setState(() => _showPocketDetails = false),
                            onManage: () => _openManage(context),
                            onMembers: () => _openMembers(context),
                            onInvite: () {
                              if (store.canManageMembers && !_submitting) {
                                _inviteMember(context);
                              } else {
                                _showMessage(
                                  context,
                                  'Only a pocket admin can invite members.',
                                );
                              }
                            },
                            onAddMoney: () {
                              if (widget.developmentContributionsEnabled &&
                                  store.canContribute &&
                                  !_submitting) {
                                _recordContribution(context);
                              } else {
                                _showMessage(
                                  context,
                                  'Family funding is not available yet.',
                                );
                              }
                            },
                            onSeeActivity: () => _openActivity(context),
                          ),
                      ],
                    ),
                  ),
                ),
          bottomNavigationBar: _showPocketDetails
              ? null
              : const AppBottomNavigation(
                  currentIndex: 0,
                  allowSelectedNavigation: true,
                  assetRootOverride: FamilyV2.assets,
                  iconFiles: [
                    'overview-197ef.svg',
                    'overview-23576.svg',
                    'overview-da4ca.svg',
                    'overview-8450b.svg',
                    'overview-1cb7b.svg',
                  ],
                ),
        );
      },
    );
  }
}

class _EmptyPocketView extends StatelessWidget {
  const _EmptyPocketView({
    required this.onCreate,
    required this.invitations,
    required this.submitting,
    required this.onRespond,
    required this.loadFailed,
    this.onRetry,
  });

  final VoidCallback onCreate;
  final List<FamilyInvitation> invitations;
  final bool submitting;
  final void Function(FamilyInvitation invitation, bool accept) onRespond;
  final bool loadFailed;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            if (invitations.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Pending invitations',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              ...invitations.map(
                (invitation) => _ReceivedInvitationCard(
                  invitation: invitation,
                  submitting: submitting,
                  onAccept: () => onRespond(invitation, true),
                  onDecline: () => onRespond(invitation, false),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
            const CircleAvatar(
              radius: 42,
              backgroundColor: AppColors.primarySoft,
              child: Icon(
                Icons.groups_2_outlined,
                color: AppColors.primary,
                size: 42,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Save together for family healthcare',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Create a shared pocket, invite family members, and build a shared health balance without a target.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.inkMuted),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (loadFailed) ...[
              const Text(
                'We could not load your Family Pockets. Your saved data has not been replaced.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.error),
              ),
              if (onRetry != null)
                TextButton(onPressed: onRetry, child: const Text('Retry')),
              const SizedBox(height: AppSpacing.sm),
            ],
            AppPrimaryButton(
              label: 'Create Family Pocket',
              onPressed: onCreate,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceivedInvitationCard extends StatelessWidget {
  const _ReceivedInvitationCard({
    required this.invitation,
    required this.submitting,
    required this.onAccept,
    required this.onDecline,
  });

  final FamilyInvitation invitation;
  final bool submitting;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            invitation.pocketName,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text('${invitation.inviterName} invited you to join this pocket.'),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _invitationCapabilities(invitation),
            style: const TextStyle(color: AppColors.inkMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: submitting ? null : onDecline,
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(
                  onPressed: submitting ? null : onAccept,
                  child: const Text('Accept invite'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InviteMemberSheet extends StatefulWidget {
  const _InviteMemberSheet({this.initialName = ''});

  final String initialName;

  @override
  State<_InviteMemberSheet> createState() => _InviteMemberSheetState();
}

class _InviteMemberSheetState extends State<_InviteMemberSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.initialName);
  final _emailController = TextEditingController();
  bool _canContribute = true;
  bool _isBeneficiary = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sheetTitle(context, 'Invite a family member'),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'This records a pending MVP invitation. No email is sent yet.',
              style: TextStyle(color: AppColors.inkMuted),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Full name'),
              validator: _required,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email address'),
              validator: (value) => value == null || !value.contains('@')
                  ? 'Enter a valid email address'
                  : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Can contribute'),
              subtitle: const Text('Can add funds to the shared pocket'),
              value: _canContribute,
              onChanged: (value) =>
                  setState(() => _canContribute = value ?? false),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Beneficiary'),
              subtitle: const Text(
                'Uses one of the two care beneficiary slots',
              ),
              value: _isBeneficiary,
              onChanged: (value) =>
                  setState(() => _isBeneficiary = value ?? false),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppPrimaryButton(
              label: 'Record invitation',
              onPressed: () {
                if (!_formKey.currentState!.validate()) return;
                if (!_canContribute && !_isBeneficiary) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Choose at least one permission for this family member.',
                      ),
                    ),
                  );
                  return;
                }
                Navigator.pop(
                  context,
                  _InviteDraft(
                    name: _nameController.text.trim(),
                    email: _emailController.text.trim(),
                    canContribute: _canContribute,
                    isBeneficiary: _isBeneficiary,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FamilyContributionSheet extends StatefulWidget {
  const _FamilyContributionSheet({required this.pocketName});

  final String pocketName;

  @override
  State<_FamilyContributionSheet> createState() =>
      _FamilyContributionSheetState();
}

class _FamilyContributionSheetState extends State<_FamilyContributionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sheetTitle(context, 'Contribute to ${widget.pocketName}'),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Development only—this records activity without moving money.',
              style: TextStyle(color: AppColors.inkMuted),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _amountController,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Contribution amount',
                prefixText: '₦ ',
              ),
              validator: _amountValidator,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppPrimaryButton(
              label: 'Record development contribution',
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  Navigator.pop(context, int.parse(_amountController.text));
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: child,
    );
  }
}

class _InviteDraft {
  const _InviteDraft({
    required this.name,
    required this.email,
    required this.canContribute,
    required this.isBeneficiary,
  });

  final String name;
  final String email;
  final bool canContribute;
  final bool isBeneficiary;
}

Widget _sheetTitle(BuildContext context, String title) => Text(
  title,
  style: Theme.of(context).textTheme.titleLarge
      ?.copyWith(fontWeight: FontWeight.w800),
);

String? _required(String? value) =>
    value == null || value.trim().isEmpty ? 'Required' : null;

String? _amountValidator(String? value) =>
    value == null || int.tryParse(value) == null || int.parse(value) < 100
    ? 'Enter an amount of at least ₦100'
    : null;

String _invitationCapabilities(FamilyInvitation invitation) {
  if (invitation.canContribute && invitation.isBeneficiary) {
    return 'Contributor and beneficiary';
  }
  if (invitation.canContribute) return 'Contributor';
  return 'Beneficiary';
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
