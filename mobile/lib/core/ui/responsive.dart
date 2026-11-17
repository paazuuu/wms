import 'package:flutter/widgets.dart';

/// Width (in logical pixels) at/above which the app uses its desktop ("wide")
/// layout. The single source of truth so the shell, scan fields and any future
/// responsive behaviour agree on where "PC" begins.
///
/// At or above this width the shell shows a persistent sidebar and scan fields
/// auto-focus on open (so a handheld scanner filters immediately, no tap).
/// Below it the layout is touch-first and fields do not steal focus — avoiding
/// an unwanted on-screen keyboard on phones.
const double kWideLayoutBreakpoint = 900;

/// True when the current window is at least [kWideLayoutBreakpoint] wide.
bool isWideLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kWideLayoutBreakpoint;

/// The smallest window the app lays itself out for: an iPhone SE held upright
/// is 320 wide, and nothing usable fits under 400 high.
const Size kMinimumLayoutSize = Size(320, 400);

/// Lays the app out at least at [kMinimumLayoutSize] and clips what does not
/// fit, so a window the browser reports as almost nothing — a minimised or
/// backgrounded tab, DevTools docked over it, a resize in progress — does not
/// squeeze every screen to zero (a grid with no width, a column with no
/// height). At any real size the child is laid out exactly as before: the
/// tree never changes shape, so no open screen loses its state.
class MinimumLayoutSize extends StatelessWidget {
  const MinimumLayoutSize({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final w = size.width < kMinimumLayoutSize.width ? kMinimumLayoutSize.width : size.width;
    final h = size.height < kMinimumLayoutSize.height ? kMinimumLayoutSize.height : size.height;
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.topLeft,
        minWidth: w,
        maxWidth: w,
        minHeight: h,
        maxHeight: h,
        child: MediaQuery(data: media.copyWith(size: Size(w, h)), child: child),
      ),
    );
  }
}
