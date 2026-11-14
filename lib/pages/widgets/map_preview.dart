import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../game/data/scenario.dart';
import '../../models/faction.dart';
import '../../theme/map_painting.dart';
import '../../utils/constants.dart';
import '../../utils/map_layout.dart';

/// 首页的天下形势缩略图：宣纸底、驿道与五色城池。
class MapPreview extends StatelessWidget {
  const MapPreview({super.key, required this.brightness});

  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: kMapDesignSize.width / kMapDesignSize.height,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.outline),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          // 首页滚动时不让整幅缩略图跟着重绘，底图只在尺寸或主题变化时再画。
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _MapPreviewPainter(
                palette: MapPalette.of(brightness),
                brightness: brightness,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapPreviewPainter extends CustomPainter {
  const _MapPreviewPainter({required this.palette, required this.brightness});

  final MapPalette palette;
  final Brightness brightness;

  @override
  void paint(Canvas canvas, Size size) {
    paintMapBackground(
      canvas,
      size,
      palette,
      fontFamily: kIsWeb ? kWebFontFamily : null,
    );
    final scale = size.width / kMapDesignSize.width;
    final cities = {for (final def in Scenario.cityDefs) def.id: def};
    final seen = <String>{};
    for (final city in Scenario.cityDefs) {
      for (final neighbor in city.neighbors) {
        final key = city.id.compareTo(neighbor) < 0
            ? '${city.id}-$neighbor'
            : '$neighbor-${city.id}';
        if (!seen.add(key)) continue;
        final other = cities[neighbor]!;
        paintRoad(
          canvas,
          city.position * scale,
          other.position * scale,
          city.owner == other.owner
              ? FactionDefs.colorOf(city.owner).withValues(alpha: 0.35)
              : palette.road.withValues(alpha: 0.4),
          1.4,
          dashLength: 5,
          gapLength: 4,
        );
      }
    }
    for (final city in Scenario.cityDefs) {
      final center = city.position * scale;
      canvas.drawCircle(
        center + const Offset(0, 1.5),
        7 * scale,
        Paint()..color = Colors.black.withValues(alpha: 0.2),
      );
      canvas.drawCircle(
        center,
        7 * scale,
        Paint()..color = FactionDefs.colorOf(city.owner),
      );
      canvas.drawCircle(
        center,
        2.4 * scale,
        Paint()..color = const Color(0xFFFFF1D0),
      );
    }
  }

  @override
  bool shouldRepaint(_MapPreviewPainter oldDelegate) =>
      oldDelegate.brightness != brightness;
}
