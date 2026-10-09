import 'package:material_ui/material_ui.dart';
import 'package:resqmesh/app/theme/tokens.dart';
import 'package:resqmesh/core/identity/username.dart';

/// Saves a validated, normalised name. Returns an error message to show
/// under the field (for example a name clash), or null on success.
typedef NameSubmit = Future<String?> Function(String name);

/// Spec §5 wording when another device on the network has the name.
const nameTakenMessage = 'This name is already being used on this network.';

/// Name field with live validation and a full-width submit button pinned to
/// the bottom. Used by onboarding and Settings → Change name.
class NameForm extends StatefulWidget {
  const NameForm({
    super.key,
    required this.header,
    required this.submitLabel,
    required this.onSubmit,
    this.initialName,
    this.busyMessage,
  });

  final Widget header;
  final String submitLabel;
  final NameSubmit onSubmit;
  final String? initialName;

  /// Shown under the field while [onSubmit] runs.
  final String? busyMessage;

  @override
  State<NameForm> createState() => _NameFormState();
}

String usernameErrorText(UsernameError error) => switch (error) {
  UsernameError.empty => 'Enter a name',
  UsernameError.tooShort => 'Use at least ${Username.minLength} characters',
  UsernameError.tooLong => 'Use ${Username.maxLength} characters or fewer',
  UsernameError.invalidCharacters =>
    "Names can't contain line breaks or control characters",
};

class _NameFormState extends State<NameForm> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName,
  );
  bool _attempted = false;
  bool _busy = false;
  String? _submitError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  UsernameValidation get _validation => Username.validate(_controller.text);

  /// Short and empty names are only flagged after a submit attempt; names
  /// that are too long or contain bad characters are flagged at once.
  String? get _errorText {
    if (_submitError != null) return _submitError;
    final validation = _validation;
    if (validation is! InvalidUsername) return null;
    final immediate =
        validation.error == UsernameError.tooLong ||
        validation.error == UsernameError.invalidCharacters;
    return immediate || _attempted ? usernameErrorText(validation.error) : null;
  }

  Future<void> _submit() async {
    setState(() => _attempted = true);
    final validation = _validation;
    if (validation is! ValidUsername || _busy) return;
    setState(() {
      _busy = true;
      _submitError = null;
    });
    String? error;
    try {
      error = await widget.onSubmit(validation.name);
    } on Exception {
      error = "Couldn't save your name. Try again.";
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _submitError = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final length = Username.length(Username.normalize(_controller.text));
    final tooLong = length > Username.maxLength;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            children: [
              widget.header,
              const SizedBox(height: AppSpacing.xxl),
              TextField(
                controller: _controller,
                autofocus: true,
                enabled: !_busy,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                onChanged: (_) => setState(() => _submitError = null),
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Your name',
                  helperText: _busy && widget.busyMessage != null
                      ? widget.busyMessage
                      : '${Username.minLength}–${Username.maxLength} characters',
                  errorText: _errorText,
                  counterText: '$length/${Username.maxLength}',
                  counterStyle: tooLong
                      ? TextStyle(color: theme.colorScheme.error)
                      : null,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  )
                : Text(widget.submitLabel),
          ),
        ),
      ],
    );
  }
}
