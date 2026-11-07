import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:healthpocket/features/contributions/domain/contribution_record.dart';
import 'package:healthpocket/features/family/domain/family_pocket.dart';
import 'package:healthpocket/features/family/presentation/family_v2_screens.dart';

const _assets = 'assets/family/v2/details/';

class FamilyPocketDetailsV2 extends StatelessWidget {
  const FamilyPocketDetailsV2({
    required this.pocket,
    required this.balanceKobo,
    required this.contributions,
    required this.currentUserId,
    required this.onBack,
    required this.onManage,
    required this.onMembers,
    required this.onInvite,
    required this.onAddMoney,
    required this.onSeeActivity,
    super.key,
  });
  final FamilyPocket pocket;
  final int balanceKobo;
  final List<ContributionRecord> contributions;
  final String currentUserId;
  final VoidCallback onBack;
  final VoidCallback onManage;
  final VoidCallback onMembers;
  final VoidCallback onInvite;
  final VoidCallback onAddMoney;
  final VoidCallback onSeeActivity;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          IconButton(
            tooltip: 'Back to pockets',
            onPressed: onBack,
            padding: EdgeInsets.zero,
            alignment: Alignment.centerLeft,
            icon: SvgPicture.asset(
              '${_assets}details-16de2.svg',
              width: 20,
              height: 20,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Manage pocket',
            onPressed: onManage,
            padding: EdgeInsets.zero,
            alignment: Alignment.centerRight,
            icon: SvgPicture.asset(
              '${_assets}details-e119a.svg',
              width: 21,
              height: 21,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Container(
            height: 54,
            width: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: FamilyV2.mint,
              borderRadius: BorderRadius.circular(20),
            ),
            child: SvgPicture.asset(
              '${_assets}details-197ef.svg',
              width: 25,
              height: 25,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pocket.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: familyText(18, FontWeight.w700, FamilyV2.navy),
                ),
                const SizedBox(height: 4),
                Text(
                  '${familyMemberCount(pocket.members.length)}  •  ${familyFrequency(pocket.frequency)} · ${familyMoney(pocket.defaultContributionAmountKobo)}',
                  maxLines: 2,
                  style: familyText(12, FontWeight.w400, FamilyV2.muted),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Container(
        height: MediaQuery.sizeOf(context).width <= 390 ? 108 : 116,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0A7F7B), Color(0xFF0E9A93)],
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pocket Balance',
                    style: familyText(13, FontWeight.w400, Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    familyMoney(balanceKobo),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: familyText(28, FontWeight.w700, Colors.white),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Next contribution: Not scheduled',
                    style: familyText(11.5, FontWeight.w400, Colors.white),
                  ),
                ],
              ),
            ),
            InkWell(
              onTap: onSeeActivity,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: SvgPicture.asset(
                  '${_assets}details-d787c.svg',
                  width: 16,
                  height: 16,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          _FamilyDetailAction(
            label: 'Add Money',
            asset: 'details-29e2b.svg',
            onTap: onAddMoney,
          ),
          const SizedBox(width: 10),
          _FamilyDetailAction(
            label: 'Invite',
            asset: 'details-b169b.svg',
            onTap: onInvite,
          ),
          const SizedBox(width: 10),
          _FamilyDetailAction(
            label: 'Manage',
            asset: 'details-e119a.svg',
            onTap: onManage,
          ),
        ],
      ),
      const SizedBox(height: 14),
      _FamilySectionTitle(
        title: 'Members (${pocket.members.length})',
        onSeeAll: onMembers,
      ),
      const SizedBox(height: 10),
      if (pocket.members.isEmpty)
        Text(
          'No members yet',
          style: familyText(13, FontWeight.w400, FamilyV2.muted),
        )
      else
        SizedBox(
          height: 88,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: pocket.members.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final member = pocket.members[index];
              return SizedBox(
                width: 64,
                child: Column(
                  children: [
                    FamilyMemberAvatar(
                      member: member,
                      index: index,
                      radius: 21,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      member.id == currentUserId
                          ? 'You'
                          : member.name.split(' ').first,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: familyText(11, FontWeight.w500, FamilyV2.navy),
                    ),
                    const SizedBox(height: 4),
                    FamilyRoleChip(label: familyRoleLabel(member)),
                  ],
                ),
              );
            },
          ),
        ),
      const SizedBox(height: 14),
      _FamilySectionTitle(title: 'Recent Activity', onSeeAll: onSeeActivity),
      const SizedBox(height: 8),
      if (contributions.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'No shared contributions yet.',
            style: familyText(13, FontWeight.w400, FamilyV2.muted),
          ),
        )
      else
        for (final record in contributions.take(3))
          FamilyActivityRow(record: record),
    ],
  );
}

