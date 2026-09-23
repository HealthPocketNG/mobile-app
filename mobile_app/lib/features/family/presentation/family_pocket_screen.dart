import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:healthpocket/core/theme/app_colors.dart';
import 'package:healthpocket/core/theme/app_spacing.dart';
import 'package:healthpocket/core/widgets/app_bottom_navigation.dart';
import 'package:healthpocket/core/widgets/app_primary_button.dart';
import 'package:healthpocket/features/contributions/domain/contribution_record.dart';
import 'package:healthpocket/features/family/application/family_pocket_store.dart';
import 'package:healthpocket/features/family/domain/family_pocket.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

typedef CreateFamilyPocket = Future<void> Function({required String name});
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
    this.onRefresh,
    this.developmentContributionsEnabled = true,
  });

  final FamilyPocketStore store;
  final CreateFamilyPocket? onCreatePocket;
  final InviteFamilyMember? onInviteMember;
  final RespondToFamilyInvitation? onRespondToInvitation;
  final Future<void> Function(FamilyInvitation invitation)? onCancelInvitation;
  final Future<void> Function(String memberId)? onRemoveMember;
  final Future<void> Function(int amountNaira)? onRecordDevelopmentContribution;
  final Future<void> Function()? onRefresh;
  final bool developmentContributionsEnabled;

  @override
  State<FamilyPocketScreen> createState() => _FamilyPocketScreenState();
}

class _FamilyPocketScreenState extends State<FamilyPocketScreen> {
  bool _submitting = false;
  bool _showInvites = false;
  bool _showPocketDetails = false;

  FamilyPocketStore get store => widget.store;

