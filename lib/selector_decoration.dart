import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

/// Объявляет стиль отображения элемента выбора диапазона.
class SelectorDecoration with Diagnosticable {
  const SelectorDecoration({
    this.color,
    required this.border,
    this.errorBorder,
    this.borderRadius,
    this.boxShadow,
    this.gradient,
    this.backgroundBlendMode,
    this.dragHandleColor,
  }) : assert(
         backgroundBlendMode == null || color != null || gradient != null,
         "backgroundBlendMode applies to SelectorDecoration's background color or "
         'gradient, but no color or gradient was provided.',
       );

  SelectorDecoration copyWith({
    Color? color,
    Color? dragHandleColor,
    BoxBorder? border,
    BoxBorder? errorBorder,
    BorderRadiusGeometry? borderRadius,
    List<BoxShadow>? boxShadow,
    Gradient? gradient,
    BlendMode? backgroundBlendMode,
  }) {
    return SelectorDecoration(
      color: color ?? this.color,
      dragHandleColor: dragHandleColor ?? this.dragHandleColor,
      border: border ?? this.border,
      errorBorder: errorBorder ?? this.errorBorder,
      borderRadius: borderRadius ?? this.borderRadius,
      boxShadow: boxShadow ?? this.boxShadow,
      gradient: gradient ?? this.gradient,
      backgroundBlendMode: backgroundBlendMode ?? this.backgroundBlendMode,
    );
  }

  SelectorDecoration merge(SelectorDecoration other) => copyWith(
    color: other.color,
    dragHandleColor: other.dragHandleColor,
    border: other.border,
    errorBorder: other.errorBorder,
    borderRadius: other.borderRadius,
    boxShadow: other.boxShadow,
    gradient: other.gradient,
    backgroundBlendMode: other.backgroundBlendMode,
  );

  /// Цвет для заливки фона прямоугольника.
  ///
  /// Игнорируется, если [gradient] не равен null.
  final Color? color;

  /// Граница, которая рисуется над фоном [color], [gradient].
  ///
  /// Используйте объекты [Border] для описания границ, которые не зависят от направления чтения.
  ///
  /// Используйте объекты [BoxBorder] для описания границ, которые должны переворачивать свои левые
  /// и правые края в зависимости от того, читается ли текст слева направо или
  /// справа налево.
  final BoxBorder border;

  final BoxBorder? errorBorder;

  /// Если значение не равно нулю, углы скругляются на значение [BorderRadius].
  final BorderRadiusGeometry? borderRadius;

  /// Список теней, отбрасываемых прямоугольником позади себя.
  ///
  /// Смотрите также:
  ///
  ///  * [kElevationToShadow], предопределенные тени, используемые в Material Design.
  ///  * [PhysicalModel], виджет который рисует тени.
  final List<BoxShadow>? boxShadow;

  /// Градиент, используемый при заполнении поля.
  ///
  /// Полностью заполняет прямоугольник передаваемым [Gradient] и игнорирует параметр [color].
  final Gradient? gradient;

  /// Режим смешивания, применяемый к фону [color] или [gradient].
  ///
  /// Если [backgroundBlendMode] не указан, то используется режим смешивания по умолчанию.
  ///
  /// Если [color] или [gradient] не указан, то режим смешивания не оказывает никакого влияния.
  final BlendMode? backgroundBlendMode;

  /// Цвет якорей.
  ///
  /// Если цвет не указан, якоря не рисуются.
  final Color? dragHandleColor;

  SelectorDecoration scale(double factor) {
    return SelectorDecoration(
      color: Color.lerp(null, color, factor),
      border: BoxBorder.lerp(null, border, factor) ?? border,
      errorBorder: BoxBorder.lerp(null, errorBorder, factor),
      borderRadius: BorderRadiusGeometry.lerp(null, borderRadius, factor),
      boxShadow: BoxShadow.lerpList(null, boxShadow, factor),
      gradient: gradient?.scale(factor),
    );
  }

