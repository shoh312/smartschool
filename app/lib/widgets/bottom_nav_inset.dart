import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_role.dart';
import '../providers/auth_provider.dart';
import 'app_bottom_nav.dart';

/// How much room a scroll view must leave at the bottom so its last item
/// isn't stranded behind the floating nav bar.
///
/// The bar floats over the body rather than pushing it up -- that's what
/// lets content fade out underneath it instead of stopping at a hard edge --
/// so nothing reserves its space automatically, and a list that doesn't add
/// this ends with its final card unreachable under the pill.
///
/// Use it wherever a scroll view sets its own padding:
///
/// ```dart
/// ListView(padding: const EdgeInsets.all(16).add(bottomNavPadding(context)))
/// ```
///
/// ### Why this reads the role instead of an inherited value
///
/// The obvious design -- have [AppShell] publish the height through an
/// InheritedWidget -- silently does nothing. A screen builds its list
/// *inside* its own `build`, and hands it to AppShell; the AppShell element
/// is therefore **below** the screen's context, while an inherited lookup
/// only ever walks **up**. Every call would return zero and the bug would
/// look untouched.
///
/// The role answers it without any lookup: whoever is signed in, the bar is
/// on screen for their whole session -- MainScreen carries it on the root
/// route and AppShell re-adds it to everything pushed on top. Only a
/// signed-out session (login, splash) has no bar, and there it is zero.
double bottomNavInset(BuildContext context) {
  final role = context.watch<AuthProvider>().role;
  return roleHasBottomNav(role) ? bottomNavOverlay(context) : 0;
}

/// Whether this role gets a bottom bar at all. Kept next to the inset so
/// the two can't disagree -- a role with a bar but no inset strands its
/// last list item underneath it.
bool roleHasBottomNav(AppRole? role) => role != null;

/// Sugar for the common case -- see [bottomNavInset].
EdgeInsets bottomNavPadding(BuildContext context) =>
    EdgeInsets.only(bottom: bottomNavInset(context));
