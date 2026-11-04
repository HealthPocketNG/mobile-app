import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:healthpocket/features/family/domain/family_pocket.dart';
import 'package:healthpocket/features/family/presentation/family_v2_screens.dart';

const _inviteAssets = 'assets/family/v2/invites/';

class FamilyInvitedV2 extends StatefulWidget {
  const FamilyInvitedV2({
    required this.invitation,
    required this.onRespond,
    super.key,
  });

  final FamilyInvitation invitation;
  final Future<bool> Function(bool accept) onRespond;

  @override
  State<FamilyInvitedV2> createState() => _FamilyInvitedV2State();
}

class _FamilyInvitedV2State extends State<FamilyInvitedV2> {
  bool _busy = false;

  Future<void> _respond(bool accept) async {
    if (_busy) return;
    setState(() => _busy = true);
    final completed = await widget.onRespond(accept);
    if (!mounted) return;
    if (completed) {
      Navigator.pop(context);
    } else {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => MediaQuery.withClampedTextScaling(
    maxScaleFactor: 1.1,
    child: Scaffold(
      backgroundColor: const Color(0xFFF7F8F9),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      tooltip: 'Close invitation',
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                      icon: SvgPicture.asset(
                        '${_inviteAssets}invited-close.svg',
                        width: 20,
                        height: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: SvgPicture.asset(
                      '${_inviteAssets}invited-illustration.svg',
                      width: 220,
                      height: 180,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    "You're invited!",
                    textAlign: TextAlign.center,
                    style: familyText(20, FontWeight.w700, FamilyV2.navy),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.invitation.inviterName} invited you to join\n${widget.invitation.pocketName} on HealthPocket.',
                    textAlign: TextAlign.center,
                    style: familyText(
                      13.5,
                      FontWeight.w400,
                      FamilyV2.muted,
                    ).copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: FamilyV2.outline),
                      borderRadius: BorderRadius.circular(14),
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
                                '${FamilyV2.assets}overview-2f0e7.svg',
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
                                    widget.invitation.pocketName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: familyText(
                                      15,
                                      FontWeight.w600,
                                      FamilyV2.navy,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Shared Family Pocket',
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
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            FamilyAvatarStack(
                              names: [widget.invitation.inviterName],
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Invited by ${widget.invitation.inviterName}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: familyText(
                                  12,
                                  FontWeight.w400,
                                  FamilyV2.muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                children: [
                  FamilyV2Button(
                    label: 'Join Family Pocket',
                    onPressed: _busy ? null : () => _respond(true),
                  ),
                  const SizedBox(height: 12),
                  FamilyV2Button(
                    label: 'Decline',
                    height: 46,
                    secondary: true,
                    onPressed: _busy ? null : () => _respond(false),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class FamilyShareInviteSheetV2 extends StatelessWidget {
  const FamilyShareInviteSheetV2({super.key});

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD5DBE0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Share invite link',
              style: familyText(20, FontWeight.w700, FamilyV2.navy),
            ),
            const SizedBox(height: 6),
            Text(
              'Invite links are not available yet. Invite by email for now.',
              style: familyText(
                13,
                FontWeight.w400,
                FamilyV2.muted,
              ).copyWith(height: 1.4),
            ),
            const SizedBox(height: 16),
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F3F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  SvgPicture.asset(
                    '${_inviteAssets}share-link.svg',
                    width: 18,
                    height: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No invite link available',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: familyText(13, FontWeight.w400, FamilyV2.navy),
                    ),
                  ),
                  SvgPicture.asset(
                    '${_inviteAssets}share-copy.svg',
                    width: 14,
                    height: 14,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    'Copy',
                    style: familyText(13, FontWeight.w600, FamilyV2.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: const [
                Expanded(
                  child: _ShareTarget(
                    label: 'WhatsApp',
                    asset: 'share-whatsapp.svg',
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _ShareTarget(label: 'SMS', asset: 'share-sms.svg'),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _ShareTarget(label: 'Email', asset: 'share-email.svg'),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _ShareTarget(label: 'More', asset: 'share-more.svg'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            FamilyV2Button(
              label: 'Done',
              height: 46,
              secondary: true,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ShareTarget extends StatelessWidget {
  const _ShareTarget({required this.label, required this.asset});
  final String label;
  final String asset;

  @override
  Widget build(BuildContext context) => Container(
    height: 72,
    decoration: BoxDecoration(
      color: const Color(0xFFEEF9F7),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SvgPicture.asset('$_inviteAssets$asset', width: 24, height: 24),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: familyText(11.5, FontWeight.w400, FamilyV2.teal),
          ),
        ),
      ],
    ),
  );
}