  static SelectorDecoration? lerp(SelectorDecoration? a, SelectorDecoration? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    if (a == null) {
      return b!.scale(t);
    }
    if (b == null) {
      return a.scale(1.0 - t);
    }
    if (t == 0.0) {
      return a;
    }
    if (t == 1.0) {
      return b;
    }
    return SelectorDecoration(
      color: Color.lerp(a.color, b.color, t),
      border: BoxBorder.lerp(a.border, b.border, t) ?? b.border,
      errorBorder: BoxBorder.lerp(a.errorBorder, b.errorBorder, t),
      borderRadius: BorderRadiusGeometry.lerp(a.borderRadius, b.borderRadius, t),
      boxShadow: BoxShadow.lerpList(a.boxShadow, b.boxShadow, t),
      gradient: Gradient.lerp(a.gradient, b.gradient, t),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is SelectorDecoration &&
        other.color == color &&
        other.dragHandleColor == dragHandleColor &&
        other.border == border &&
        other.errorBorder == errorBorder &&
        other.borderRadius == borderRadius &&
        listEquals<BoxShadow>(other.boxShadow, boxShadow) &&
        other.gradient == gradient &&
        other.backgroundBlendMode == backgroundBlendMode;
  }

  @override
  int get hashCode => Object.hash(
    color,
    dragHandleColor,
    border,
    errorBorder,
    borderRadius,
    boxShadow == null ? null : Object.hashAll(boxShadow!),
    gradient,
    backgroundBlendMode,
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..defaultDiagnosticsTreeStyle = DiagnosticsTreeStyle.whitespace
      ..emptyBodyDescription = '<no decorations specified>';

    properties.add(ColorProperty('color', color, defaultValue: null));
    properties.add(DiagnosticsProperty<BoxBorder>('border', border, defaultValue: null));
    properties.add(DiagnosticsProperty<BorderRadiusGeometry>('borderRadius', borderRadius, defaultValue: null));
    properties.add(
      IterableProperty<BoxShadow>('boxShadow', boxShadow, defaultValue: null, style: DiagnosticsTreeStyle.whitespace),
    );
    properties.add(DiagnosticsProperty<Gradient>('gradient', gradient, defaultValue: null));
  }

  /// Проверка попадания.
  bool hitTest(Size size, Offset position, {TextDirection? textDirection}) {
    assert((Offset.zero & size).contains(position));
    if (borderRadius != null) {
      final RRect bounds = borderRadius!.resolve(textDirection).toRRect(Offset.zero & size);
      return bounds.contains(position);
    }
    return true;
  }

  /// Рисует прямоугольник в заданных [rect] ограничениях.
  ///
  /// Обратите внимание, если вы указали [border] или [errorBorder], то вам надо явно передать именованный
  /// параметр [border] в метод.
  void paint(Canvas canvas, Rect rect, [BoxBorder? border, TextDirection? textDirection]) =>
      _SelectorDecorationPainter(this).paint(canvas, rect, border, textDirection);
}

class _SelectorDecorationPainter {
  _SelectorDecorationPainter(this.decoration);

  final SelectorDecoration decoration;

  Paint? _cachedBackgroundPaint;
  Rect? _rectForCachedBackgroundPaint;

  Paint _getBackgroundPaint(Rect rect, TextDirection? textDirection) {
    assert(decoration.gradient != null || _rectForCachedBackgroundPaint == null);

    if (_cachedBackgroundPaint == null || (decoration.gradient != null && _rectForCachedBackgroundPaint != rect)) {
      final Paint paint = Paint();
      if (decoration.backgroundBlendMode != null) {
        paint.blendMode = decoration.backgroundBlendMode!;
      }
      if (decoration.color != null) {
        paint.color = decoration.color!;
      }
      if (decoration.gradient != null) {
        paint.shader = decoration.gradient!.createShader(rect, textDirection: textDirection);
        _rectForCachedBackgroundPaint = rect;
      }
      _cachedBackgroundPaint = paint;
    }

    return _cachedBackgroundPaint!;
  }

  void _paintBox(Canvas canvas, Rect rect, Paint paint, TextDirection? textDirection) {
    if (decoration.borderRadius == null || decoration.borderRadius == BorderRadius.zero) {
      canvas.drawRect(rect, paint);
    } else {
      canvas.drawRRect(decoration.borderRadius!.resolve(textDirection).toRRect(rect), paint);
    }
  }

