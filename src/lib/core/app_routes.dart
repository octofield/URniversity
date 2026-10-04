import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/app_page.dart';

// Web addresses (CLAUDE.md §13, system_design.md §1). The four tabs share one
// HomeScreen and the address picks the tab; the main pages have their own.
// Everything else — detail pages, journals, the trash — opens on top without
// an address of its own
abstract final class AppRoutes {
  static const tasks = '/tasks';
  static const targets = '/targets';
  static const visions = '/visions';
  static const me = '/me';
  static const timetable = '/timetable';
  static const grades = '/grades';
  static const settings = '/settings';
  static const admin = '/admin';
  static const login = '/login';

  // In tab order: index 0 is the tasks tab
  static const tabs = [tasks, targets, visions, me];
}

// Opens a main page over the current one, so Back returns to it. Without a
// router — a screen pumped on its own in a widget test — it is pushed plainly
void openPage(BuildContext context, String path, Widget Function() page) {
  if (GoRouter.maybeOf(context) != null) {
    context.push(path);
  } else {
    Navigator.push(context, AppPageRoute(builder: (_) => page()));
  }
}

// A main page reached by typing its address has nothing under it to go back
// to; this puts a way to the tasks tab where the back arrow would be
Widget? homeButtonIfFirst(BuildContext context) {
  if (Navigator.canPop(context) || GoRouter.maybeOf(context) == null) return null;
  return IconButton(
    icon: const Icon(Icons.home_outlined),
    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
    onPressed: () => context.go(AppRoutes.tasks),
  );
}
