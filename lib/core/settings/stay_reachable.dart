import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resqmesh/core/bootstrap/core_services.dart';
import 'package:resqmesh/core/storage/key_value_store.dart';

/// *Stay reachable* (PROJECT_PLAN.md §5.6, P8.3): keep the background
/// service running while idle, so people nearby can still reach this phone
/// with LinkUp closed. Off by default; offered once.
final stayReachableProvider = NotifierProvider<StayReachable, bool>(
  StayReachable.new,
);

final class StayReachable extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(keyValueStoreProvider).getString(StoreKeys.stayReachable) ==
      'on';

  Future<void> set({required bool on}) async {
    state = on;
    final store = ref.read(keyValueStoreProvider);
    await store.setString(StoreKeys.stayReachable, on ? 'on' : 'off');
    await store.setString(StoreKeys.stayReachableOffered, 'yes');
  }

  /// Whether the one-time offer was already shown or answered.
  bool get offered =>
      ref
          .read(keyValueStoreProvider)
          .getString(StoreKeys.stayReachableOffered) !=
      null;

  Future<void> dismissOffer() => ref
      .read(keyValueStoreProvider)
      .setString(StoreKeys.stayReachableOffered, 'yes');
}