  Future<void> _runAction(
    BuildContext context,
    Future<void> Function() action, {
    String? successMessage,
  }) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await action();
      if (successMessage != null && context.mounted) {
        _showMessage(context, successMessage);
      }
    } catch (_) {
      if (context.mounted) {
        _showMessage(
          context,
          'That change could not be saved. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _createPocket(BuildContext context) async {
    final draft = await showModalBottomSheet<_PocketDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const _CreatePocketSheet(),
    );
    if (draft == null || !context.mounted) return;
    await _runAction(context, () async {
      final create = widget.onCreatePocket;
      if (create == null) {
        store.createPocket(name: draft.name);
      } else {
        await create(name: draft.name);
      }
    }, successMessage: 'Family Pocket created');
  }

  Future<void> _inviteMember(BuildContext context) async {
    final invite = await showModalBottomSheet<_InviteDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const _InviteMemberSheet(),
    );
    if (invite == null || !context.mounted) return;
    await _runAction(context, () async {
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
    if (mounted) {
      setState(() => _showPocketDetails = true);
    }
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

  Future<void> _respondToInvitation(
    BuildContext context,
    FamilyInvitation invitation, {
    required bool accept,
  }) async {
    await _runAction(context, () async {
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, child) {
        final pocket = store.selectedPocket;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Family Pocket'),
            actions: [
              IconButton(
                onPressed: () => _createPocket(context),
                icon: const Icon(Icons.add_circle_outline_rounded),
                tooltip: 'Create Family Pocket',
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
          ),
          body: pocket == null
              ? store.loadStatus == FamilyPocketLoadStatus.loading
                    ? const Center(child: CircularProgressIndicator())
                    : _EmptyPocketView(
                        onCreate: () => _createPocket(context),
                        invitations: store.receivedInvitations,
                        submitting: _submitting,
                        onRespond: (invitation, accept) => _respondToInvitation(
                          context,
                          invitation,
                          accept: accept,
                        ),
                        loadFailed:
                            store.loadStatus == FamilyPocketLoadStatus.failure,
                        onRetry: widget.onRefresh == null
                            ? null
                            : () => _refresh(context),
                      )
              : RefreshIndicator(
                  onRefresh: () => _refresh(context),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      AppSpacing.xl,
                    ),
                    children: [
                      if (!_showPocketDetails) ...[
                      Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Family Pocket', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                          const Text('Save together. Go further.', style: TextStyle(color: AppColors.inkMuted)),
                        ])),
                        TextButton(
                          onPressed: store.canManageMembers && !_submitting ? () => _inviteMember(context) : null,
                          child: const Text('Invite'),
                        ),
                        Material(color: AppColors.primarySoft, shape: const CircleBorder(), child: IconButton(onPressed: () => _createPocket(context), icon: const Icon(LucideIcons.plus, color: AppColors.primary))),
                      ]),
                      const SizedBox(height: AppSpacing.md),
                      if (!widget.developmentContributionsEnabled)
                        const Padding(
                          padding: EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Text(
                            'Shared funding is not enabled',
                            style: TextStyle(color: AppColors.inkMuted, fontSize: 12),
                          ),
                        ),
                      _FamilySummaryCard(totalBalanceKobo: store.totalBalanceKobo, pocketCount: store.pockets.length),
                      const SizedBox(height: AppSpacing.lg),
                      Row(children: [
                        _PocketTab(label: 'My Pockets', selected: !_showInvites, onTap: () => setState(() => _showInvites = false)),
                        const SizedBox(width: AppSpacing.lg),
                        _PocketTab(label: 'Invites', selected: _showInvites, onTap: () => setState(() => _showInvites = true)),
                      ]),
                      const SizedBox(height: AppSpacing.md),
                      if (_showInvites) ...[
                        if (store.receivedInvitations.isEmpty)
                          const _NoPendingInvites()
                        else
                          ...store.receivedInvitations.map((invitation) => _ReceivedInvitationCard(invitation: invitation, submitting: _submitting, onAccept: () => _respondToInvitation(context, invitation, accept: true), onDecline: () => _respondToInvitation(context, invitation, accept: false))),
                        const SizedBox(height: AppSpacing.lg),
                      ] else ...[
                        SizedBox(
                          height: 154,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: store.pockets.length,
                            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
                            itemBuilder: (context, index) {
                              final item = store.pockets[index];
                              return SizedBox(
                                width: 252,
                                child: _PocketOverviewCard(
                                  pocket: item,
                                  balanceKobo: store.balanceForPocketKobo(item.id),
                                  selected: item.id == pocket.id,
                                  onTap: () {
                                    store.selectPocket(item.id);
                                    setState(() => _showPocketDetails = true);
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _StartPocketCard(onTap: () => _createPocket(context)),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      ],
                      if (_showPocketDetails) ...[
                        Row(
                          children: [
                            IconButton(
                              tooltip: 'Back to pockets',
                              onPressed: () => setState(() => _showPocketDetails = false),
                              icon: const Icon(LucideIcons.arrowLeft),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                pocket.name,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      if (store.receivedInvitations.isNotEmpty) ...[
                        const _SectionHeader(title: 'Pending invitations'),
                        const SizedBox(height: AppSpacing.sm),
                        ...store.receivedInvitations.map(
                          (invitation) => _ReceivedInvitationCard(
                            invitation: invitation,
                            submitting: _submitting,
                            onAccept: () => _respondToInvitation(
                              context,
                              invitation,
                              accept: true,
                            ),
                            onDecline: () => _respondToInvitation(
                              context,
                              invitation,
                              accept: false,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      if (store.pockets.length > 1) ...[
                        DropdownButtonFormField<String>(
                          key: ValueKey(pocket.id),
                          initialValue: pocket.id,
                          decoration: const InputDecoration(
                            labelText: 'Selected pocket',
                            prefixIcon: Icon(Icons.groups_2_outlined),
                          ),
                          items: store.pockets
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item.id,
                                  child: Text(item.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) store.selectPocket(value);
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      _PocketHero(
                        pocket: pocket,
                        balanceKobo: store.selectedBalanceKobo,
                        developmentContributionsEnabled:
                            widget.developmentContributionsEnabled,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: _PocketAction(
                              icon: Icons.person_add_alt_1_outlined,
                              label: 'Invite',
                              onTap: store.canManageMembers && !_submitting
                                  ? () => _inviteMember(context)
                                  : null,
                            ),
                          ),
                          if (widget.developmentContributionsEnabled) ...[
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: _PocketAction(
                                icon: Icons.add_card_outlined,
                                label: 'Dev record',
                                onTap: _submitting || !store.canContribute
                                    ? null
                                    : () => _recordContribution(context),
                              ),
                            ),
                          ],
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _PocketAction(
                              icon: Icons.add_home_work_outlined,
                              label: 'New pocket',
                              onTap: _submitting
                                  ? null
                                  : () => _createPocket(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      _SectionHeader(
                        title: 'Members',
                        action: '${pocket.members.length}',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Material(
                        color: AppColors.surface,
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: const BorderSide(color: AppColors.outline),
                        ),
                        child: Column(
                          children: [
                            for (
                              var index = 0;
                              index < pocket.members.length;
                              index++
                            ) ...[
                              _MemberTile(
                                member: pocket.members[index],
                                canRemove:
                                    store.canManageMembers &&
                                    pocket.members[index].role !=
                                        FamilyRole.admin,
                                onRemove: () => _removeMember(
                                  context,
                                  pocket.members[index],
                                ),
                              ),
                              if (index != pocket.members.length - 1)
                                const Divider(height: 1, indent: 68),
                            ],
                          ],
                        ),
                      ),
                      if (store.canManageMembers &&
                          pocket.invitations.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xl),
                        _SectionHeader(
                          title: 'Invitations',
                          action:
                              '${pocket.invitations.where((item) => item.effectiveStatus == FamilyInvitationStatus.pending).length} pending',
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        ...pocket.invitations.map(
                          (invitation) => _AdminInvitationTile(
                            invitation: invitation,
                            onCancel:
                                !_submitting &&
                                    invitation.status ==
                                        FamilyInvitationStatus.pending
                                ? () => _cancelInvitation(context, invitation)
                                : null,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      const _SectionHeader(
                        title: 'Shared contribution history',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (store.selectedContributions.isEmpty)
                        const _EmptyActivity()
                      else
                        ...store.selectedContributions.map(
                          (item) => _FamilyContributionTile(contribution: item),
                        ),
                      ],
                    ],
                  ),
                ),
          bottomNavigationBar: const AppBottomNavigation(currentIndex: 4),
        );
      },
    );
  }
}

class _FamilySummaryCard extends StatelessWidget {
  const _FamilySummaryCard({required this.totalBalanceKobo, required this.pocketCount});
  final int totalBalanceKobo;
  final int pocketCount;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF09A99F), AppColors.primaryDark]), borderRadius: BorderRadius.circular(20)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Total Family Savings', style: TextStyle(color: Colors.white70)),
      const SizedBox(height: 5),
      Text(_formatKobo(totalBalanceKobo), style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
      const SizedBox(height: 3),
      Text('Across $pocketCount ${pocketCount == 1 ? 'pocket' : 'pockets'}', style: const TextStyle(color: Colors.white70)),
    ]),
  );
}

class _PocketTab extends StatelessWidget {
  const _PocketTab({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.only(bottom: 8), child: Column(mainAxisSize: MainAxisSize.min, children: [
    Text(label, style: TextStyle(fontWeight: FontWeight.w800, color: selected ? AppColors.primary : AppColors.inkMuted)),
    const SizedBox(height: 6),
    Container(height: 2, width: 72, color: selected ? AppColors.primary : Colors.transparent),
  ])));
}

class _PocketOverviewCard extends StatelessWidget {
  const _PocketOverviewCard({required this.pocket, required this.balanceKobo, required this.selected, required this.onTap});
  final FamilyPocket pocket;
  final int balanceKobo;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    child: Material(color: AppColors.surface, borderRadius: BorderRadius.circular(16), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
      const CircleAvatar(radius: 24, backgroundColor: AppColors.primarySoft, child: Icon(LucideIcons.usersRound, color: AppColors.primary)),
      const SizedBox(width: 12),
      Expanded(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(pocket.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        Text('${pocket.members.length} ${pocket.members.length == 1 ? 'member' : 'members'}', style: const TextStyle(color: AppColors.inkMuted, fontSize: 12)),
      ])),
      Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(_formatKobo(balanceKobo), style: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Icon(LucideIcons.chevronRight, color: selected ? AppColors.primary : AppColors.inkMuted, size: 18),
      ]),
    ])))),
  );
}

class _StartPocketCard extends StatelessWidget {
  const _StartPocketCard({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(16), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: const Padding(padding: EdgeInsets.all(16), child: Row(children: [
    CircleAvatar(backgroundColor: Colors.white, child: Icon(LucideIcons.plus, color: AppColors.primary)),
    SizedBox(width: 12),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Start a new Pocket', style: TextStyle(fontWeight: FontWeight.w800)), Text('Create a pocket for your family, friends or loved ones.', style: TextStyle(color: AppColors.inkMuted, fontSize: 12))])),
  ]))));
}

class _NoPendingInvites extends StatelessWidget {
  const _NoPendingInvites();
  @override
  Widget build(BuildContext context) => const Padding(padding: EdgeInsets.symmetric(vertical: 28), child: Center(child: Text('No pending invites', style: TextStyle(color: AppColors.inkMuted))));
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

class _PocketHero extends StatelessWidget {
  const _PocketHero({
    required this.pocket,
    required this.balanceKobo,
    required this.developmentContributionsEnabled,
  });

  final FamilyPocket pocket;
  final int balanceKobo;
  final bool developmentContributionsEnabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A8B7D), AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white12,
                child: Icon(Icons.groups_2_rounded, color: Colors.white),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pocket.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${pocket.reservedBeneficiaryCount} of ${pocket.beneficiaryLimit} beneficiary slots reserved',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            developmentContributionsEnabled
                ? 'Development shared balance'
                : 'Shared funding is not enabled',
            style: const TextStyle(color: Colors.white70),
          ),
          Text(
            _formatKobo(balanceKobo),
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (developmentContributionsEnabled)
            const Text(
              'Simulated records only — no money moved.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          Text(
            '${pocket.members.length} members building health security together',
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _PocketAction extends StatelessWidget {
  const _PocketAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onTap == null ? AppColors.surfaceMuted : AppColors.surface,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.outline),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: onTap == null ? AppColors.inkMuted : AppColors.primary,
                size: 22,
              ),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action});

  final String title;
  final String? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        if (action != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              action!,
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.canRemove,
    required this.onRemove,
  });

  final FamilyMember member;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final initials = member.name
        .trim()
        .split(RegExp(r'\s+'))
        .take(2)
        .map((part) => part.isEmpty ? '' : part[0].toUpperCase())
        .join();
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: member.isBeneficiary
            ? AppColors.secondarySoft
            : AppColors.primarySoft,
        child: Text(
          initials,
          style: const TextStyle(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      title: Text(member.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(_memberCapabilities(member)),
      trailing: member.role == FamilyRole.admin
          ? const Icon(Icons.shield_outlined, color: AppColors.accent)
          : canRemove
          ? IconButton(
              key: ValueKey('remove-member-${member.id}'),
              onPressed: onRemove,
              icon: const Icon(Icons.person_remove_outlined),
              color: AppColors.error,
              tooltip: 'Remove ${member.name}',
            )
          : null,
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

class _AdminInvitationTile extends StatelessWidget {
  const _AdminInvitationTile({
    required this.invitation,
    required this.onCancel,
  });

  final FamilyInvitation invitation;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final status = invitation.effectiveStatus;
    return Material(
      color: AppColors.surface,
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: AppColors.primarySoft,
          child: Icon(Icons.mail_outline, color: AppColors.primary),
        ),
        title: Text(invitation.inviteeName),
        subtitle: Text(
          '${_invitationCapabilities(invitation)} • ${_invitationStatusLabel(status)}',
        ),
        trailing: onCancel == null
            ? null
            : TextButton(onPressed: onCancel, child: const Text('Cancel')),
      ),
    );
  }
}

class _FamilyContributionTile extends StatelessWidget {
  const _FamilyContributionTile({required this.contribution});

  final ContributionRecord contribution;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(
        backgroundColor: AppColors.primarySoft,
        child: Icon(Icons.south_west_rounded, color: AppColors.primary),
      ),
      title: Text(
        '${contribution.contributorName ?? 'Family member'} contributed',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text('${_dateLabel(contribution.createdAt)} • Demo record'),
      trailing: Text(
        '+${_formatKobo(contribution.amountKobo)}',
        style: const TextStyle(
          color: AppColors.success,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyActivity extends StatelessWidget {
  const _EmptyActivity();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Text(
        'No shared contributions yet. Start this pocket together.',
      ),
    );
  }
}

class _CreatePocketSheet extends StatefulWidget {
  const _CreatePocketSheet();

  @override
  State<_CreatePocketSheet> createState() => _CreatePocketSheetState();
}

class _CreatePocketSheetState extends State<_CreatePocketSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
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
            _sheetTitle(context, 'Create Family Pocket'),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Family Pockets build an ongoing shared balance without a target.',
              style: TextStyle(color: AppColors.inkMuted),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Pocket name'),
              validator: _required,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppPrimaryButton(
              label: 'Create pocket',
              onPressed: () {
                if (!_formKey.currentState!.validate()) return;
                Navigator.pop(
                  context,
                  _PocketDraft(name: _nameController.text.trim()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteMemberSheet extends StatefulWidget {
  const _InviteMemberSheet();

  @override
  State<_InviteMemberSheet> createState() => _InviteMemberSheetState();
}

class _InviteMemberSheetState extends State<_InviteMemberSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
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

class _PocketDraft {
  const _PocketDraft({required this.name});

  final String name;
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

String _memberCapabilities(FamilyMember member) {
  if (member.role == FamilyRole.admin) return 'Admin • Can contribute';
  if (member.canContribute && member.isBeneficiary) {
    return 'Contributor • Beneficiary';
  }
  if (member.canContribute) return 'Contributor';
  return 'Beneficiary';
}

String _invitationCapabilities(FamilyInvitation invitation) {
  if (invitation.canContribute && invitation.isBeneficiary) {
    return 'Contributor and beneficiary';
  }
  if (invitation.canContribute) return 'Contributor';
  return 'Beneficiary';
}

String _invitationStatusLabel(FamilyInvitationStatus status) =>
    switch (status) {
      FamilyInvitationStatus.pending => 'Pending',
      FamilyInvitationStatus.accepted => 'Accepted',
      FamilyInvitationStatus.declined => 'Declined',
      FamilyInvitationStatus.cancelled => 'Cancelled',
      FamilyInvitationStatus.expired => 'Expired',
    };

String _naira(int amount) {
  final value = amount.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => ',',
  );
  return '₦$value';
}

String _formatKobo(int amountKobo) {
  final whole = _naira(amountKobo ~/ 100);
  final kobo = amountKobo.remainder(100).abs();
  return kobo == 0 ? whole : '$whole.${kobo.toString().padLeft(2, '0')}';
}

String _dateLabel(DateTime? date) {
  if (date == null) return 'Saving…';
  final now = DateTime.now();
  final days = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(date.year, date.month, date.day)).inDays;
  if (days == 0) return 'Today';
  if (days == 1) return 'Yesterday';
  return '$days days ago';
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
