import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:resqmesh/app/theme/tokens.dart';
import 'package:resqmesh/core/constants/brand.dart';
import 'package:resqmesh/core/platform/app_info_provider.dart';
import 'package:resqmesh/core/settings/developer_mode.dart';
import 'package:resqmesh/shared/widgets/app_mark.dart';

/// What the app keeps and who can see it (Settings → Privacy, About).
const privacyText =
    '${Brand.name} works only on your local network. Nothing goes to the '
    'internet, and there are no accounts.\n\n'
    'Your chats and files are stored only on this phone.\n\n'
    'Messages and files are not encrypted on the network. People on the '
    'same Wi-Fi with special tools could see them, so use networks you '
    'trust, or your own hotspot.';

/// About (P11.5): what the app does, version, privacy and licences.
/// Tapping the version 7 times unlocks the developer screen (spec §34).
class AboutScreen extends ConsumerStatefulWidget {
  const AboutScreen({super.key});

  @override
  ConsumerState<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends ConsumerState<AboutScreen> {
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
    final theme = Theme.of(context);
    final version = ref.watch(appInfoProvider).value?.label ?? '…';
    const tile = EdgeInsets.symmetric(
      horizontal: AppSpacing.xl,
      vertical: AppSpacing.sm,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.lg,
          AppSpacing.gutter,
          AppSpacing.xxl,
        ),
        children: [
          const Center(child: AppMark(size: 88)),
          const SizedBox(height: AppSpacing.lg),
          Text(
            Brand.name,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Chat and share files with people nearby. No internet needed.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const Card(
            child: Column(
              children: [
                ListTile(
                  contentPadding: tile,
                  leading: Icon(Icons.wifi_rounded),
                  title: Text('Same Wi-Fi or hotspot'),
                  subtitle: Text(
                    'Join one network. The router does not need internet.',
                  ),
                ),
                ListTile(
                  contentPadding: tile,
                  leading: Icon(Icons.radar_rounded),
                  title: Text('Finds people by itself'),
                  subtitle: Text('Everyone nearby appears in People.'),
                ),
                ListTile(
                  contentPadding: tile,
                  leading: Icon(Icons.swap_horiz_rounded),
                  title: Text('Phone to phone'),
                  subtitle: Text(
                    'Messages and files go straight to the other phone, '
                    'and are checked when they arrive.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Card(
            child: Column(
              children: [
                ListTile(
                  contentPadding: tile,
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacy'),
                  subtitle: const Text(privacyText),
                ),
                ListTile(
                  contentPadding: tile,
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Open-source licences'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: Brand.name,
                    applicationVersion: version,
                  ),
                ),
                ListTile(
                  contentPadding: tile,
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('Version'),
                  subtitle: Text(version),
                  onTap: _onVersionTap,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
