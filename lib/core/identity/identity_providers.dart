import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resqmesh/core/bootstrap/core_services.dart';
import 'package:resqmesh/core/identity/identity_repository.dart';
import 'package:resqmesh/core/identity/local_identity.dart';
import 'package:resqmesh/core/logging/app_logger.dart';

final identityRepositoryProvider = Provider<IdentityRepository>(
  (ref) => IdentityRepository(ref.watch(keyValueStoreProvider)),
);

/// This device's identity. Only valid after start-up has finished.
final identityProvider = NotifierProvider<IdentityController, LocalIdentity>(
  IdentityController.new,
);

final class IdentityController extends Notifier<LocalIdentity> {
  @override
  LocalIdentity build() => ref.watch(identityRepositoryProvider).read();

  /// Validates and stores [name] (normalised). Throws [ArgumentError] if the
  /// name breaks the rules in `Username`.
  Future<void> setUsername(String name) async {
    final hadName = state.hasName;
    final updated = await ref
        .read(identityRepositoryProvider)
        .saveUsername(name);
    if (!ref.mounted) return;
    state = updated;
    ref.read(appLoggerProvider).info(
      LogTag.app,
      hadName ? 'Name changed' : 'Name chosen',
      {'device': updated.shortId},
    );
  }
}