  void _paintShadows(Canvas canvas, Rect rect, TextDirection? textDirection) {
    if (decoration.boxShadow == null) {
      return;
    }
    for (final BoxShadow boxShadow in decoration.boxShadow!) {
      final Paint paint = boxShadow.toPaint();
      final Rect bounds = rect.shift(boxShadow.offset).inflate(boxShadow.spreadRadius);
      assert(() {
        if (debugDisableShadows && boxShadow.blurStyle == BlurStyle.outer) {
          canvas.save();
          canvas.clipRect(bounds);
        }
        return true;
      }());
      _paintBox(canvas, bounds, paint, textDirection);
      assert(() {
        if (debugDisableShadows && boxShadow.blurStyle == BlurStyle.outer) {
          canvas.restore();
        }
        return true;
      }());
    }
  }

  double _calculateAdjustedSide(BorderSide side) {
    if (side.color.a == 255 && side.style == BorderStyle.solid) {
      return side.strokeInset;
    }
    return 0;
  }

  Rect _adjustedRectOnOutlinedBorder(Rect rect, BoxBorder? border, TextDirection? textDirection) {
    if (border == null) {
      return rect;
    }

    if (border case final Border border) {
      final EdgeInsets insets =
          EdgeInsets.fromLTRB(
            _calculateAdjustedSide(border.left),
            _calculateAdjustedSide(border.top),
            _calculateAdjustedSide(border.right),
            _calculateAdjustedSide(border.bottom),
          ) /
          2;

      return Rect.fromLTRB(
        rect.left + insets.left,
        rect.top + insets.top,
        rect.right - insets.right,
        rect.bottom - insets.bottom,
      );
    } else if (border case final BorderDirectional border) {
      if (textDirection == null) return rect;

      final BorderSide leftSide = textDirection == TextDirection.rtl ? border.end : border.start;
      final BorderSide rightSide = textDirection == TextDirection.rtl ? border.start : border.end;

      final EdgeInsets insets =
          EdgeInsets.fromLTRB(
            _calculateAdjustedSide(leftSide),
            _calculateAdjustedSide(border.top),
            _calculateAdjustedSide(rightSide),
            _calculateAdjustedSide(border.bottom),
          ) /
          2;

      return Rect.fromLTRB(
        rect.left + insets.left,
        rect.top + insets.top,
        rect.right - insets.right,
        rect.bottom - insets.bottom,
      );
    }
    return rect;
  }

  void _paintBackgroundColor(Canvas canvas, Rect rect, BoxBorder? border, TextDirection? textDirection) {
    if (decoration.color != null || decoration.gradient != null) {
      final Rect adjustedRect = _adjustedRectOnOutlinedBorder(rect, border, textDirection);
      _paintBox(canvas, adjustedRect, _getBackgroundPaint(rect, textDirection), textDirection);
    }
  }

  void paint(Canvas canvas, Rect rect, [BoxBorder? border, TextDirection? textDirection]) {
    _paintShadows(canvas, rect, textDirection);
    _paintBackgroundColor(canvas, rect, border, textDirection);
    border?.paint(
      canvas,
      rect,
      borderRadius: decoration.borderRadius?.resolve(textDirection),
      textDirection: textDirection,
    );

    final dragHandleColor = decoration.dragHandleColor;
    if (dragHandleColor == null) return;

    final linePaint =
        Paint()
          ..color = dragHandleColor
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.fill;

    final shift = border != null ? Offset(border.dimensions.horizontal / 4, 0) : Offset.zero;

    final verticalSpace = rect.height * .21;

    canvas.drawLine(
      (rect.topLeft + shift) + Offset(0, verticalSpace),
      (rect.bottomLeft + shift) - Offset(0, verticalSpace),
      linePaint,
    );

    canvas.drawLine(
      (rect.topRight - shift) + Offset(0, verticalSpace),
      (rect.bottomRight - shift) - Offset(0, verticalSpace),
      linePaint,
    );
  }
}
