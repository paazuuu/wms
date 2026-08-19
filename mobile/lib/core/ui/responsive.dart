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
