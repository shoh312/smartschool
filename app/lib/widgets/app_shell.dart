import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/nav_provider.dart';
import 'app_bottom_nav.dart';
import 'bottom_nav_inset.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.showAppBar = true,
  });

  final String title;
  final Widget child;
  final List<Widget> actions;
  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    // Two different questions, and conflating them was a bug.
    //
    // `hasNav` -- is a bar on screen at all? For a signed-in role, always:
    // MainScreen carries it on its tabs, AppShell on anything pushed. This
    // is what decides the *layout*: the body must run to the bottom edge so
    // content fades out under the pill.
    //
    // `renderNav` -- must *this* Scaffold draw it? Only when pushed;
    // a tab page would otherwise stack a second bar on MainScreen's own.
    //
    // Tying the layout to `renderNav` (as this did) left every tab page
    // with extendBody off and its bottom SafeArea consumed, so content
    // stopped dead in a flat band above the pill instead of dissolving
    // into it -- the opaque block under the bar on the teacher, parent and
    // pupil screens, which the director never had because their tabs use a
    // plain Scaffold rather than AppShell.
    final hasNav = roleHasBottomNav(context.watch<AuthProvider>().role);
    final isPushedScreen = !(ModalRoute.of(context)?.isFirst ?? true);
    final renderNav = hasNav && isPushedScreen;

    // The bottom inset belongs to the nav bar's own SafeArea, not to this
    // one too. Which is why scroll views have to leave the room themselves
    // -- see bottomNavPadding in bottom_nav_inset.dart.
    final body = SafeArea(bottom: !hasNav, child: child);

    return Scaffold(
      extendBody: hasNav,
      appBar: showAppBar
          ? AppBar(
              title: Text(title),
              // No sign-out here any more: every role has a Settings tab
              // now, and signing out belongs in one place rather than in
              // the corner of every root screen where it was one mis-tap
              // away from ending the session.
              actions: actions,
            )
          : null,
      body: body,
      bottomNavigationBar: renderNav
          ? AppBottomNav(
              selectedIndex: context.watch<NavProvider>().currentIndex,
              onDestinationSelected: (index) => selectNavTab(context, index),
            )
          : null,
    );
  }
}
