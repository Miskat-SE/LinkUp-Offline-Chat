import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resqmesh/core/bootstrap/core_services.dart';
import 'package:resqmesh/core/connection/connection_method.dart';
import 'package:resqmesh/core/logging/app_logger.dart';
import 'package:resqmesh/core/storage/key_value_store.dart';

/// The connection method the user picked, or null before onboarding chose
/// one. Only valid after start-up has finished.
final connectionMethodProvider =
    NotifierProvider<ConnectionMethodController, ConnectionMethod?>(
      ConnectionMethodController.new,
    );

final class ConnectionMethodController extends Notifier<ConnectionMethod?> {
  @override
  ConnectionMethod? build() {
    final stored = ConnectionMethod.fromName(
      ref.watch(keyValueStoreProvider).getString(StoreKeys.connectionMethod),
    );
    // A method from a newer build that this one can't use counts as unset.
    return stored != null && stored.available ? stored : null;
  }

  Future<void> choose(ConnectionMethod method) async {
    if (!method.available) {
      throw ArgumentError.value(method, 'method', 'is not available yet');
    }
    await ref
        .read(keyValueStoreProvider)
        .setString(StoreKeys.connectionMethod, method.name);
    if (!ref.mounted) return;
    state = method;
    ref.read(appLoggerProvider).info(LogTag.app, 'Connection method chosen', {
      'method': method.name,
    });
  }
}
