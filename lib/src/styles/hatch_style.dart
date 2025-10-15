import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Hatching style for displaying inactive area.
@immutable
class HatchStyle {
  const HatchStyle({
    this.backgroundColor = const Color.fromARGB(95, 230, 235, 243),
    this.space = 8.0,
    this.strokeColor = const Color.fromARGB(80, 194, 197, 204),
    this.strokeWidth = 1,
  });

  final Color backgroundColor;
  final Color strokeColor;
  final double strokeWidth;
  final double space;

  HatchStyle copyWith({Color? backgroundColor, Color? strokeColor, double? strokeWidth, double? space}) => HatchStyle(
        backgroundColor: backgroundColor ?? this.backgroundColor,
        strokeColor: strokeColor ?? this.strokeColor,
        strokeWidth: strokeWidth ?? this.strokeWidth,
        space: space ?? this.space,
      );

  @override
  int get hashCode => Object.hash(runtimeType, backgroundColor, strokeColor, strokeWidth, space);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HatchStyle &&
          runtimeType == other.runtimeType &&
          backgroundColor == other.backgroundColor &&
          strokeColor == other.strokeColor &&
          strokeWidth == other.strokeWidth &&
          space == other.space;
}
