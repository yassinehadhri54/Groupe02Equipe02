import 'package:material_ui/material_ui.dart';

class ThemeSelection extends InheritedWidget {
  const ThemeSelection({
    super.key,
    required this.mode,
    required this.onToggle,
    required super.child,
  });

  final ThemeMode mode;
  final VoidCallback onToggle;

  static ThemeSelection? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ThemeSelection>();

  @override
  bool updateShouldNotify(ThemeSelection oldWidget) =>
      mode != oldWidget.mode || onToggle != oldWidget.onToggle;
}

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final selection = ThemeSelection.maybeOf(context);
    if (selection == null) return const SizedBox.shrink();

    final isDark = selection.mode == ThemeMode.dark;
    return IconButton(
      tooltip: isDark ? 'Activer le mode jour' : 'Activer le mode nuit',
      color: color,
      onPressed: selection.onToggle,
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: animation, child: child),
        ),
        child: Icon(
          isDark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
          key: ValueKey(isDark),
        ),
      ),
    );
  }
}