class _FamilyDetailAction extends StatelessWidget {
  const _FamilyDetailAction({
    required this.label,
    required this.asset,
    required this.onTap,
  });
  final String label;
  final String asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Container(
            height: 44,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: FamilyV2.mint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SvgPicture.asset('$_assets$asset', width: 21, height: 21),
          ),
          const SizedBox(height: 6),
          Text(label, style: familyText(12, FontWeight.w400, FamilyV2.navy)),
        ],
      ),
    ),
  );
}

class _FamilySectionTitle extends StatelessWidget {
  const _FamilySectionTitle({required this.title, required this.onSeeAll});
  final String title;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: familyText(14, FontWeight.w700, FamilyV2.navy),
        ),
      ),
      TextButton(
        onPressed: onSeeAll,
        style: TextButton.styleFrom(padding: EdgeInsets.zero),
        child: Text(
          'See all',
          style: familyText(12, FontWeight.w400, FamilyV2.muted),
        ),
      ),
    ],
  );
}

class FamilyMemberAvatar extends StatelessWidget {
  const FamilyMemberAvatar({
    required this.member,
    required this.index,
    this.radius = 22,
    super.key,
  });
  final FamilyMember member;
  final int index;
  final double radius;
  static const backgrounds = [
    Color(0xFFCDEFEA),
    Color(0xFFFDE0E6),
    Color(0xFFFFEBC8),
    Color(0xFFD9E8FF),
    Color(0xFFE6DEFB),
  ];
  static const foregrounds = [
    FamilyV2.teal,
    Color(0xFFC92E4D),
    Color(0xFF9A6200),
    Color(0xFF2B5BD7),
    Color(0xFF5B3FC4),
  ];

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: radius,
    backgroundColor: backgrounds[index % backgrounds.length],
    child: Text(
      member.name.isEmpty ? '?' : member.name[0].toUpperCase(),
      style: familyText(
        radius * .55,
        FontWeight.w600,
        foregrounds[index % foregrounds.length],
      ),
    ),
  );
}

class FamilyRoleChip extends StatelessWidget {
  const FamilyRoleChip({required this.label, super.key});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: label == 'Admin' || label == 'Owner'
          ? FamilyV2.mint
          : const Color(0xFFF0F3F5),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      maxLines: 1,
      style: familyText(
        10,
        FontWeight.w400,
        label == 'Admin' || label == 'Owner' ? FamilyV2.teal : FamilyV2.muted,
      ),
    ),
  );
}

String familyRoleLabel(FamilyMember member) {
  if (member.role == FamilyRole.owner) return 'Owner';
  if (member.role == FamilyRole.admin) return 'Admin';
  if (member.isBeneficiary && !member.canContribute) return 'Beneficiary';
  return 'Contributor';
}

class FamilyActivityRow extends StatelessWidget {
  const FamilyActivityRow({required this.record, super.key});
  final ContributionRecord record;

  @override
  Widget build(BuildContext context) {
    final name = record.contributorName ?? 'Family member';
    final index = name.isEmpty ? 0 : name.codeUnitAt(0) % 5;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: FamilyV2.outline)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: FamilyMemberAvatar.backgrounds[index],
            child: Text(
              name.isEmpty ? '?' : name[0].toUpperCase(),
              style: familyText(
                13,
                FontWeight.w600,
                FamilyMemberAvatar.foregrounds[index],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: familyText(13, FontWeight.w500, FamilyV2.navy),
                ),
                const SizedBox(height: 3),
                Text(
                  familyActivityDate(record.createdAt),
                  style: familyText(11, FontWeight.w400, FamilyV2.muted),
                ),
              ],
            ),
          ),
          Text(
            '+ ${familyMoney(record.amountKobo)}',
            style: familyText(13, FontWeight.w700, FamilyV2.teal),
          ),
        ],
      ),
    );
  }
}

