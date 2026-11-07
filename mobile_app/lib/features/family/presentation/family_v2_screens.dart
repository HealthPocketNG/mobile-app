import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:healthpocket/core/theme/app_ui_density.dart';
import 'package:healthpocket/features/family/domain/family_pocket.dart';

abstract final class FamilyV2 {
  static const assets = 'assets/family/v2/';
  static const teal = Color(0xFF0B7F7A);
  static const navy = Color(0xFF0F1B4C);
  static const muted = Color(0xFF5B6477);
  static const mint = Color(0xFFE4F6F3);
  static const outline = Color(0xFFE8EDF0);
  static const rose = Color(0xFFFDE8EE);
}

TextStyle familyText(double size, FontWeight weight, Color color) => TextStyle(
  fontFamily: 'Inter',
  fontSize: AppUiDensity.font(size),
  fontWeight: weight,
  color: color,
);

class FamilyV2Button extends StatelessWidget {
  const FamilyV2Button({
    required this.label,
    required this.onPressed,
    this.secondary = false,
    this.height = AppUiDensity.primaryButtonHeight,
    this.trailingAsset,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool secondary;
  final double height;
  final String? trailingAsset;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: double.infinity,
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: secondary ? FamilyV2.mint : FamilyV2.teal,
        foregroundColor: secondary ? FamilyV2.teal : Colors.white,
        disabledBackgroundColor: FamilyV2.outline,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        elevation: 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: familyText(
                  15,
                  FontWeight.w600,
                  secondary ? FamilyV2.teal : Colors.white,
                ),
              ),
            ),
          ),
          if (trailingAsset != null) ...[
            const SizedBox(width: 12),
            SvgPicture.asset('${FamilyV2.assets}$trailingAsset', width: 20),
          ],
        ],
      ),
    ),
  );
}

class FamilyV2Header extends StatelessWidget {
  const FamilyV2Header({
    required this.title,
    required this.subtitle,
    this.trailing,
    this.showBack = true,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;
  final bool showBack;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (showBack) ...[
        SizedBox(
          height: 34,
          child: Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: SvgPicture.asset(
                '${FamilyV2.assets}create-86655.svg',
                width: 18,
                height: 18,
              ),
              onPressed: () => Navigator.pop(context),
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
              tooltip: 'Back',
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: familyText(26, FontWeight.w700, FamilyV2.teal),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: familyText(
                    13,
                    FontWeight.w400,
                    FamilyV2.muted,
                  ).copyWith(height: 1.4),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    ],
  );
}

class FamilyAvatarStack extends StatelessWidget {
  const FamilyAvatarStack({required this.names, super.key});
  final List<String> names;

  static const _backgrounds = [
    Color(0xFFCDEFEA),
    Color(0xFFFDE0E6),
    Color(0xFFFFEBC8),
    Color(0xFFD9E8FF),
  ];
  static const _foregrounds = [
    FamilyV2.teal,
    Color(0xFFC92E4D),
    Color(0xFF9A6200),
    Color(0xFF2B5BD7),
  ];

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 24,
    width: names.isEmpty ? 0 : 24 + (names.length.clamp(1, 4) - 1) * 16,
    child: Stack(
      children: [
        for (var index = 0; index < names.length && index < 4; index++)
          Positioned(
            left: index * 16,
            child: Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _backgrounds[index],
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Text(
                names[index].isEmpty ? '?' : names[index][0].toUpperCase(),
                style: familyText(10, FontWeight.w700, _foregrounds[index]),
              ),
            ),
          ),
      ],
    ),
  );
}

class FamilyPocketOverviewV2 extends StatelessWidget {
  const FamilyPocketOverviewV2({
    required this.pockets,
    required this.totalBalanceKobo,
    required this.balanceForPocketKobo,
    required this.invitations,
    required this.showInvites,
    required this.onTabChanged,
    required this.onCreate,
    required this.onPocketTap,
    required this.onInvitationResponse,
    required this.onInvitationTap,
    required this.submitting,
    required this.developmentContributionsEnabled,
    super.key,
  });

