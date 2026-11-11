import 'package:flutter/widgets.dart';

/// Tells a tool page whether its tab is the one on screen.
///
/// All visited tabs stay alive so they keep their last reading, but only the
/// active one may sample a sensor. Outside a [TabActive] a page counts as
/// active.
class TabActive extends InheritedWidget {
  const TabActive({super.key, required this.active, required super.child});

  final bool active;

  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<TabActive>()?.active ?? true;

  @override
  bool updateShouldNotify(TabActive oldWidget) => active != oldWidget.active;
}
