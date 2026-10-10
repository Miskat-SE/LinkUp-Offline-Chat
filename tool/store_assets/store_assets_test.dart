// Draws the Play Store icon and feature graphic into store/.
//   flutter test tool/store_assets/store_assets_test.dart
// The mark matches the launcher icon (ic_launcher_foreground.xml).
import 'dart:io';
import 'dart:ui';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const teal = Color(0xFF00696E);
const deep = Color(0xFF00363A);

/// The launcher mark in its 108-unit viewport, drawn in white.
void paintMark(Canvas canvas) {
  final thin = Paint()
    ..color = const Color(0xB3FFFFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5
    ..strokeJoin = StrokeJoin.round;
  final spoke = Paint()
    ..color = const Color(0xFFFFFFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.5
    ..strokeCap = StrokeCap.round;
  final fill = Paint()..color = const Color(0xFFFFFFFF);
  const top = Offset(54, 31);
  const left = Offset(34.1, 65.5);
  const right = Offset(73.9, 65.5);
  const hub = Offset(54, 54);
  canvas
    ..drawPath(
      Path()
        ..moveTo(top.dx, top.dy)
        ..lineTo(left.dx, left.dy)
        ..lineTo(right.dx, right.dy)
        ..close(),
      thin,
    )
    ..drawLine(hub, top, spoke)
    ..drawLine(hub, left, spoke)
    ..drawLine(hub, right, spoke)
    ..drawCircle(hub, 8, fill)
    ..drawCircle(top, 6.5, fill)
    ..drawCircle(left, 6.5, fill)
    ..drawCircle(right, 6.5, fill);
}

Future<void> save(
  int width,
  int height,
  String path,
  void Function(Canvas) draw,
) async {
  final recorder = ui.PictureRecorder();
  draw(Canvas(recorder));
  final image = await recorder.endRecording().toImage(width, height);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  await File(path).writeAsBytes(png!.buffer.asUint8List());
}

Future<void> loadRoboto() async {
  final dir =
      '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts';
  final loader = FontLoader('Roboto');
  for (final weight in ['Bold', 'Regular']) {
    final bytes = File('$dir/Roboto-$weight.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

ui.Paragraph text(
  String s,
  double size,
  FontWeight weight,
  Color color,
  double width,
) {
  final builder =
      ui.ParagraphBuilder(
          ui.ParagraphStyle(
            fontFamily: 'Roboto',
            fontSize: size,
            fontWeight: weight,
            height: 1.2,
          ),
        )
        ..pushStyle(ui.TextStyle(color: color))
        ..addText(s);
  return builder.build()..layout(ui.ParagraphConstraints(width: width));
}

void main() {
  test('store assets', () async {
    await loadRoboto();
    // 512×512 icon: the launcher's visible 72-unit area, full bleed (Play
    // rounds the corners itself).
    await save(512, 512, 'store/icon-512.png', (c) {
      c.drawRect(const Rect.fromLTWH(0, 0, 512, 512), Paint()..color = teal);
      c
        ..scale(512 / 72)
        ..translate(-18, -18);
      paintMark(c);
    });

    // 1024×500 feature graphic.
    await save(1024, 500, 'store/feature-graphic.png', (c) {
      c.drawRect(
        const Rect.fromLTWH(0, 0, 1024, 500),
        Paint()
          ..shader = ui.Gradient.linear(Offset.zero, const Offset(1024, 500), [
            teal,
            deep,
          ]),
      );
      c
        ..save()
        ..translate(70, 90)
        ..scale(320 / 108);
      paintMark(c);
      c.restore();
      c
        ..drawParagraph(
          text('LinkUp', 96, FontWeight.bold, const Color(0xFFFFFFFF), 560),
          const Offset(420, 120),
        )
        ..drawParagraph(
          text(
            'Chat and share files nearby.\nNo internet needed.',
            34,
            FontWeight.normal,
            const Color(0xE6FFFFFF),
            580,
          ),
          const Offset(424, 250),
        );
    });
  });
}