  final List<FamilyPocket> pockets;
  final int totalBalanceKobo;
  final int Function(String) balanceForPocketKobo;
  final List<FamilyInvitation> invitations;
  final bool showInvites;
  final ValueChanged<bool> onTabChanged;
  final VoidCallback onCreate;
  final ValueChanged<FamilyPocket> onPocketTap;
  final void Function(FamilyInvitation, bool) onInvitationResponse;
  final ValueChanged<FamilyInvitation> onInvitationTap;
  final bool submitting;
  final bool developmentContributionsEnabled;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FamilyV2Header(
        title: 'Family Pocket',
        subtitle: 'Save together. Go further.',
        showBack: false,
        trailing: InkWell(
          onTap: onCreate,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 44,
            width: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: FamilyV2.mint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: SvgPicture.asset(
              '${FamilyV2.assets}overview-29e2b.svg',
              width: 24,
              height: 24,
            ),
          ),
        ),
      ),
      const SizedBox(height: 14),
      Container(
        height: MediaQuery.sizeOf(context).width < 360 ? 140 : 116,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0A7F7B), Color(0xFF0E9A93)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              height: 48,
              width: 48,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0x33FFFFFF),
                shape: BoxShape.circle,
              ),
              child: SvgPicture.asset(
                '${FamilyV2.assets}overview-b7ce4.svg',
                width: 26,
                height: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Family Savings',
                    style: familyText(13, FontWeight.w400, Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    familyMoney(totalBalanceKobo),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: familyText(28, FontWeight.w700, Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Across ${pockets.length} ${pockets.length == 1 ? 'pocket' : 'pockets'}',
                    style: familyText(12, FontWeight.w400, Colors.white),
                  ),
                ],
              ),
            ),
            InkWell(
              onTap: pockets.isEmpty
                  ? onCreate
                  : () => onPocketTap(pockets.first),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: SvgPicture.asset(
                  '${FamilyV2.assets}overview-cd711.svg',
                  width: 18,
                  height: 18,
                ),
              ),
            ),
          ],
        ),
      ),
      if (!developmentContributionsEnabled) ...[
        const SizedBox(height: 8),
        Text(
          'Shared funding is not enabled',
          style: familyText(12, FontWeight.w400, FamilyV2.muted),
        ),
      ],
      const SizedBox(height: 10),
      Container(
        height: 46,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFEEF9F7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            for (final tab in [false, true])
              Expanded(
                child: InkWell(
                  onTap: () => onTabChanged(tab),
                  borderRadius: BorderRadius.circular(9),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: showInvites == tab
                          ? Colors.white
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: showInvites == tab
                          ? const [
                              BoxShadow(
                                color: Color(0x140F1B4C),
                                blurRadius: 3,
                                offset: Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          tab ? 'Invites' : 'My Pockets',
                          style: familyText(
                            13,
                            showInvites == tab
                                ? FontWeight.w600
                                : FontWeight.w400,
                            showInvites == tab ? FamilyV2.teal : FamilyV2.muted,
                          ),
                        ),
                        if (tab && invitations.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          const CircleAvatar(
                            radius: 4,
                            backgroundColor: Color(0xFFE8405F),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      if (showInvites)
        invitations.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 36),
                child: Center(
                  child: Text(
                    'No pending invites',
                    style: familyText(13, FontWeight.w400, FamilyV2.muted),
                  ),
                ),
              )
            : Column(
                children: [
                  for (final invitation in invitations)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _FamilyInvitationCardV2(
                        invitation: invitation,
                        submitting: submitting,
                        onTap: () => onInvitationTap(invitation),
                        onAccept: () => onInvitationResponse(invitation, true),
                        onDecline: () =>
                            onInvitationResponse(invitation, false),
                      ),
                    ),
                ],
              )
      else ...[
        for (final pocket in pockets) ...[
          FamilyV2PocketCard(
            pocket: pocket,
            balanceKobo: balanceForPocketKobo(pocket.id),
            onTap: () => onPocketTap(pocket),
          ),
          const SizedBox(height: 10),
        ],
        InkWell(
          onTap: onCreate,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: FamilyV2.mint,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: SvgPicture.asset(
                    '${FamilyV2.assets}overview-74e95.svg',
                    width: 24,
                    height: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Start a new Pocket',
                        style: familyText(14, FontWeight.w700, FamilyV2.navy),
                      ),
                      Text(
                        'Create a pocket for your family, friends or loved ones.',
                        style: familyText(
                          12,
                          FontWeight.w400,
                          FamilyV2.muted,
                        ).copyWith(height: 1.4),
                      ),
                    ],
                  ),
                ),
                SvgPicture.asset(
                  '${FamilyV2.assets}overview-e3cc4.svg',
                  width: 16,
                  height: 16,
                ),
              ],
            ),
          ),
        ),
      ],
    ],
  );
}

