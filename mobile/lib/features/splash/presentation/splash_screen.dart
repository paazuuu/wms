import 'package:flutter/material.dart';

import '../../../app.dart';
import '../../../core/theme/app_spacing.dart';

/// Shown while a stored session is being restored, before the router knows
/// whether to land on the dashboard or the login page.
///
/// Its own file (rather than a private widget in `app.dart`) because the
/// router needs to name it as a destination: "still deciding" is a real
/// location now, not just a branch of a switch on the home widget.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandMark(size: 72),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: scheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
