import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class InlineMessage extends StatelessWidget {
  const InlineMessage({super.key, required this.message, this.isError = true});
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isError ? scheme.errorContainer : AppColors.paleBlue,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          message,
          style: TextStyle(
            color: isError ? scheme.onErrorContainer : AppColors.navy,
          ),
        ),
      ),
    );
  }
}