class _FamilyInvitationCardV2 extends StatelessWidget {
  const _FamilyInvitationCardV2({
    required this.invitation,
    required this.submitting,
    required this.onTap,
    required this.onAccept,
    required this.onDecline,
  });

  final FamilyInvitation invitation;
  final bool submitting;
  final VoidCallback onTap;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 123),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: FamilyV2.outline),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFFDE0E6),
                child: Text(
                  invitation.inviterName.isEmpty
                      ? '?'
                      : invitation.inviterName[0].toUpperCase(),
                  style: familyText(
                    15,
                    FontWeight.w700,
                    const Color(0xFFC92E4D),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invitation.pocketName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: familyText(14, FontWeight.w700, FamilyV2.navy),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${invitation.inviterName} invited you${_invitationAge(invitation.createdAt)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: familyText(12, FontWeight.w400, FamilyV2.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.only(
              left: MediaQuery.sizeOf(context).width < 360 ? 0 : 56,
            ),
            child: Row(
              children: [
                _InvitationAction(
                  label: 'Accept',
                  onPressed: submitting ? null : onAccept,
                  primary: true,
                ),
                const SizedBox(width: 8),
                _InvitationAction(
                  label: 'Decline',
                  onPressed: submitting ? null : onDecline,
                  primary: false,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

String _invitationAge(DateTime? createdAt) {
  if (createdAt == null) return '';
  final days = DateTime.now().difference(createdAt).inDays;
  if (days < 1) return ' · Today';
  if (days == 1) return ' · Yesterday';
  if (days < 7) return ' · $days days ago';
  if (days < 14) return ' · Last week';
  return ' · ${days ~/ 7} weeks ago';
}

class _InvitationAction extends StatelessWidget {
  const _InvitationAction({
    required this.label,
    required this.onPressed,
    required this.primary,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onPressed,
    borderRadius: BorderRadius.circular(17),
    child: Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: primary ? FamilyV2.teal : const Color(0xFFF0F3F5),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Text(
        label,
        style: familyText(
          12.5,
          FontWeight.w600,
          primary ? Colors.white : FamilyV2.muted,
        ),
      ),
    ),
  );
}

class FamilyV2PocketCard extends StatelessWidget {
  const FamilyV2PocketCard({
    required this.pocket,
    required this.balanceKobo,
    this.onTap,
    super.key,
  });
  final FamilyPocket pocket;
  final int balanceKobo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isCarePocket = pocket.name.toLowerCase().contains("mum's care");
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: FamilyV2.outline),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              height: 44,
              width: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isCarePocket ? FamilyV2.rose : FamilyV2.mint,
                borderRadius: BorderRadius.circular(22),
              ),
              child: SvgPicture.asset(
                '${FamilyV2.assets}${isCarePocket ? 'overview-0bcfc.svg' : 'overview-2f0e7.svg'}',
                width: 24,
                height: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pocket.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: familyText(14, FontWeight.w700, FamilyV2.navy),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      FamilyAvatarStack(
                        names: pocket.members
                            .map((member) => member.name)
                            .toList(),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        familyMemberCount(pocket.members.length),
                        style: familyText(
                          11.5,
                          FontWeight.w400,
                          FamilyV2.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    children: [
                      Text(
                        familyMoney(balanceKobo),
                        style: familyText(18, FontWeight.w700, FamilyV2.teal),
                      ),
                      Text(
                        '${familyFrequency(pocket.frequency)} · ${familyMoney(pocket.defaultContributionAmountKobo)}',
                        style: familyText(
                          11.5,
                          FontWeight.w400,
                          FamilyV2.muted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (onTap != null)
              SvgPicture.asset(
                '${FamilyV2.assets}overview-e3cc4.svg',
                width: 16,
                height: 16,
              ),
          ],
        ),
      ),
    );
  }
}

String familyFrequency(FamilyContributionFrequency value) => switch (value) {
  FamilyContributionFrequency.daily => 'Daily',
  FamilyContributionFrequency.weekly => 'Weekly',
  FamilyContributionFrequency.monthly => 'Monthly',
};

String familyMemberCount(int count) =>
    '$count ${count == 1 ? 'member' : 'members'}';

String familyMoney(int amountKobo) {
  final whole = (amountKobo ~/ 100).toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return '₦ $whole';
}

class FamilyPocketDraft {
  const FamilyPocketDraft({
    required this.name,
    required this.description,
    required this.frequency,
    required this.defaultAmountKobo,
  });
  final String name;
  final String? description;
  final FamilyContributionFrequency frequency;
  final int defaultAmountKobo;
}

class FamilyCreatePocketV2 extends StatefulWidget {
  const FamilyCreatePocketV2({super.key});

  @override
  State<FamilyCreatePocketV2> createState() => _FamilyCreatePocketV2State();
}

class _FamilyCreatePocketV2State extends State<FamilyCreatePocketV2> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _amount = TextEditingController(text: '500');
  FamilyContributionFrequency _frequency = FamilyContributionFrequency.weekly;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      FamilyPocketDraft(
        name: _name.text.trim(),
        description: _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        frequency: _frequency,
        defaultAmountKobo: int.parse(_amount.text) * 100,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => MediaQuery.withClampedTextScaling(
    maxScaleFactor: 1.1,
    child: Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            children: [
              const FamilyV2Header(
                title: 'Create Family Pocket',
                subtitle: 'Start a pocket and invite others to save with you.',
              ),
              const SizedBox(height: 16),
              Center(
                child: InkWell(
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Pocket photos are not available yet.'),
                    ),
                  ),
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    children: [
                      Container(
                        height: 64,
                        width: 64,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: FamilyV2.mint,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: SvgPicture.asset(
                          '${FamilyV2.assets}create-d4ff6.svg',
                          width: 28,
                          height: 28,
                        ),
                      ),
                      const SizedBox(height: 8),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'Add a photo ',
                              style: familyText(
                                12,
                                FontWeight.w400,
                                FamilyV2.teal,
                              ),
                            ),
                            TextSpan(
                              text: '(optional)',
                              style: familyText(
                                12,
                                FontWeight.w400,
                                FamilyV2.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _FamilyFieldLabel('Pocket Name'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: _fieldDecoration('e.g. The Ayo Family'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a pocket name'
                    : null,
              ),
              const SizedBox(height: 20),
              _FamilyFieldLabel('Description', optional: true),
              const SizedBox(height: 8),
              TextFormField(
                controller: _description,
                maxLines: 2,
                decoration: _fieldDecoration(
                  'e.g. For family healthcare needs',
                ),
              ),
              const SizedBox(height: 20),
              _FamilyFieldLabel('Contribution Frequency'),
              const SizedBox(height: 8),
              Container(
                height: 44,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F3F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    for (final value in FamilyContributionFrequency.values)
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _frequency = value),
                          borderRadius: BorderRadius.circular(9),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _frequency == value
                                  ? FamilyV2.teal
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Text(
                              familyFrequency(value),
                              style: familyText(
                                13,
                                _frequency == value
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                _frequency == value
                                    ? Colors.white
                                    : FamilyV2.muted,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _FamilyFieldLabel('Default Amount'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amount,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _fieldDecoration('').copyWith(prefixText: '₦ '),
                style: familyText(20, FontWeight.w700, FamilyV2.navy),
                validator: (value) {
                  final amount = int.tryParse(value ?? '');
                  return amount == null || amount < 100
                      ? 'Enter at least ₦100'
                      : null;
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  SvgPicture.asset(
                    '${FamilyV2.assets}create-39fe6.svg',
                    width: 14,
                    height: 14,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Members can contribute more than this.',
                      style: familyText(12, FontWeight.w400, FamilyV2.muted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: FamilyV2Button(
            label: 'Create Pocket',
            onPressed: _submit,
            trailingAsset: 'create-ed152.svg',
          ),
        ),
      ),
    ),
  );
}

class _FamilyFieldLabel extends StatelessWidget {
  const _FamilyFieldLabel(this.text, {this.optional = false});
  final String text;
  final bool optional;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(text, style: familyText(13, FontWeight.w700, FamilyV2.navy)),
      if (optional)
        Text(
          ' (optional)',
          style: familyText(11, FontWeight.w400, FamilyV2.muted),
        ),
    ],
  );
}

InputDecoration _fieldDecoration(String hint) => InputDecoration(
  hintText: hint,
  hintStyle: familyText(13, FontWeight.w400, const Color(0xFF9AA3AF)),
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  filled: true,
  fillColor: Colors.white,
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: FamilyV2.outline),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: FamilyV2.teal),
  ),
  errorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: Color(0xFFE8405F)),
  ),
);

class FamilyContactsV2 extends StatelessWidget {
  const FamilyContactsV2({required this.onContinue, super.key});
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) => MediaQuery.withClampedTextScaling(
    maxScaleFactor: 1.1,
    child: Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Image.asset(
                '${FamilyV2.assets}contacts-people.png',
                width: 200,
                height: 170,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 24),
              Text(
                'Invite people you trust',
                textAlign: TextAlign.center,
                style: familyText(20, FontWeight.w700, FamilyV2.navy),
              ),
              const SizedBox(height: 8),
              Text(
                'Allow contacts access to quickly add family and\nfriends to your Family Pocket.\nWe never message anyone without your say-so.',
                textAlign: TextAlign.center,
                style: familyText(
                  13.5,
                  FontWeight.w400,
                  FamilyV2.muted,
                ).copyWith(height: 1.5),
              ),
              const Spacer(flex: 4),
              FamilyV2Button(
                label: 'Allow Contacts',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Contacts access is not connected yet. You can invite by email.',
                      ),
                    ),
                  );
                  onContinue();
                },
              ),
              const SizedBox(height: 12),
              FamilyV2Button(
                label: 'Invite with a Link Instead',
                secondary: true,
                onPressed: onContinue,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class FamilyInviteMembersV2 extends StatefulWidget {
  const FamilyInviteMembersV2({
    required this.pocket,
    required this.onInvite,
    required this.onDone,
    required this.onSkip,
    required this.onShareLink,
    this.showSampleContacts = false,
    super.key,
  });

  final FamilyPocket pocket;
  final Future<bool> Function(String name) onInvite;
  final VoidCallback onDone;
  final VoidCallback onSkip;
  final VoidCallback onShareLink;
  final bool showSampleContacts;

  @override
  State<FamilyInviteMembersV2> createState() => _FamilyInviteMembersV2State();
}

class _FamilyInviteMembersV2State extends State<FamilyInviteMembersV2> {
  final _search = TextEditingController();
  bool _busy = false;
  final Set<String> _justInvited = {};
  static const _sampleNames = [
    'Mercy',
    'Daniel',
    'Esther',
    'Tunde',
    'Ruth',
    'Ayo',
    'Chisom',
  ];
  static const _backgrounds = [
    Color(0xFFFDE0E6),
    Color(0xFFFFEBC8),
    Color(0xFFD9E8FF),
    Color(0xFFCDEFEA),
    Color(0xFFE6DEFB),
    Color(0xFFFDE0E6),
    Color(0xFFFFEBC8),
  ];
  static const _foregrounds = [
    Color(0xFFC92E4D),
    Color(0xFF9A6200),
    Color(0xFF2B5BD7),
    FamilyV2.teal,
    Color(0xFF5B3FC4),
    Color(0xFFC92E4D),
    Color(0xFF9A6200),
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _invite(String name) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (await widget.onInvite(name) && mounted) {
        setState(() => _justInvited.add(name));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.pocket.invitations
        .where((item) => item.effectiveStatus == FamilyInvitationStatus.pending)
        .map((item) => item.inviteeName);
    final names =
        <String>{
              if (widget.showSampleContacts) ..._sampleNames,
              ...existing,
              ..._justInvited,
            }
            .where(
              (name) => name.toLowerCase().contains(_search.text.toLowerCase()),
            )
            .toList();
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.1,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          alignment: Alignment.centerLeft,
                          icon: SvgPicture.asset(
                            '${FamilyV2.assets}invite-16de2.svg',
                            width: 18,
                            height: 18,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: widget.onSkip,
                          child: Text(
                            'Skip',
                            style: familyText(
                              13,
                              FontWeight.w400,
                              FamilyV2.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Invite Members',
                      style: familyText(26, FontWeight.w700, FamilyV2.teal),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Add family or friends to this pocket.\nYou can also do this later.',
                      style: familyText(
                        13,
                        FontWeight.w400,
                        FamilyV2.muted,
                      ).copyWith(height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: _fieldDecoration('Search contacts...')
                          .copyWith(
                            filled: true,
                            fillColor: const Color(0xFFF0F3F5),
                            border: InputBorder.none,
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide.none,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: Padding(
                              padding: const EdgeInsets.all(14),
                              child: SvgPicture.asset(
                                '${FamilyV2.assets}invite-21be9.svg',
                                width: 16,
                                height: 16,
                              ),
                            ),
                          ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  children: [
                    if (names.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 30),
                        child: Text(
                          'No contacts here yet. Add a member by email.',
                          textAlign: TextAlign.center,
                          style: familyText(
                            13,
                            FontWeight.w400,
                            FamilyV2.muted,
                          ),
                        ),
                      ),
                    for (var index = 0; index < names.length; index++)
                      _FamilyInviteTile(
                        name: names[index],
                        background: _backgrounds[index % _backgrounds.length],
                        foreground: _foregrounds[index % _foregrounds.length],
                        invited:
                            existing.contains(names[index]) ||
                            _justInvited.contains(names[index]),
                        onInvite: _busy ? null : () => _invite(names[index]),
                      ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _busy ? null : () => _invite(''),
                      icon: const Icon(Icons.mail_outline, size: 18),
                      label: const Text('Invite by email'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FamilyV2Button(
                  label: 'Send Invites',
                  onPressed: _busy ? null : widget.onDone,
                  trailingAsset: 'invite-ed152.svg',
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: widget.onShareLink,
                  icon: SvgPicture.asset(
                    '${FamilyV2.assets}invite-326f1.svg',
                    width: 16,
                    height: 16,
                  ),
                  label: Text(
                    'Share Invite Link',
                    style: familyText(13, FontWeight.w500, FamilyV2.teal),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FamilyInviteTile extends StatelessWidget {
  const _FamilyInviteTile({
    required this.name,
    required this.background,
    required this.foreground,
    required this.invited,
    required this.onInvite,
  });
  final String name;
  final Color background;
  final Color foreground;
  final bool invited;
  final VoidCallback? onInvite;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 54,
    child: Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: background,
          child: Text(
            name.isEmpty ? '?' : name[0].toUpperCase(),
            style: familyText(15, FontWeight.w700, foreground),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            name,
            style: familyText(14, FontWeight.w500, FamilyV2.navy),
          ),
        ),
        if (invited)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F3F5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                SvgPicture.asset(
                  '${FamilyV2.assets}invite-61d4b.svg',
                  width: 12,
                  height: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  'Invited',
                  style: familyText(12, FontWeight.w400, FamilyV2.muted),
                ),
              ],
            ),
          )
        else
          TextButton(
            onPressed: onInvite,
            style: TextButton.styleFrom(
              backgroundColor: FamilyV2.mint,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              'Invite',
              style: familyText(12, FontWeight.w500, FamilyV2.teal),
            ),
          ),
      ],
    ),
  );
}

class FamilyPocketSuccessV2 extends StatelessWidget {
  const FamilyPocketSuccessV2({
    required this.pocket,
    required this.onInviteMore,
    required this.onGoToPocket,
    super.key,
  });
  final FamilyPocket pocket;
  final VoidCallback onInviteMore;
  final VoidCallback onGoToPocket;

  @override
  Widget build(BuildContext context) => MediaQuery.withClampedTextScaling(
    maxScaleFactor: 1.1,
    child: Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: onGoToPocket,
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
                icon: SvgPicture.asset(
                  '${FamilyV2.assets}success-c81db.svg',
                  width: 18,
                  height: 18,
                ),
                tooltip: 'Close',
              ),
            ),
            const SizedBox(height: 44),
            Center(
              child: SizedBox(
                width: 210,
                height: 150,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: FamilyV2.mint,
                        shape: BoxShape.circle,
                      ),
                      child: SvgPicture.asset(
                        '${FamilyV2.assets}success-2bdc5.svg',
                        width: 52,
                        height: 52,
                      ),
                    ),
                    const Positioned(
                      top: 0,
                      left: 48,
                      child: _SuccessRay(color: FamilyV2.teal, angle: -.6),
                    ),
                    const Positioned(
                      top: 0,
                      right: 48,
                      child: _SuccessRay(color: FamilyV2.teal, angle: .6),
                    ),
                    const Positioned(
                      top: 52,
                      left: 4,
                      child: _SuccessRay(color: Color(0xFFE8405F), angle: 1.4),
                    ),
                    const Positioned(
                      top: 52,
                      right: 4,
                      child: _SuccessRay(color: Color(0xFFE8405F), angle: -1.4),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            Text(
              'Family Pocket Created!',
              textAlign: TextAlign.center,
              style: familyText(20, FontWeight.w700, FamilyV2.navy),
            ),
            const SizedBox(height: 8),
            Text(
              '“${pocket.name}” is ready.\nYou can now invite members and start saving together.',
              textAlign: TextAlign.center,
              style: familyText(
                13,
                FontWeight.w400,
                FamilyV2.muted,
              ).copyWith(height: 1.5),
            ),
            const SizedBox(height: 22),
            _FamilySuccessPocketCard(pocket: pocket),
            const SizedBox(height: 28),
            FamilyV2Button(
              label: 'Invite More People',
              onPressed: onInviteMore,
            ),
            const SizedBox(height: 10),
            FamilyV2Button(
              label: 'Go to Pocket',
              secondary: true,
              onPressed: onGoToPocket,
            ),
          ],
        ),
      ),
    ),
  );
}

class _SuccessRay extends StatelessWidget {
  const _SuccessRay({required this.color, required this.angle});
  final Color color;
  final double angle;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: angle,
    child: Container(
      width: 5,
      height: 22,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    ),
  );
}

class _FamilySuccessPocketCard extends StatelessWidget {
  const _FamilySuccessPocketCard({required this.pocket});
  final FamilyPocket pocket;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: FamilyV2.outline),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: FamilyV2.mint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: SvgPicture.asset(
                '${FamilyV2.assets}success-3e389.svg',
                width: 26,
                height: 26,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pocket.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: familyText(15, FontWeight.w700, FamilyV2.navy),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${familyFrequency(pocket.frequency)} · ${familyMoney(pocket.defaultContributionAmountKobo)}',
                    style: familyText(12, FontWeight.w400, FamilyV2.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            FamilyAvatarStack(
              names: pocket.members.map((member) => member.name).toList(),
            ),
            const SizedBox(width: 6),
            Text(
              familyMemberCount(pocket.members.length),
              style: familyText(11.5, FontWeight.w400, FamilyV2.muted),
            ),
          ],
        ),
      ],
    ),
  );
}
