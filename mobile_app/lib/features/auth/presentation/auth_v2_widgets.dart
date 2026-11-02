import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

abstract final class AuthV2 {
  static const navy = Color(0xFF0F1B4C);
  static const teal = Color(0xFF0B7F7A);
  static const muted = Color(0xFF5B6477);
  static const border = Color(0xFFE8EDF0);
  static const pale = Color(0xFFE4F6F3);
  static const fieldHeight = 48.0;
  static const horizontal = 20.0;
  static const assets = 'assets/auth/v2/';

  static TextStyle heading = const TextStyle(
    fontFamily: 'Inter',
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: navy,
    height: 1.25,
  );
  static TextStyle body = const TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    color: muted,
    height: 1.45,
  );
  static TextStyle label = const TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: navy,
  );
}

class AuthV2Button extends StatelessWidget {
  const AuthV2Button({
    required this.label,
    required this.onPressed,
    this.secondary = false,
    this.busy = false,
    super.key,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool secondary;
  final bool busy;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: secondary ? 46 : 52,
    child: FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: secondary ? AuthV2.pale : AuthV2.teal,
        foregroundColor: secondary ? AuthV2.teal : Colors.white,
        disabledBackgroundColor: const Color(0xFFA8DDD7),
        shape: const StadiumBorder(),
        elevation: 0,
      ),
      child: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
    ),
  );
}

class AuthV2Back extends StatelessWidget {
  const AuthV2Back({this.onPressed, super.key});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: IconButton(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 20, minHeight: 24),
      alignment: Alignment.centerLeft,
      onPressed: onPressed ?? () => Navigator.maybePop(context),
      icon: SvgPicture.asset('${AuthV2.assets}2cf68.svg'),
    ),
  );
}

class AuthV2Heading extends StatelessWidget {
  const AuthV2Heading(this.title, this.subtitle, {super.key});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(title, textAlign: TextAlign.center, style: AuthV2.heading),
      const SizedBox(height: 12),
      Text(subtitle, textAlign: TextAlign.center, style: AuthV2.body),
    ],
  );
}

class AuthV2Field extends StatefulWidget {
  const AuthV2Field({
    required this.label,
    required this.controller,
    this.hint,
    this.password = false,
    this.keyboardType,
    this.validator,
    this.focusNode,
    super.key,
  });
  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool password;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final FocusNode? focusNode;

  @override
  State<AuthV2Field> createState() => _AuthV2FieldState();
}

class _AuthV2FieldState extends State<AuthV2Field> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(widget.label, style: AuthV2.label),
      const SizedBox(height: 7),
      TextFormField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        keyboardType: widget.keyboardType,
        obscureText: widget.password && !_visible,
        validator: widget.validator,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          color: AuthV2.navy,
        ),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            color: Color(0xFF9BA7B9),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AuthV2.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AuthV2.teal),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          suffixIcon: widget.password
              ? IconButton(
                  onPressed: () => setState(() => _visible = !_visible),
                  icon: const Icon(
                    Icons.visibility_outlined,
                    size: 20,
                    color: AuthV2.muted,
                  ),
                )
              : null,
        ),
      ),
    ],
  );
}

class AuthV2CodeCells extends StatelessWidget {
  const AuthV2CodeCells({
    required this.controller,
    this.masked = false,
    this.autofocus = false,
    this.onComplete,
    super.key,
  });
  final TextEditingController controller;
  final bool masked;
  final bool autofocus;
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      AnimatedBuilder(
        animation: controller,
        builder: (context, _) => Row(
          children: List.generate(
            6,
            (index) => Expanded(
              child: Container(
                height: 54,
                margin: EdgeInsets.only(right: index == 5 ? 0 : 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: index < controller.text.length
                        ? const Color(0xFF13A39B)
                        : AuthV2.border,
                  ),
                ),
                child: Text(
                  index < controller.text.length
                      ? (masked ? '●' : controller.text[index])
                      : '',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: AuthV2.navy,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      Positioned.fill(
        child: Opacity(
          opacity: 0.01,
          child: TextField(
            controller: controller,
            autofocus: autofocus,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            onChanged: (value) {
              if (value.length == 6) onComplete?.call();
            },
          ),
        ),
      ),
    ],
  );
}

class AuthV2Emblem extends StatelessWidget {
  const AuthV2Emblem({
    required this.asset,
    this.background = AuthV2.pale,
    super.key,
  });
  final String asset;
  final Color background;
  @override
  Widget build(BuildContext context) => Container(
    width: 112,
    height: 112,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(56),
    ),
    child: SvgPicture.asset('${AuthV2.assets}$asset'),
  );
}
