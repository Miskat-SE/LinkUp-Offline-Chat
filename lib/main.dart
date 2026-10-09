import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:resqmesh/app/app.dart';
import 'package:resqmesh/app/restartable_app.dart';

void main() {
  runApp(
    RestartableApp(
      builder: (key) => ProviderScope(key: key, child: const ResQMeshApp()),
    ),
  );
}
