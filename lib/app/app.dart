import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:resqmesh/app/router.dart';
import 'package:resqmesh/app/theme/app_theme.dart';
import 'package:resqmesh/core/constants/brand.dart';
import 'package:resqmesh/features/settings/presentation/theme_mode_controller.dart';

class ResQMeshApp extends ConsumerWidget {
  const ResQMeshApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    // Wallpaper colours on Android 12+, the brand seed otherwise.
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) => MaterialApp.router(
        title: Brand.name,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(lightDynamic),
        darkTheme: AppTheme.dark(darkDynamic),
        themeMode: themeMode,
        routerConfig: router,
      ),
    );
  }
}
