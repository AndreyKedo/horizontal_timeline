import 'dart:math' as math;

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
    this.shape = BoxShape.rectangle,
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
    BoxShape? shape,
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
      shape: shape ?? this.shape,
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
    shape: other.shape,
  );

  final Color? color;

  final BoxBorder border;

  final BoxBorder? errorBorder;

  final BorderRadiusGeometry? borderRadius;

  final List<BoxShadow>? boxShadow;

  final Gradient? gradient;

  final BlendMode? backgroundBlendMode;

  final Color? dragHandleColor;

  final BoxShape shape;

  /// Returns a new box decoration that is scaled by the given factor.
  SelectorDecoration scale(double factor) {
    return SelectorDecoration(
      color: Color.lerp(null, color, factor),
      border: BoxBorder.lerp(null, border, factor) ?? border,
      errorBorder: BoxBorder.lerp(null, errorBorder, factor),
      borderRadius: BorderRadiusGeometry.lerp(null, borderRadius, factor),
      boxShadow: BoxShadow.lerpList(null, boxShadow, factor),
      gradient: gradient?.scale(factor),
      shape: shape,
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
      shape: t < 0.5 ? a.shape : b.shape,
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
        other.backgroundBlendMode == backgroundBlendMode &&
        other.shape == shape;
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
    shape,
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
    properties.add(EnumProperty<BoxShape>('shape', shape, defaultValue: BoxShape.rectangle));
  }

  bool hitTest(Size size, Offset position, {TextDirection? textDirection}) {
    assert((Offset.zero & size).contains(position));
    switch (shape) {
      case BoxShape.rectangle:
        if (borderRadius != null) {
          final RRect bounds = borderRadius!.resolve(textDirection).toRRect(Offset.zero & size);
          return bounds.contains(position);
        }
        return true;
      case BoxShape.circle:
        // Circles are inscribed into our smallest dimension.
        final Offset center = size.center(Offset.zero);
        final double distance = (position - center).distance;
        return distance <= math.min(size.width, size.height) / 2.0;
    }
  }

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
    switch (decoration.shape) {
      case BoxShape.circle:
        assert(decoration.borderRadius == null);
        final Offset center = rect.center;
        final double radius = rect.shortestSide / 2.0;
        canvas.drawCircle(center, radius, paint);
      case BoxShape.rectangle:
        if (decoration.borderRadius == null || decoration.borderRadius == BorderRadius.zero) {
          canvas.drawRect(rect, paint);
        } else {
          canvas.drawRRect(decoration.borderRadius!.resolve(textDirection).toRRect(rect), paint);
        }
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
      shape: decoration.shape,
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