String familyActivityDate(DateTime? date) {
  if (date == null) return 'Pending';
  final now = DateTime.now();
  if (now.year == date.year && now.month == date.month && now.day == date.day) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    return 'Today, $hour:${date.minute.toString().padLeft(2, '0')} ${date.hour < 12 ? 'AM' : 'PM'}';
  }
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

class FamilyActivityV2 extends StatelessWidget {
  const FamilyActivityV2({required this.contributions, super.key});
  final List<ContributionRecord> contributions;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            alignment: Alignment.centerLeft,
            icon: SvgPicture.asset(
              '${_assets}details-16de2.svg',
              width: 20,
              height: 20,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Family Activity',
            style: familyText(26, FontWeight.w700, FamilyV2.teal),
          ),
          const SizedBox(height: 16),
          if (contributions.isEmpty)
            Text(
              'No shared contributions yet.',
              style: familyText(13, FontWeight.w400, FamilyV2.muted),
            )
          else
            for (final record in contributions)
              FamilyActivityRow(record: record),
        ],
      ),
    ),
  );
}

typedef UpdateFamilyPocketV2 = Future<bool> Function({
  String? name,
  FamilyContributionFrequency? frequency,
  int? defaultContributionAmountKobo,
});

class FamilyManagePocketV2 extends StatefulWidget {
  const FamilyManagePocketV2({
    required this.pocket,
    required this.onUpdate,
    required this.onMembers,
    required this.onLeave,
    required this.onCancelInvitation,
    required this.canManage,
    required this.canLeave,
    super.key,
  });
  final FamilyPocket pocket;
  final UpdateFamilyPocketV2 onUpdate;
  final VoidCallback onMembers;
  final Future<bool> Function() onLeave;
  final ValueChanged<FamilyInvitation> onCancelInvitation;
  final bool canManage;
  final bool canLeave;

  @override
  State<FamilyManagePocketV2> createState() => _FamilyManagePocketV2State();
}

class _FamilyManagePocketV2State extends State<FamilyManagePocketV2> {
  bool _busy = false;

