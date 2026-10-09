import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:resqmesh/app/theme/tokens.dart';
import 'package:resqmesh/core/connection/connection_method.dart';
import 'package:resqmesh/core/connection/connection_providers.dart';
import 'package:resqmesh/core/constants/brand.dart';
import 'package:resqmesh/core/identity/identity_providers.dart';
import 'package:resqmesh/core/network/discovery/discovery_engine.dart';
import 'package:resqmesh/core/network/lan_providers.dart';
import 'package:resqmesh/shared/widgets/connection_method_picker.dart';
import 'package:resqmesh/shared/widgets/mesh_illustration.dart';
import 'package:resqmesh/shared/widgets/name_form.dart';

/// First launch in three steps: welcome, choose your name (spec §5), choose
/// how to connect. Choosing a connection method finishes onboarding and the
/// router moves on to Home.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _steps = 3;
  static const _connectStep = 2;

  // Someone who already has a name only needs to choose how to connect.
  late final int _firstStep = ref.read(identityProvider).hasName
      ? _connectStep
      : 0;
  late final PageController _pages = PageController(initialPage: _firstStep);
  late int _step = _firstStep;

  @override
  void initState() {
    super.initState();
    // Start listening early, so the name check knows who is around.
    ref.read(discoveryEngineProvider);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _goTo(int step) async {
    FocusScope.of(context).unfocus();
    setState(() => _step = step);
    final duration = AppMotion.of(context, AppMotion.long);
    if (duration == Duration.zero) {
      _pages.jumpToPage(step);
      return;
    }
    await _pages.animateToPage(
      step,
      duration: duration,
      curve: AppMotion.emphasized,
    );
  }

  @override
  Widget build(BuildContext context) {
    final canGoBack = _step > _firstStep;
    return PopScope(
      canPop: !canGoBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goTo(_step - 1);
      },
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                children: [
                  _TopBar(
                    step: _step,
                    steps: _steps,
                    onBack: canGoBack ? () => _goTo(_step - 1) : null,
                  ),
                  Expanded(
                    child: PageView(
                      controller: _pages,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _WelcomeStep(onNext: () => _goTo(1)),
                        _NameStep(onDone: () => _goTo(_connectStep)),
                        const _ConnectStep(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.step, required this.steps, this.onBack});

  final int step;
  final int steps;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final duration = AppMotion.of(context, AppMotion.medium);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 48,
            child: onBack == null
                ? null
                : IconButton(
                    tooltip: 'Back',
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
          ),
          Expanded(
            child: Semantics(
              label: 'Step ${step + 1} of $steps',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < steps; i++)
                    AnimatedContainer(
                      duration: duration,
                      curve: AppMotion.emphasized,
                      margin: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                      ),
                      width: i == step ? 32 : 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: i <= step
                            ? scheme.primary
                            : scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox.square(dimension: 48),
        ],
      ),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              children: [
                const Center(child: MeshIllustration(size: 220)),
                const SizedBox(height: AppSpacing.xxl),
                Semantics(
                  header: true,
                  child: Text(
                    'Talk when the internet is down',
                    style: theme.textTheme.displaySmall,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '${Brand.name} connects phones that are close to each other. '
                  'No internet, no account, no cloud.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                const _Feature(
                  icon: Icons.forum_rounded,
                  title: 'Chat one to one or with everyone',
                  body: 'Messages wait and send when the other phone is back.',
                ),
                const _Feature(
                  icon: Icons.folder_zip_rounded,
                  title: 'Share files of any size',
                  body: 'Photos, videos and documents go straight to them.',
                ),
                const _Feature(
                  icon: Icons.lock_rounded,
                  title: 'Stays on your phones',
                  body: 'Nothing is uploaded anywhere.',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: FilledButton(
              onPressed: onNext,
              child: const Text('Get started'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Icon(icon, color: scheme.onSecondaryContainer),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NameStep extends ConsumerWidget {
  const _NameStep({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: NameForm(
        submitLabel: 'Continue',
        busyMessage: 'Checking name on this network…',
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                'Choose your name',
                style: theme.textTheme.displaySmall,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'People nearby will see this name. You can change it later '
              'in Settings.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        onSubmit: (name) async {
          final check = await ref.read(discoveryEngineProvider).checkName(name);
          if (check.outcome == NameCheckOutcome.taken) return nameTakenMessage;
          await ref.read(identityProvider.notifier).setUsername(name);
          onDone();
          return null;
        },
      ),
    );
  }
}

class _ConnectStep extends ConsumerStatefulWidget {
  const _ConnectStep();

  @override
  ConsumerState<_ConnectStep> createState() => _ConnectStepState();
}

class _ConnectStepState extends ConsumerState<_ConnectStep> {
  ConnectionMethod _method = ConnectionMethod.wifiRouter;
  bool _busy = false;

  Future<void> _finish() async {
    setState(() => _busy = true);
    try {
      await ref.read(connectionMethodProvider.notifier).choose(_method);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    'How do you want to connect?',
                    style: theme.textTheme.displaySmall,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Pick what the people around you can use. You can change '
                  'this any time in Settings.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                ConnectionMethodPicker(
                  selected: _method,
                  onSelected: (method) => setState(() => _method = method),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: FilledButton.icon(
              onPressed: _busy ? null : _finish,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Start'),
            ),
          ),
        ],
      ),
    );
  }
}
