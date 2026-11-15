import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../utils/constants.dart';

/// 地图底色：宣纸卷轴，深色模式换成夜色羊皮。
class MapPalette {
  const MapPalette({
    required this.parchmentTop, required this.parchmentBottom,
    required this.ink, required this.road, required this.river,
    required this.mountain, required this.frame, required this.regionText,
  });

  final Color parchmentTop, parchmentBottom, ink, road;
  final Color river, mountain, frame, regionText;

  static const light = MapPalette(
    parchmentTop: Color(0xFFF7EBD2), parchmentBottom: Color(0xFFE9D6B2),
    ink: Color(0xFF3A2A1C), road: Color(0xFF9C7C4F),
    river: Color(0xFF5B7F8C), mountain: Color(0xFF8A7550),
    frame: Color(0xFFC8A15A), regionText: Color(0xFF7A5C36),
  );

  static const dark = MapPalette(
    parchmentTop: Color(0xFF2C2116), parchmentBottom: Color(0xFF1C150E),
    ink: Color(0xFFEDDCBE), road: Color(0xFF8A6D44),
    river: Color(0xFF4E7280), mountain: Color(0xFF6A5638),
    frame: Color(0xFF9C7B42), regionText: Color(0xFFB99A6B),
  );

  static MapPalette of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}

/// 州名水印位置，配合 [kMapDesignSize] 使用。
const List<({String name, Offset position})> kRegionLabels = [
  (name: '凉州', position: Offset(205, 120)), (name: '雍州', position: Offset(350, 185)),
  (name: '并州', position: Offset(470, 118)), (name: '冀州', position: Offset(650, 185)),
  (name: '幽州', position: Offset(600, 55)), (name: '青州', position: Offset(765, 192)),
  (name: '兖州', position: Offset(612, 322)), (name: '豫州', position: Offset(548, 438)),
  (name: '司隶', position: Offset(468, 255)), (name: '荆州', position: Offset(548, 612)),
  (name: '扬州', position: Offset(772, 420)), (name: '益州', position: Offset(300, 472)),
];

/// 画整幅地图的底子：宣纸渐变、卷轴边框、江河、山脉与州名水印。
void paintMapBackground(
  Canvas canvas,
  Size size,
  MapPalette palette, {
  double designWidth = 1200,
  double designHeight = 760,
  String? fontFamily,
}) {
  final rect = Offset.zero & size;
  final base = Paint()
    ..shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [palette.parchmentTop, palette.parchmentBottom],
    ).createShader(rect);
  canvas.drawRect(rect, base);

  // 细密的纤维纹路，模仿手工宣纸。
  final fiber = Paint()
    ..strokeWidth = 0.7
    ..color = palette.ink.withValues(alpha: 0.045);
  for (var i = 0; i < 90; i++) {
    final y = (i + 0.5) * size.height / 90;
    final wave = math.sin(i * 1.7) * size.width * 0.012;
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y + wave),
      fiber,
    );
  }

  final scale = size.width / designWidth;
  canvas.save();
  canvas.scale(scale, scale);

  _paintRiver(
    canvas,
    palette,
    Path()
      ..moveTo(210, 205)
      ..cubicTo(330, 268, 462, 232, 558, 258)
      ..cubicTo(648, 282, 742, 238, 862, 296)
      ..cubicTo(920, 324, 960, 318, 1010, 300),
  );
  _paintRiver(
    canvas,
    palette,
    Path()
      ..moveTo(300, 462)
      ..cubicTo(420, 508, 520, 566, 620, 582)
      ..cubicTo(720, 598, 830, 584, 960, 520),
  );

  _paintMountains(canvas, palette, const Offset(120, 330), 7, 0.9);
  _paintMountains(canvas, palette, const Offset(250, 420), 6, 0.8);
  _paintMountains(canvas, palette, const Offset(300, 610), 7, 0.85);
  _paintMountains(canvas, palette, const Offset(880, 600), 5, 0.7);
  _paintMountains(canvas, palette, const Offset(150, 120), 4, 0.7);

  for (final region in kRegionLabels) {
    _paintRegionText(canvas, palette, region.name, region.position, fontFamily);
  }

  final frame = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..color = palette.frame.withValues(alpha: 0.55);
  final outer = RRect.fromRectAndRadius(
    Rect.fromLTWH(14, 14, designWidth - 28, designHeight - 28),
    const Radius.circular(10),
  );
  canvas.drawRRect(outer, frame);
  canvas.drawRRect(
    outer.deflate(7),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = palette.frame.withValues(alpha: 0.3),
  );
  canvas.restore();
}

void _paintRiver(Canvas canvas, MapPalette palette, Path path) {
  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round
      ..color = palette.river.withValues(alpha: 0.14),
  );
  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = palette.river.withValues(alpha: 0.38),
  );
}

void _paintMountains(
  Canvas canvas,
  MapPalette palette,
  Offset origin,
  int count,
  double strength,
) {
  final paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..strokeCap = StrokeCap.round
    ..color = palette.mountain.withValues(alpha: 0.22 * strength);
  final random = math.Random(origin.dx.round() * 31 + origin.dy.round());
  for (var i = 0; i < count; i++) {
    final base = origin +
        Offset(
          random.nextDouble() * 160 - 80,
          random.nextDouble() * 70 - 35,
        );
    final width = 20 + random.nextDouble() * 26;
    final height = 12 + random.nextDouble() * 18;
    final path = Path()
      ..moveTo(base.dx - width / 2, base.dy)
      ..lineTo(base.dx, base.dy - height)
      ..lineTo(base.dx + width / 2, base.dy);
    canvas.drawPath(path, paint);
    canvas.drawLine(
      Offset(base.dx - 4, base.dy - height * 0.3),
      Offset(base.dx + 4, base.dy - height * 0.3),
      paint,
    );
  }
}

/// 州名水印的文字缓存：同一条水印只排版一次，深浅色各一份。
/// 缓存上限为州名数 × 2，长期运行不会增长。
final Map<int, TextPainter> _regionPainters = {};

/// 已排版的州名水印数量，供性能测试断言缓存命中。
@visibleForTesting
int get regionPainterCount => _regionPainters.length;

void _paintRegionText(
  Canvas canvas,
  MapPalette palette,
  String text,
  Offset center,
  String? fontFamily,
) {
  final key = Object.hash(text, palette.regionText, fontFamily);
  final painter = _regionPainters.putIfAbsent(
    key,
    () => TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 52,
          fontWeight: FontWeight.w700,
          letterSpacing: 10,
          color: palette.regionText.withValues(alpha: 0.16),
          fontFamily: fontFamily ?? (kIsWeb ? kWebFontFamily : null),
          fontFamilyFallback: kKaiFontFallback,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(),
  );
  painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
}

/// 城池之间的虚线驿道，选中城池时高亮可进攻路线。
void paintRoad(
  Canvas canvas,
  Offset from,
  Offset to,
  Color color,
  double width, {
  double dashLength = 9,
  double gapLength = 7,
}) {
  final paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..color = color;
  final delta = to - from;
  final distance = delta.distance;
  if (distance <= 0) return;
  final unit = delta / distance;
  var travelled = 0.0;
  while (travelled < distance) {
    final end = math.min(travelled + dashLength, distance);
    canvas.drawLine(from + unit * travelled, from + unit * end, paint);
    travelled = end + gapLength;
  }
}