  Future<void> _editName() async {
    if (!widget.canManage) return;
    var draftName = widget.pocket.name;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Pocket name'),
        content: TextFormField(
          initialValue: draftName,
          onChanged: (value) => draftName = value,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          maxLength: 80,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, draftName.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null ||
        result.isEmpty ||
        result == widget.pocket.name ||
        !mounted) {
      return;
    }
    setState(() => _busy = true);
    await widget.onUpdate(name: result);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _editFrequency() async {
    if (!widget.canManage) return;
    final value = await showModalBottomSheet<FamilyContributionFrequency>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Contribution frequency',
                style: familyText(20, FontWeight.w700, FamilyV2.navy),
              ),
              const SizedBox(height: 12),
              for (final option in FamilyContributionFrequency.values)
                ListTile(
                  title: Text(familyFrequency(option)),
                  trailing: Icon(
                    option == widget.pocket.frequency
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: FamilyV2.teal,
                  ),
                  onTap: () => Navigator.pop(sheetContext, option),
                ),
            ],
          ),
        ),
      ),
    );
    if (value == null || value == widget.pocket.frequency || !mounted) return;
    setState(() => _busy = true);
    await widget.onUpdate(frequency: value);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _editAmount() async {
    if (!widget.canManage) return;
    var draftAmount = (widget.pocket.defaultContributionAmountKobo ~/ 100)
        .toString();
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Default amount'),
        content: TextFormField(
          initialValue: draftAmount,
          onChanged: (value) => draftAmount = value,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            prefixText: '₦ ',
            labelText: 'Amount',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final naira = int.tryParse(draftAmount);
              if (naira == null || naira < 100) return;
              Navigator.pop(dialogContext, naira * 100);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null ||
        result == widget.pocket.defaultContributionAmountKobo ||
        !mounted) {
      return;
    }
    setState(() => _busy = true);
    await widget.onUpdate(defaultContributionAmountKobo: result);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _confirmLeave() async {
    if (!widget.canLeave) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transfer ownership before leaving this pocket.'),
        ),
      );
      return;
    }
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD2D8DD),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: FamilyV2.mint,
                  shape: BoxShape.circle,
                ),
                child: SvgPicture.asset(
                  '${_assets}leave-modal.svg',
                  width: 30,
                  height: 30,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Leave ${widget.pocket.name}?',
                textAlign: TextAlign.center,
                style: familyText(20, FontWeight.w700, FamilyV2.navy),
              ),
              const SizedBox(height: 30),
              Text(
                "You'll stop receiving updates and won't be able to contribute unless you're invited again.",
                textAlign: TextAlign.center,
                style: familyText(
                  13,
                  FontWeight.w400,
                  FamilyV2.muted,
                ).copyWith(height: 1.5),
              ),
              const SizedBox(height: 62),
              _FamilyDestructiveButton(
                label: 'Leave Pocket',
                onPressed: () => Navigator.pop(sheetContext, true),
              ),
              const SizedBox(height: 10),
              FamilyV2Button(
                label: 'Cancel',
                secondary: true,
                onPressed: () => Navigator.pop(sheetContext, false),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    final left = await widget.onLeave();
    if (left && navigator.mounted) navigator.pop();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => MediaQuery.withClampedTextScaling(
    maxScaleFactor: 1.1,
    child: Scaffold(
      backgroundColor: const Color(0xFFF7F8F9),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              alignment: Alignment.centerLeft,
              padding: EdgeInsets.zero,
              icon: SvgPicture.asset(
                '${_assets}details-16de2.svg',
                width: 20,
                height: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Manage pocket',
              style: familyText(26, FontWeight.w700, FamilyV2.teal),
            ),
            const SizedBox(height: 4),
            Text(
              widget.pocket.name,
              style: familyText(13, FontWeight.w400, FamilyV2.muted),
            ),
            const SizedBox(height: 14),
            _FamilyManageOption(
              title: 'Pocket name',
              subtitle: widget.pocket.name,
              asset: 'manage_card-ada86.svg',
              onTap: _busy ? null : _editName,
            ),
            _FamilyManageOption(
              title: 'Contribution frequency',
              subtitle: familyFrequency(widget.pocket.frequency),
              asset: 'manage-frequency.svg',
              showChevron: false,
              onTap: _busy ? null : _editFrequency,
            ),
            _FamilyManageOption(
              title: 'Default amount',
              subtitle: familyMoney(widget.pocket.defaultContributionAmountKobo)
                  .replaceFirst('₦ ', '₦'),
              asset: 'manage-amount.svg',
              onTap: _busy ? null : _editAmount,
            ),
            _FamilyManageOption(
              title: 'Members and roles',
              subtitle: familyMemberCount(widget.pocket.members.length),
              asset: 'manage-members.svg',
              onTap: widget.onMembers,
            ),
            _FamilyManageOption(
              title: 'Pocket notifications',
              subtitle: 'Updates from this pocket',
              asset: 'manage-bell.svg',
              toggle: true,
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Pocket-specific notification settings are not available yet.',
                  ),
                ),
              ),
            ),
            _FamilyManageOption(
              title: 'Leave pocket',
              subtitle: "You'll stop receiving updates",
              asset: 'manage-leave.svg',
              onTap: _busy ? null : _confirmLeave,
            ),
            if (widget.pocket.invitations.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Invitations',
                style: familyText(14, FontWeight.w700, FamilyV2.navy),
              ),
              const SizedBox(height: 8),
              for (final invitation in widget.pocket.invitations)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(invitation.inviteeName),
                  subtitle: Text(invitation.effectiveStatus.name),
                  trailing:
                      widget.canManage &&
                          invitation.effectiveStatus ==
                              FamilyInvitationStatus.pending
                      ? TextButton(
                          onPressed: () =>
                              widget.onCancelInvitation(invitation),
                          child: const Text('Cancel'),
                        )
                      : null,
                ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _FamilyManageOption extends StatelessWidget {
  const _FamilyManageOption({
    required this.title,
    required this.subtitle,
    required this.asset,
    required this.onTap,
    this.showChevron = true,
    this.toggle = false,
  });
  final String title;
  final String subtitle;
  final String asset;
  final VoidCallback? onTap;
  final bool showChevron;
  final bool toggle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        constraints: const BoxConstraints(minHeight: 74),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          border: Border.all(color: FamilyV2.outline),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: FamilyV2.mint,
                shape: BoxShape.circle,
              ),
              child: SvgPicture.asset('$_assets$asset', width: 22, height: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: familyText(14, FontWeight.w700, FamilyV2.navy),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: familyText(12, FontWeight.w400, FamilyV2.muted),
                  ),
                ],
              ),
            ),
            if (toggle)
              Switch(
                value: true,
                onChanged: onTap == null ? null : (_) => onTap!(),
                activeThumbColor: Colors.white,
                activeTrackColor: FamilyV2.teal,
              )
            else if (showChevron)
              SvgPicture.asset(
                '${_assets}manage_card-48cd9.svg',
                width: 16,
                height: 16,
              ),
          ],
        ),
      ),
    ),
  );
}

