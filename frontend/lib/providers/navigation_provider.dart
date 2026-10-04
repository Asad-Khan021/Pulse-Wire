import 'package:flutter_riverpod/flutter_riverpod.dart';

enum NavigationTab {
  home,
  search,
  saved,
  settings,
}

class NavigationNotifier extends StateNotifier<int> {
  NavigationNotifier() : super(0);

  void setIndex(int index) {
    if (index >= 0 && index < 4 && state != index) {
      state = index;
    }
  }

  void selectTab(NavigationTab tab) {
    setIndex(tab.index);
  }
}

final navigationIndexProvider =
    StateNotifierProvider<NavigationNotifier, int>((ref) {
  return NavigationNotifier();
});
