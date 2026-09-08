import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:healthpocket/core/theme/app_colors.dart';
import 'package:healthpocket/core/theme/app_spacing.dart';
import 'package:healthpocket/core/widgets/app_bottom_navigation.dart';
import 'package:healthpocket/core/widgets/app_primary_button.dart';
import 'package:healthpocket/features/family/application/family_pocket_store.dart';
import 'package:healthpocket/features/family/domain/family_pocket.dart';

class FamilyPocketScreen extends StatelessWidget {
  const FamilyPocketScreen({required this.store, super.key});

  final FamilyPocketStore store;

  Future<void> _createPocket(BuildContext context) async {
    final draft = await showModalBottomSheet<_PocketDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const _CreatePocketSheet(),
    );
    if (draft == null) return;
    store.createPocket(name: draft.name, beneficiary: draft.beneficiary);
  }

  Future<void> _inviteMember(BuildContext context) async {
    final invite = await showModalBottomSheet<_InviteDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const _InviteMemberSheet(),
    );
    if (invite == null) return;
    final invited = store.inviteMember(
      name: invite.name,
      email: invite.email,
      role: invite.role,
    );
    if (!invited && context.mounted) {
      _showMessage(context, 'Only a Family Pocket admin can invite members.');
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
    if (amount != null) store.recordContribution(amount);
  }

  Future<void> _removeContributor(
    BuildContext context,
    FamilyMember member,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove contributor?'),
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
            child: const Text('Remove contributor'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final removed = store.removeContributor(member.id);
    if (context.mounted) {
      _showMessage(
        context,
        removed
            ? '${member.name} was removed.'
            : 'Only an admin can remove a contributor.',
      );
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
              ? _EmptyPocketView(onCreate: () => _createPocket(context))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.xl,
                  ),
                  children: [
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
                    _PocketHero(pocket: pocket, balance: store.selectedBalance),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: _PocketAction(
                            icon: Icons.person_add_alt_1_outlined,
                            label: 'Invite',
                            onTap: store.canManageMembers
                                ? () => _inviteMember(context)
                                : null,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _PocketAction(
                            icon: Icons.add_card_outlined,
                            label: 'Contribute',
                            onTap: () => _recordContribution(context),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _PocketAction(
                            icon: Icons.add_home_work_outlined,
                            label: 'New pocket',
                            onTap: () => _createPocket(context),
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
                                  pocket.members[index].role ==
                                      FamilyRole.contributor,
                              onRemove: () => _removeContributor(
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
                    const SizedBox(height: AppSpacing.xl),
                    const _SectionHeader(title: 'Shared contribution history'),
                    const SizedBox(height: AppSpacing.sm),
                    if (store.selectedContributions.isEmpty)
                      const _EmptyActivity()
                    else
                      ...store.selectedContributions.map(
                        (item) => _FamilyContributionTile(contribution: item),
                      ),
                  ],
                ),
          bottomNavigationBar: const AppBottomNavigation(currentIndex: 2),
        );
      },
    );
  }
}

class _EmptyPocketView extends StatelessWidget {
  const _EmptyPocketView({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
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
  const _PocketHero({required this.pocket, required this.balance});

  final FamilyPocket pocket;
  final int balance;

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
                      'For ${pocket.beneficiary}',
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
          const Text(
            'Shared health balance',
            style: TextStyle(color: Colors.white70),
          ),
          Text(
            _naira(balance),
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.xs),
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
        backgroundColor: member.role == FamilyRole.beneficiary
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
      subtitle: Text(
        member.isPending
            ? '${_roleLabel(member.role)} • Invite pending'
            : _roleLabel(member.role),
      ),
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

class _FamilyContributionTile extends StatelessWidget {
  const _FamilyContributionTile({required this.contribution});

  final FamilyContribution contribution;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(
        backgroundColor: AppColors.primarySoft,
        child: Icon(Icons.south_west_rounded, color: AppColors.primary),
      ),
      title: Text(
        '${contribution.memberName} contributed',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text('${_dateLabel(contribution.createdAt)} • Demo record'),
      trailing: Text(
        '+${_naira(contribution.amount)}',
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
  final _beneficiaryController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _beneficiaryController.dispose();
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
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _beneficiaryController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Who is this pocket for?',
              ),
              validator: _required,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppPrimaryButton(
              label: 'Create pocket',
              onPressed: () {
                if (!_formKey.currentState!.validate()) return;
                Navigator.pop(
                  context,
                  _PocketDraft(
                    name: _nameController.text.trim(),
                    beneficiary: _beneficiaryController.text.trim(),
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

class _InviteMemberSheet extends StatefulWidget {
  const _InviteMemberSheet();

  @override
  State<_InviteMemberSheet> createState() => _InviteMemberSheetState();
}

class _InviteMemberSheetState extends State<_InviteMemberSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  FamilyRole _role = FamilyRole.contributor;

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
            DropdownButtonFormField<FamilyRole>(
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'Role'),
              items: const [
                DropdownMenuItem(
                  value: FamilyRole.contributor,
                  child: Text('Contributor'),
                ),
                DropdownMenuItem(
                  value: FamilyRole.beneficiary,
                  child: Text('Beneficiary'),
                ),
              ],
              onChanged: (value) => setState(() => _role = value!),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppPrimaryButton(
              label: 'Send demo invite',
              onPressed: () {
                if (!_formKey.currentState!.validate()) return;
                Navigator.pop(
                  context,
                  _InviteDraft(
                    name: _nameController.text.trim(),
                    email: _emailController.text.trim(),
                    role: _role,
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
              'Demo only—this records activity without moving money.',
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
              label: 'Record demo contribution',
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
  const _PocketDraft({required this.name, required this.beneficiary});

  final String name;
  final String beneficiary;
}

class _InviteDraft {
  const _InviteDraft({
    required this.name,
    required this.email,
    required this.role,
  });

  final String name;
  final String email;
  final FamilyRole role;
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

String _roleLabel(FamilyRole role) => switch (role) {
  FamilyRole.admin => 'Admin',
  FamilyRole.contributor => 'Contributor',
  FamilyRole.beneficiary => 'Beneficiary',
};

String _naira(int amount) {
  final value = amount.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => ',',
  );
  return '₦$value';
}

String _dateLabel(DateTime date) {
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
