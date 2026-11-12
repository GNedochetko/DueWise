import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_theme.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 48, this.showName = true});
  final double size;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'DueWise',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/branding/dw_monogram.svg',
            width: size,
            height: size,
          ),
          if (showName) ...[
            const SizedBox(width: 12),
            Text(
              'DueWise',
              style: TextStyle(
                fontSize: size * .52,
                fontWeight: FontWeight.w700,
                letterSpacing: -.7,
                color: AppColors.navy,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