class _FamilyDestructiveButton extends StatelessWidget {
  const _FamilyDestructiveButton({
    required this.label,
    required this.onPressed,
  });
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 52,
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFFDE8EE),
        foregroundColor: const Color(0xFFE8405F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        elevation: 0,
      ),
      child: Text(
        label,
        style: familyText(15, FontWeight.w600, const Color(0xFFE8405F)),
      ),
    ),
  );
}

class FamilyMembersV2 extends StatelessWidget {
  const FamilyMembersV2({
    required this.pocket,
    required this.contributions,
    required this.currentUserId,
    required this.canManage,
    required this.onInvite,
    required this.onRemove,
    super.key,
  });
  final FamilyPocket pocket;
  final List<ContributionRecord> contributions;
  final String currentUserId;
  final bool canManage;
  final VoidCallback onInvite;
  final ValueChanged<FamilyMember> onRemove;

  int _balanceFor(FamilyMember member) => contributions
      .where(
        (record) =>
            record.contributorUserId == member.id &&
            record.status == ContributionStatus.recorded &&
            record.amountKobo > 0,
      )
      .fold(0, (total, record) => total + record.amountKobo);

  Future<void> _changeRole(BuildContext context, FamilyMember member) async {
    if (!canManage ||
        member.id == currentUserId ||
        member.role != FamilyRole.member) {
      return;
    }
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => _FamilyRoleSheet(
        member: member,
        onSave: () => Navigator.pop(sheetContext, true),
        onRemove: () {
          Navigator.pop(sheetContext);
          onRemove(member);
        },
      ),
    );
    if (saved == true && context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Role changes unavailable'),
          content: const Text(
            'Role changes are not available in this build yet.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => MediaQuery.withClampedTextScaling(
    maxScaleFactor: 1.1,
    child: Scaffold(
      backgroundColor: const Color(0xFFF7F8F9),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  alignment: Alignment.centerLeft,
                  padding: EdgeInsets.zero,
                  icon: SvgPicture.asset(
                    '${_assets}members-16de2.svg',
                    width: 20,
                    height: 20,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: canManage ? onInvite : null,
                  child: Text(
                    'Invite',
                    style: familyText(13, FontWeight.w500, FamilyV2.teal),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Members (${pocket.members.length})',
              style: familyText(26, FontWeight.w700, FamilyV2.teal),
            ),
            const SizedBox(height: 4),
            Text(
              'People saving together in ${pocket.name}.',
              style: familyText(13, FontWeight.w400, FamilyV2.muted),
            ),
            const SizedBox(height: 12),
            for (var index = 0; index < pocket.members.length; index++)
              _FamilyMemberRow(
                member: pocket.members[index],
                index: index,
                currentUserId: currentUserId,
                amountKobo: _balanceFor(pocket.members[index]),
                onTap:
                    canManage &&
                        pocket.members[index].id != currentUserId &&
                        pocket.members[index].role == FamilyRole.member
                    ? () => _changeRole(context, pocket.members[index])
                    : null,
              ),
          ],
        ),
      ),
    ),
  );
}

