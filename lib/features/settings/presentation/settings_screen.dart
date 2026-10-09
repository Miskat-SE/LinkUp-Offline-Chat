import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:resqmesh/app/router.dart';
import 'package:resqmesh/app/theme/tokens.dart';
import 'package:resqmesh/core/connection/connection_providers.dart';
import 'package:resqmesh/core/constants/brand.dart';
import 'package:resqmesh/core/identity/identity_providers.dart';
import 'package:resqmesh/core/platform/app_info_provider.dart';
import 'package:resqmesh/core/platform/background.dart';
import 'package:resqmesh/core/settings/developer_mode.dart';
import 'package:resqmesh/core/settings/stay_reachable.dart';
import 'package:resqmesh/core/storage/database_providers.dart';
import 'package:resqmesh/features/settings/presentation/storage_screen.dart';
import 'package:resqmesh/features/settings/presentation/theme_mode_controller.dart';
import 'package:resqmesh/shared/widgets/connection_method_info.dart';
import 'package:resqmesh/shared/widgets/user_avatar.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.large(title: Text('Settings')),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              0,
              AppSpacing.gutter,
              AppSpacing.xxl,
            ),
            sliver: SliverList.list(
              children: const [
                _ProfileCard(),
                _SectionTitle('Connection'),
                _ConnectionCard(),
                SizedBox(height: AppSpacing.md),
                _StayReachableCard(),
                _SectionTitle('Appearance'),
                _ThemeCard(),
                _SectionTitle('Storage'),
                _StorageCard(),
                _SectionTitle('About'),
                _AboutCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends ConsumerWidget {
  const _ProfileCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final identity = ref.watch(identityProvider);
    final name = identity.username ?? '';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                UserAvatar(name: name, seed: identity.deviceId, size: 64),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: theme.textTheme.headlineSmall),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Device ${identity.shortId}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.tonalIcon(
              onPressed: () => context.push(Routes.changeName),
              icon: const Icon(Icons.edit_rounded),
              label: const Text('Change name'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionCard extends ConsumerWidget {
  const _ConnectionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final method = ref.watch(connectionMethodProvider);
    final info = method == null ? null : ConnectionMethodInfo.of(method);
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.sm,
        ),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          child: Icon(
            info?.icon ?? Icons.cable_rounded,
            color: scheme.onPrimaryContainer,
          ),
        ),
        title: const Text('How you connect'),
        subtitle: Text(info?.title ?? 'Not chosen'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.push(Routes.connection),
      ),
    );
  }
}

/// Stay reachable (P8.3): the background service keeps running while idle.
class _StayReachableCard extends ConsumerWidget {
  const _StayReachableCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(stayReachableProvider);
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.sm,
            ),
            secondary: const Icon(Icons.wifi_tethering_rounded),
            title: const Text('Stay reachable'),
            subtitle: const Text(
              'Get messages and files with LinkUp closed. Shows a small '
              'notification and uses a little more battery.',
            ),
            value: on,
            onChanged: (value) =>
                ref.read(stayReachableProvider.notifier).set(on: value),
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
            ),
            leading: const Icon(Icons.battery_saver_rounded),
            title: const Text('Battery settings'),
            subtitle: const Text(
              'If your phone stops LinkUp in the background, allow it here.',
            ),
            trailing: const Icon(Icons.open_in_new_rounded, size: 18),
            onTap: () =>
                ref.read(backgroundServiceProvider).openBatterySettings(),
          ),
        ],
      ),
    );
  }
}

class _StorageCard extends ConsumerWidget {
  const _StorageCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final count = ref.watch(messageCountProvider).value;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.sm,
        ),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          child: Icon(
            Icons.storage_rounded,
            color: scheme.onSecondaryContainer,
          ),
        ),
        title: const Text('Storage'),
        subtitle: Text(count == null ? '…' : messageCountLabel(count)),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.push(Routes.storage),
      ),
    );
  }
}

/// App version. Tapping it 7 times unlocks the developer screen (spec §34).
class _AboutCard extends ConsumerStatefulWidget {
  const _AboutCard();

  @override
  ConsumerState<_AboutCard> createState() => _AboutCardState();
}

class _AboutCardState extends ConsumerState<_AboutCard> {
  static const _tapsToUnlock = 7;
  int _taps = 0;

  Future<void> _onVersionTap() async {
    if (ref.read(developerModeProvider)) return;
    _taps++;
    if (_taps < _tapsToUnlock) return;
    await ref.read(developerModeProvider.notifier).unlock();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Developer options unlocked')));
  }

  @override
  Widget build(BuildContext context) {
    final version = ref.watch(appInfoProvider).value?.label ?? '…';
    final developer = ref.watch(developerModeProvider);
    return Card(
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.sm,
            ),
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text(Brand.name),
            subtitle: Text('Version $version'),
            onTap: _onVersionTap,
          ),
          if (developer)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.sm,
              ),
              leading: const Icon(Icons.developer_mode_rounded),
              title: const Text('Developer options'),
              subtitle: const Text('Network, peers, packets and logs'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push(Routes.developer),
            ),
        ],
      ),
    );
  }
}

class _ThemeCard extends ConsumerWidget {
  const _ThemeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Theme', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto_rounded),
                  label: Text('System'),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_rounded),
                  label: Text('Light'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_rounded),
                  label: Text('Dark'),
                ),
              ],
              selected: {mode},
              showSelectedIcon: false,
              onSelectionChanged: (selection) =>
                  ref.read(themeModeProvider.notifier).set(selection.single),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
