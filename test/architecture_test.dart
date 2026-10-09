import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Enforces the dependency rules in PROJECT_PLAN.md §4.1 on every test run.
void main() {
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'))
      .toList();

  List<String> importsOf(File file) => RegExp(
    r'''^import\s+'([^']+)';''',
    multiLine: true,
  ).allMatches(file.readAsStringSync()).map((m) => m.group(1)!).toList();

  /// `lib/features/chat/data/x.dart` → `chat`.
  String? featureOf(String path) =>
      RegExp(r'lib/features/([^/]+)/').firstMatch(path)?.group(1);

  List<String> violations(bool Function(File file, String import) broken) => [
    for (final file in files)
      for (final import in importsOf(file))
        if (broken(file, import)) '${file.path} imports $import',
  ];

  test('Material comes from material_ui, not the SDK (ADR-0016)', () {
    expect(
      violations(
        (_, i) =>
            i == 'package:flutter/material.dart' ||
            i == 'package:flutter/cupertino.dart',
      ),
      isEmpty,
    );
  });

  test('core never depends on app or features', () {
    expect(
      violations(
        (f, i) =>
            f.path.startsWith('lib/core/') &&
            (i.startsWith('package:resqmesh/features/') ||
                i.startsWith('package:resqmesh/app/')),
      ),
      isEmpty,
    );
  });

  test('domain layers are pure Dart', () {
    expect(
      violations(
        (f, i) =>
            f.path.contains('/domain/') &&
            (i.startsWith('package:flutter') ||
                i.startsWith('package:material_ui') ||
                i.startsWith('package:flutter_riverpod')),
      ),
      isEmpty,
    );
  });

  test('widgets never touch sockets or files directly', () {
    expect(
      violations(
        (f, i) =>
            (f.path.contains('/presentation/') ||
                f.path.startsWith('lib/shared/widgets/')) &&
            i == 'dart:io',
      ),
      isEmpty,
    );
  });

  test("features use each other's domain layer only", () {
    expect(
      violations((f, i) {
        final from = featureOf(f.path);
        final match = RegExp(
          r'^package:resqmesh/features/([^/]+)/(data|presentation)/',
        ).firstMatch(i);
        // The app shell (router) may wire up every screen. Chat (file
        // messages) and Settings (Storage) build on file sharing; file
        // sharing depends on neither.
        const allowed = {
          ('chat', 'file_transfer'),
          ('settings', 'file_transfer'),
        };
        return from != null &&
            match != null &&
            match.group(1) != from &&
            !allowed.contains((from, match.group(1)));
      }),
      isEmpty,
    );
  });
}