class _FamilyMemberRow extends StatelessWidget {
  const _FamilyMemberRow({
    required this.member,
    required this.index,
    required this.currentUserId,
    required this.amountKobo,
    required this.onTap,
  });
  final FamilyMember member;
  final int index;
  final String currentUserId;
  final int amountKobo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    key: ValueKey('family-member-${member.id}'),
    onTap: onTap,
    child: Container(
      height: 66,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: FamilyV2.outline)),
      ),
      child: Row(
        children: [
          FamilyMemberAvatar(member: member, index: index, radius: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.id == currentUserId ? 'You' : member.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: familyText(14, FontWeight.w700, FamilyV2.navy),
                ),
                const SizedBox(height: 3),
                FamilyRoleChip(label: familyRoleLabel(member)),
              ],
            ),
          ),
          Text(
            amountKobo == 0
                ? '—'
                : familyMoney(amountKobo).replaceFirst('₦ ', '₦'),
            style: familyText(13, FontWeight.w700, FamilyV2.navy),
          ),
        ],
      ),
    ),
  );
}

enum _FamilyRoleOption { admin, contributor, beneficiary, guardrail }

class _FamilyRoleSheet extends StatefulWidget {
  const _FamilyRoleSheet({
    required this.member,
    required this.onSave,
    required this.onRemove,
  });
  final FamilyMember member;
  final VoidCallback onSave;
  final VoidCallback onRemove;

  @override
  State<_FamilyRoleSheet> createState() => _FamilyRoleSheetState();
}

class _FamilyRoleSheetState extends State<_FamilyRoleSheet> {
  late _FamilyRoleOption _selected = widget.member.role == FamilyRole.admin
      ? _FamilyRoleOption.admin
      : widget.member.isBeneficiary && !widget.member.canContribute
      ? _FamilyRoleOption.beneficiary
      : _FamilyRoleOption.contributor;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD2D8DD),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Change role',
              style: familyText(20, FontWeight.w700, FamilyV2.navy),
            ),
            const SizedBox(height: 4),
            Text(
              widget.member.name,
              style: familyText(13, FontWeight.w400, FamilyV2.muted),
            ),
            const SizedBox(height: 4),
            for (final option in _FamilyRoleOption.values) ...[
              _FamilyRoleOptionTile(
                option: option,
                selected: _selected == option,
                onTap: () => setState(() => _selected = option),
              ),
              const SizedBox(height: 4),
            ],
            const SizedBox(height: 16),
            FamilyV2Button(label: 'Save Role', onPressed: widget.onSave),
            const SizedBox(height: 10),
            _FamilyDestructiveButton(
              label: 'Remove from Pocket',
              onPressed: widget.onRemove,
            ),
          ],
        ),
      ),
    ),
  );
}

class _FamilyRoleOptionTile extends StatelessWidget {
  const _FamilyRoleOptionTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });
  final _FamilyRoleOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = switch (option) {
      _FamilyRoleOption.admin => 'Admin',
      _FamilyRoleOption.contributor => 'Contributor',
      _FamilyRoleOption.beneficiary => 'Beneficiary',
      _FamilyRoleOption.guardrail => 'Guardrail',
    };
    final description = switch (option) {
      _FamilyRoleOption.admin => 'Manages the pocket, members and roles',
      _FamilyRoleOption.contributor => 'Can add money to the pocket',
      _FamilyRoleOption.beneficiary => 'Can use pocket funds for care',
      _FamilyRoleOption.guardrail =>
        'Reviews larger payments before they go through',
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        constraints: const BoxConstraints(minHeight: 78),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEEF9F7) : Colors.white,
          border: Border.all(
            color: selected ? FamilyV2.teal : FamilyV2.outline,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? FamilyV2.teal : const Color(0xFF9AA3AF),
                  width: selected ? 6 : 1,
                ),
              ),
              child: selected
                  ? const Center(
                      child: CircleAvatar(
                        radius: 2,
                        backgroundColor: Colors.white,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: familyText(14, FontWeight.w700, FamilyV2.navy),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: familyText(12, FontWeight.w400, FamilyV2.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
