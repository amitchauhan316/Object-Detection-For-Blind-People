import 'dart:async';
import 'package:flutter/material.dart';
import 'voice_helper.dart';

class AccessButton extends StatelessWidget {
  final Widget child;
  final FutureOr<void> Function()? onPressed;
  final String label;

  const AccessButton({
    super.key,
    required this.child,
    required this.onPressed,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed == null
          ? null
          : () async {
              await VoiceHelper.speakAction(label);
              await onPressed!();
            },
      child: child,
    );
  }
}
