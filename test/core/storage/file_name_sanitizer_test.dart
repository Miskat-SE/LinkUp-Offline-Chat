import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:resqmesh/core/storage/file_name_sanitizer.dart';
import 'package:resqmesh/core/storage/file_store.dart';
import 'package:resqmesh/features/file_transfer/data/engine/transfer_engine.dart';

String clean(String name) => FileNameSanitizer.sanitize(name);

void main() {
  group('FileNameSanitizer', () {
    test('ordinary names are kept', () {
      expect(clean('photo.jpg'), 'photo.jpg');
      expect(
        clean('Trip to Cox’s Bazar (1).mp4'),
        'Trip to Cox’s Bazar (1).mp4',
      );
      expect(clean('ছবি ২০২৬.png'), 'ছবি ২০২৬.png');
      expect(clean('😀 party.gif'), '😀 party.gif');
    });

    test('paths are cut to the last part (no traversal)', () {
      expect(clean('../../etc/passwd'), 'passwd');
      expect(clean(r'..\..\Windows\system32\evil.dll'), 'evil.dll');
      expect(clean('/data/data/com.resqmesh.resqmesh/databases/x.db'), 'x.db');
      expect(clean('dir/'), FileNameSanitizer.fallback);
      expect(clean('..'), FileNameSanitizer.fallback);
      expect(clean('.'), FileNameSanitizer.fallback);
    });

    test('hidden names and trailing dots or spaces are removed', () {
      expect(clean('.bashrc'), 'bashrc');
      expect(clean('...secret.txt'), 'secret.txt');
      expect(clean('report.pdf. . '), 'report.pdf');
      expect(clean('   '), FileNameSanitizer.fallback);
      expect(clean(''), FileNameSanitizer.fallback);
    });

    test('control characters and direction tricks are removed', () {
      expect(clean('a\u0000b\nc\td.txt'), 'abcd.txt');
      // Shows as "photoexe.jpg" with the override; really an .exe.
      expect(clean('photo\u202Egpj.exe'), 'photogpj.exe');
      expect(clean('x\u2066y\u2069.png'), 'xy.png');
    });

    test('characters other systems reserve are replaced', () {
      expect(clean('a<b>c:d"e|f?g*h.txt'), 'a_b_c_d_e_f_g_h.txt');
      expect(clean('CON'), '_CON');
      expect(clean('nul.txt'), '_nul.txt');
      expect(clean('console.txt'), 'console.txt');
    });

    test('long names fit 255 UTF-8 bytes and keep the extension', () {
      final long = clean('${'a' * 400}.jpeg');
      expect(utf8.encode(long).length, lessThanOrEqualTo(255));
      expect(long, endsWith('.jpeg'));

      // Bangla letters are 3 bytes each: cut on a character boundary.
      final bangla = clean('${'ক' * 200}.pdf');
      expect(utf8.encode(bangla).length, lessThanOrEqualTo(255));
      expect(bangla, endsWith('.pdf'));
      expect(
        bangla.replaceAll('.pdf', '').runes.every((r) => r == 'ক'.runes.first),
        isTrue,
      );

      // Emoji with skin tone are kept whole or dropped, never split.
      final emoji = clean('👍🏽' * 100);
      expect(utf8.encode(emoji).length, lessThanOrEqualTo(255));
      expect(emoji.length % '👍🏽'.length, 0);
    });
  });

  group('FileStore', () {
    test('paths are built from IDs, never from received names', () {
      expect(FileStore.receivedPath('abc'), 'received/abc');
      expect(FileStore.partialPath('abc'), 'partial/abc.part');
      expect(FileStore.sentPath('abc'), 'sent/abc');
      expect(FileStore.thumbPath('abc'), 'thumbs/abc.jpg');
    });
  });

  group('SHA-256 (FIPS 180-2 test vectors)', () {
    late Directory dir;
    setUp(() async => dir = await Directory.systemTemp.createTemp('sha'));
    tearDown(() => dir.delete(recursive: true));

    Future<String> hash(List<int> bytes) async {
      final file = File('${dir.path}/f')..writeAsBytesSync(bytes);
      return TransferEngine().hashFile(file.path);
    }

    test('empty input', () async {
      expect(
        await hash([]),
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
    });

    test('"abc"', () async {
      expect(
        await hash(utf8.encode('abc')),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });

    test('one million "a" (read in chunks)', () async {
      expect(
        await hash(List.filled(1000000, 0x61)),
        'cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0',
      );
    });
  });
}
