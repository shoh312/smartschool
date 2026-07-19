import 'package:flutter/foundation.dart';

/// Which bottom-nav tab the director shell is on. Shared across the app so
/// the bottom bar can stay visible (and correctly highlighted) even on
/// screens pushed on top of MainScreen, not just the tab pages themselves.
class DirectorNavProvider extends ChangeNotifier {
  int currentIndex = 0;

  void setIndex(int index) {
    if (index == currentIndex) return;
    currentIndex = index;
    notifyListeners();
  }
}
