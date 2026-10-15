import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:resqmesh/core/network/connection/bluetooth_transport.dart';
import 'package:resqmesh/features/file_transfer/data/engine/transfer_backend.dart';
import 'package:resqmesh/features/file_transfer/data/engine/transfer_engine.dart';

import '../../support/fake_bluetooth.dart';

const idA = 'aaaaaaaa-0000-4000-8000-000000000001';
const idB = 'bbbbbbbb-0000-4000-8000-000000000002';

TransferIdentity identity(String id, String name) => TransferIdentity(
  deviceId: id,
  name: name,
  nameClaimedAt: DateTime.utc(2026),
  appVersion: 'test',
);

void main() {
  test(
    'a file goes over Bluetooth, small chunks, byte-identical (P14)',
    () async {
      final dir = await Directory.systemTemp.createTemp('resqmesh_bt');
      addTearDown(() => dir.delete(recursive: true));
      final air = FakeAir();
      final yusufBt = FakeBluetooth(address: 'AA:01', air: air);
      final rahimBt = FakeBluetooth(address: 'BB:02', air: air);
      final yusufTransport = BluetoothTransport(yusufBt);
      final rahimTransport = BluetoothTransport(rahimBt);
      final sender = TransferEngine(
        transport: yusufTransport,
        timing: TransferTiming.bluetooth,
        chunkSize: 16 * 1024,
        flushEvery: 64 * 1024,
      );
      final receiver = TransferEngine(
        transport: rahimTransport,
        timing: TransferTiming.bluetooth,
      );
      addTearDown(() async {
        await sender.dispose();
        await receiver.dispose();
        await yusufTransport.dispose();
        await rahimTransport.dispose();
      });
      await sender.start(identity(idA, 'Yusuf'));
      final channel = (await receiver.start(identity(idB, 'Rahim')))!;

      final receiverEvents = <TransferEvent>[];
      final senderEvents = <TransferEvent>[];
      final finalPath = p.join(dir.path, 'received', 'f');
      receiver.events.listen((event) {
        receiverEvents.add(event);
        if (event is OfferReceived) {
          receiver.answer(
            event.fileId,
            AcceptOffer(
              partPath: p.join(dir.path, 'partial', 'f.part'),
              finalPath: finalPath,
            ),
          );
        }
      });
      sender.events.listen(senderEvents.add);

      final source = File(p.join(dir.path, 'photo.jpg'));
      final random = Random(3);
      await source.writeAsBytes(
        Uint8List.fromList(List.generate(2 << 20, (_) => random.nextInt(256))),
      );
      const fileId = '0a4e6c1d-2b8f-4e57-a3c9-000000000001';
      sender.upload(
        UploadRequest(
          fileId: fileId,
          chatMessageId: '6f1c2a0e-8a4b-4d1e-9a51-2c7f0b3e9d10',
          peerId: idB,
          address: 'BB:02',
          port: channel,
          path: source.path,
          fileName: 'photo.jpg',
          fileSize: 2 << 20,
          mimeType: 'image/jpeg',
          sha256: await sender.hashFile(source.path),
        ),
      );

      Future<TransferEnded> ended(List<TransferEvent> events) async {
        for (var i = 0; i < 3000; i++) {
          final done = events.whereType<TransferEnded>().firstOrNull;
          if (done != null) return done;
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        fail('did not end');
      }

      expect((await ended(senderEvents)).outcome, isA<TransferCompleted>());
      expect((await ended(receiverEvents)).outcome, isA<TransferCompleted>());
      expect(
        sha256.convert(await File(finalPath).readAsBytes()),
        sha256.convert(await source.readAsBytes()),
      );
    },
  );
}
