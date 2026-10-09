import 'package:material_ui/material_ui.dart';

/// Lets the app start over without the process restarting: a new key
/// rebuilds the ProviderScope, so every service stops and starts again
/// from storage. Used after *Clear all local data* (PROJECT_PLAN.md §8.3).
class RestartableApp extends StatefulWidget {
  const RestartableApp({super.key, required this.builder});

  /// Builds the app under [Key]; a new key means a fresh start.
  final Widget Function(Key key) builder;

  /// Starts the app over, if it runs under a [RestartableApp].
  static void restart(BuildContext context) =>
      context.findAncestorStateOfType<_RestartableAppState>()?._restart();

  @override
  State<RestartableApp> createState() => _RestartableAppState();
}

class _RestartableAppState extends State<RestartableApp> {
  Key _key = UniqueKey();

  void _restart() => setState(() => _key = UniqueKey());

  @override
  Widget build(BuildContext context) => widget.builder(_key);
}
