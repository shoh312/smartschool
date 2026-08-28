import 'package:flutter/foundation.dart';

/// Which bottom-nav tab the shell is on, whichever role is signed in.
/// Shared across the app so
/// the bottom bar can stay visible (and correctly highlighted) even on
/// screens pushed on top of MainScreen, not just the tab pages themselves.
class NavProvider extends ChangeNotifier {
  int currentIndex = 0;

  /// Back to the first tab.
  ///
  /// The provider lives above the navigator, so it survives signing out:
  /// without this, whoever signed in next landed on whatever tab the last
  /// person left open -- in practice Profile, since that is where the
  /// sign-out button is.
  void reset() => setIndex(0);

  void setIndex(int index) {
    if (index == currentIndex) return;
    currentIndex = index;
    notifyListeners();
  }
}
