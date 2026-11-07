import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:healthpocket/core/theme/app_ui_density.dart';
import 'package:healthpocket/core/data/repository_contracts.dart';
import 'package:healthpocket/core/widgets/initials_avatar.dart';
import 'package:healthpocket/features/profile/domain/user_profile.dart';

abstract final class ProfileV2 {
  static const assets = 'assets/profile/v2/';
  static const teal = Color(0xFF0B7F7A);
  static const navy = Color(0xFF0F1B4C);
  static const muted = Color(0xFF5B6477);
  static const mint = Color(0xFFE4F6F3);
  static const outline = Color(0xFFE8EDF0);
  static const soft = Color(0xFFF0F3F5);
  static const pink = Color(0xFFE8405F);
}

TextStyle profileText(double size, FontWeight weight, Color color) => TextStyle(
  fontFamily: 'Inter',
  fontSize: AppUiDensity.font(size),
  fontWeight: weight,
  color: color,
);

class ProfileV2Scaffold extends StatelessWidget {
  const ProfileV2Scaffold({
    required this.title,
    required this.subtitle,
    required this.children,
    super.key,
    this.back = true,
    this.trailing,
    this.bottomNavigationBar,
    this.paddingTop = 18,
    this.backAsset = '9689a.svg',
  });
  final String title, subtitle;
  final List<Widget> children;
  final bool back;
  final Widget? trailing, bottomNavigationBar;
  final double paddingTop;
  final String backAsset;

  @override
  Widget build(BuildContext context) => MediaQuery.withClampedTextScaling(
    maxScaleFactor: 1.1,
    child: Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, paddingTop, 20, 28),
          children: [
            if (back || trailing != null) ...[
              Row(
                children: [
                  if (back)
                    ProfileV2Back(
                      onTap: () => Navigator.pop(context),
                      asset: backAsset,
                    ),
                  const Spacer(),
                  ?trailing,
                ],
              ),
              const SizedBox(height: 8),
            ],
            Text(
              title,
              style: profileText(26, FontWeight.w700, ProfileV2.teal),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: profileText(12, FontWeight.w400, ProfileV2.muted),
            ),
            ...children,
          ],
        ),
      ),
      bottomNavigationBar: bottomNavigationBar,
    ),
  );
}

class ProfileV2DashedOutline extends StatelessWidget {
  const ProfileV2DashedOutline({
    required this.child,
    required this.color,
    super.key,
    this.radius = 12,
  });

  final Widget child;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: _ProfileDashedPainter(color: color, radius: radius),
    child: child,
  );
}

class _ProfileDashedPainter extends CustomPainter {
  const _ProfileDashedPainter({required this.color, required this.radius});
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1),
          Radius.circular(radius),
        ),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final metric in path.computeMetrics()) {
      for (double start = 0; start < metric.length; start += 7) {
        canvas.drawPath(metric.extractPath(start, start + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ProfileDashedPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

class ProfileV2Back extends StatelessWidget {
  const ProfileV2Back({
    required this.onTap,
    super.key,
    this.asset = '9689a.svg',
  });
  final VoidCallback onTap;
  final String asset;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: SizedBox.square(
      dimension: 32,
      child: Center(
        child: SvgPicture.asset(
          '${ProfileV2.assets}$asset',
          width: 20,
          height: 20,
        ),
      ),
    ),
  );
}

class ProfileV2Icon extends StatelessWidget {
  const ProfileV2Icon({
    required this.asset,
    super.key,
    this.background = ProfileV2.mint,
    this.size = 44,
  });
  final String asset;
  final Color background;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: background, shape: BoxShape.circle),
    child: SvgPicture.asset(
      '${ProfileV2.assets}$asset',
      width: size * .5,
      height: size * .5,
    ),
  );
}

class ProfileV2CardRow extends StatelessWidget {
  const ProfileV2CardRow({
    required this.asset,
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
    this.background = ProfileV2.mint,
  });
  final String asset, title, subtitle;
  final VoidCallback onTap;
  final Color background;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: ProfileV2.outline),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              ProfileV2Icon(asset: asset, background: background),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: profileText(14, FontWeight.w600, ProfileV2.navy),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: profileText(
                        11.5,
                        FontWeight.w400,
                        ProfileV2.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              SvgPicture.asset(
                '${ProfileV2.assets}809a3.svg',
                width: 16,
                height: 16,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void profileMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class ProfileV2Photo extends StatelessWidget {
  const ProfileV2Photo({
    required this.profile,
    super.key,
    this.userId,
    this.repository,
    this.providerPhotoUrl,
    this.radius = 48,
  });
  final UserProfile profile;
  final String? userId, providerPhotoUrl;
  final ProfilePhotoRepository? repository;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final path = profile.profileImagePath;
    if (path != null && userId != null && repository != null) {
      return FutureBuilder<String?>(
        future: repository!.getDownloadUrl(userId: userId!, storagePath: path),
        builder: (context, snapshot) =>
            _avatar(snapshot.data ?? providerPhotoUrl),
      );
    }
    return _avatar(providerPhotoUrl);
  }

  Widget _avatar(String? url) {
    final image = url != null && url.startsWith('https://')
        ? NetworkImage(url)
        : null;
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFCDEFEA),
      foregroundImage: image,
      onForegroundImageError: image == null ? null : (_, _) {},
      child: Text(
        InitialsAvatar.initialsFor(profile.fullName),
        style: profileText(radius * .42, FontWeight.w700, ProfileV2.teal),
      ),
    );
  }
}
