import 'package:material_ui/material_ui.dart';
import 'package:resqmesh/app/theme/tokens.dart';

/// The ResQMesh mark: a hub icon on a rounded tonal tile.
class AppMark extends StatelessWidget {
  const AppMark({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(size * AppRadii.lg / 96),
        ),
        child: Icon(
          Icons.hub_rounded,
          size: size / 2,
          color: scheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
