library;

import 'dart:ui';

import 'package:flutter/foundation.dart' show ValueListenable, setEquals;
import 'package:flutter/material.dart';
import 'package:horizontal_timeline/src/animated_render_object.dart';
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:horizontal_timeline/src/render_utils.dart';
import 'package:horizontal_timeline/src/styles/hatch_style.dart';
import 'package:horizontal_timeline/src/styles/selector_decoration.dart';
import 'package:horizontal_timeline/src/time_extension.dart';
import 'package:horizontal_timeline/src/time_range.dart';

export 'package:horizontal_timeline/src/styles/selector_decoration.dart';
export 'package:horizontal_timeline/src/styles/hatch_style.dart';
export 'package:horizontal_timeline/src/time_extension.dart';
export 'package:horizontal_timeline/src/time_range.dart';

/// Constant time shift in minutes.
const kMinutesShift = 15;

/// Number of divisions on the time scale.
const kSteps = kMinutesPerDay / kMinutesShift;

/// Padding between text and the bottom border of the time scale.
const kTopPaddingOfTimeLabel = 6.0;

/// Width of the area within which gestures for capturing the left and right edges of the selection area work.
const kDragArea = 48.0;

/// Minimum allowable value of the gap between divisions.
const kMinGap = 24.0;

/// Horizontal padding when focusing on the available area.
const kHorizontalFocusPadding = 32.0;

/// Sensitivity factor at which a scroll gesture will be detected.
const kScrollThreshold = 5.0;

/// Horizontal scroll sensitivity.
const kAxisScrollThreshold = 100.0;

const kDefaultSelectorStyle = SelectorDecoration(
  border: Border.symmetric(
    horizontal: BorderSide(color: Colors.blue, width: 2),
    vertical: BorderSide(color: Colors.blue, width: 6),
  ),
  errorBorder: Border.symmetric(
    horizontal: BorderSide(color: Colors.red, width: 2),
    vertical: BorderSide(color: Colors.red, width: 6),
  ),
  color: Color.fromARGB(100, 178, 208, 255),
  borderRadius: BorderRadius.all(Radius.circular(2)),
  dragHandleColor: Colors.white,
);

/// Default animation style for the time selection scale.
final kDefaultSelectorAnimationStyle = AnimationStyle(curve: Curves.easeInOut, duration: Durations.short3);

/// Default scroll animation style.
final kDefaultScrollAnimationStyle = AnimationStyle(curve: Curves.linear, duration: Durations.short2);

/// Unary callback type that accepts an argument of type [TimeRange].
typedef OnChangeSelectorRange = void Function(TimeRange value);

/// Selector drag direction
enum DragDirection {
  /// Drag to the left
  left,

  /// Drag to the right
  right;

  const DragDirection();

  factory DragDirection.fromPoints(double x1, double x2) {
    if (x1 < x2) {
      return DragDirection.left;
    } else {
      return DragDirection.right;
    }
  }
}

@immutable
class FocusPosition {
  const FocusPosition({required this.time, required this.alignment});

  final TimeOfDay time;
  final Alignment alignment;

  @override
  int get hashCode => Object.hash(runtimeType, time, alignment);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FocusPosition && runtimeType == other.runtimeType && time == other.time && alignment == other.alignment;
}

/// {@template timeline}
/// A widget that displays a 24-hour timeline with the ability to select a specific time range.
/// When the selected range changes, the [onChange] callback is automatically called, accepting an argument
/// of type [TimeRange].
///
/// The initial position of the time range selector element is set using the [initialSelectorRange] property.
/// The minimum allowable range value is set using the [minSelectorRange] property.
/// Customization of the appearance is available through the [selectorDecoration] property.
///
/// The time scale step is configured using the [gap] parameter - its value must not be
/// less than the value of [kMinGap].
/// Available time intervals are specified in the [availableRanges] property.
///
/// Additional visualization settings are made through the following properties:
/// * [timeScaleColor]: Scale outline color.
/// * [strokeWidth]: Outline line thickness.
/// * [timeLabelStyle]: Style of time label text.
/// * [enabledLabelStyle]: Style of available time interval labels.
/// * [disabledLabelStyle]: Style of unavailable time interval labels.
/// * [hatchStyle]: Hatching style to indicate unavailable intervals.
///
/// This widget automatically finds the nearest parent [Scrollable] widget to interact with scrolling.
/// Make sure this widget is a descendant of another widget like [SingleChildScrollView],
/// but does **not support** use within [CustomScrollView].
/// Note that only horizontal orientation [Axis.horizontal] is supported, and you must also
/// apply the property [Scrollable.hitTestBehavior] = [HitTestBehavior.deferToChild] in parent widgets for
/// proper gesture handling.
///
/// The widget itself does not set its own minimum height, so it takes the height of its
/// parent container. You need to carefully monitor the setting of the widget's maximum height,
/// using widgets such as [ConstrainedBox] before adding it inside [SingleChildScrollView].
///
/// Usage example
///
/// ```dart
/// import 'package:flutter/material.dart';
/// import 'package:horizontal_timeline/horizontal_timeline.dart';
///
/// void main() {
///   runApp(const MainApp());
/// }
///
/// class MainApp extends StatelessWidget {
///   const MainApp({super.key});
///
///   @override
///   Widget build(BuildContext context) {
///     return MaterialApp(
///       home: ConstrainedBox(
///               constraints: BoxConstraints.loose(Size.fromHeight(75)),
///               child: SingleChildScrollView(
///                 scrollDirection: Axis.horizontal,
///                 hitTestBehavior: HitTestBehavior.deferToChild,
///                 child: Timeline(
///                   initialSelectorRange: TimeRange(begin: TimeOfDay(hour: 9, minute: 0), end: TimeOfDay(hour: 10, minute: 0)),
///                   availableRanges: {TimeRange(begin: TimeOfDay(hour: 9, minute: 0), end: TimeOfDay(hour: 18, minute: 0))},
///                 ),
///             ),
///         ),
///     );
///   }
/// }
/// ```
/// {@endtemplate}
class Timeline extends LeafRenderObjectWidget {
  /// {@macro timeline}
  const Timeline({
    super.key,
    this.initialSelectorRange,
    this.focusTimePosition,
    this.onChange,
    this.availableRanges = const {},
    this.timeScaleColor = const Color(0xFFC2C5CC),
    this.strokeWidth = 1,
    this.gap = kMinGap,
    this.timeLabelStyle = const TextStyle(color: Color(0xFF1A1A1A), fontSize: 8),
    this.enabledLabelStyle = const TextStyle(color: Color(0xFF1A1A1A)),
    this.disabledLabelStyle = const TextStyle(color: Color(0xFFACADB3)),
    this.hatchStyle = const HatchStyle(),
    this.selectorDecoration = kDefaultSelectorStyle,
    this.minSelectorRange = const TimeOfDay(hour: 0, minute: 30),
    this.scrollAnimationStyle,
    this.animationStyle,
    this.space = kTopPaddingOfTimeLabel,
    this.focusTimeAlignment = Alignment.center,
  });

  /// Initial time range value. If null, the time selector element is not displayed.
  final TimeRange? initialSelectorRange;

  /// Time position for focusing when initializing the widget.
  /// If specified, the time scale automatically scrolls to the given time.
  /// If null, no focus is applied.
  /// Takes precedence over [initialSelectorRange].
  final TimeOfDay? focusTimePosition;

  /// Alignment of the focusable time position relative to the visible area.
  /// Defaults to [Alignment.center].
  final Alignment focusTimeAlignment;

  /// Callback that is called each time the selected time range changes.
  final OnChangeSelectorRange? onChange;

  /// Available time ranges for selection. If the list is empty, no restrictions are imposed.
  final Set<TimeRange> availableRanges;

  /// Offset between scale divisions.
  final double gap;

  /// Scale color.
  final Color timeScaleColor;

  /// Thickness of scale divisions and the bottom line.
  final double strokeWidth;

  /// Time text style.
  final TextStyle timeLabelStyle;

  /// Available time text style.
  final TextStyle enabledLabelStyle;

  /// Unavailable time text style.
  final TextStyle disabledLabelStyle;

  /// Style of unavailable time zone strokes.
  final HatchStyle hatchStyle;

  /// Range selector element style. See [SelectorDecoration] for details.
  final SelectorDecoration selectorDecoration;

  /// Minimum time segment for selection.
  final TimeOfDay minSelectorRange;

  /// Scroll animation style. Defaults to [kDefaultSelectorAnimationStyle].
  final AnimationStyle? scrollAnimationStyle;

  /// Range selector element animation style. Defaults to [kDefaultScrollAnimationStyle].
  final AnimationStyle? animationStyle;

  /// Padding between text and the bottom border of the time scale.
  final double space;

  void _debug() {
    assert(debugTimeOfDayCheck(minSelectorRange));

    assert(minSelectorRange.totalMinutes >= kMinutesShift, 'Invalid time 0 < TimeOfDay.totalMinutes >= 15');
    assert(gap >= kMinGap, 'Invalid gap value. kMinGap <= gap');
  }

  @override
  RenderObject createRenderObject(BuildContext context) {
    _debug();

    final materialLocalization = MaterialLocalizations.of(context);

    final scrollableState = Scrollable.of(context, axis: Axis.horizontal);

    return TimelineRenderObject(
      gap: gap,
      space: space,
      timeScaleColor: timeScaleColor,
      strokeWidth: strokeWidth,
      localization: materialLocalization,
      timeLabelStyle: timeLabelStyle,
      enabledLabelStyle: enabledLabelStyle,
      disabledLabelStyle: disabledLabelStyle,
      availableRanges: availableRanges,
      hatchStyle: hatchStyle,
      selectorDecoration: selectorDecoration,
      minSelectorRange: minSelectorRange,
      scrollable: scrollableState,
      initialSelectorValue: initialSelectorRange,
      onChangeSelectorRange: onChange,
      scrollAnimationStyle: scrollAnimationStyle ?? kDefaultScrollAnimationStyle,
      tickerNotifier: TickerMode.getNotifier(context),
      animationStyle: animationStyle ?? kDefaultSelectorAnimationStyle,
      focusPosition: _getFocusPosition(),
    );
  }

  @override
  void updateRenderObject(BuildContext context, TimelineRenderObject renderObject) {
    _debug();

    final materialLocalization = MaterialLocalizations.of(context);
    final scrollableState = Scrollable.of(context, axis: Axis.horizontal);

    renderObject
      ..gap = gap
      ..space = space
      ..timeScaleColor = timeScaleColor
      ..strokeWidth = strokeWidth
      ..localization = materialLocalization
      ..timeLabelStyle = timeLabelStyle
      ..enabledLabelStyle = enabledLabelStyle
      ..disabledLabelStyle = disabledLabelStyle
      ..availableRanges = availableRanges
      ..hatchStyle = hatchStyle
      ..selectorDecoration = selectorDecoration
      ..minSelectorRange = minSelectorRange
      .._scrollable = scrollableState
      ..initialSelectorRange = initialSelectorRange
      ..scrollAnimationStyle = scrollAnimationStyle ?? kDefaultScrollAnimationStyle
      ..animationStyle = animationStyle ?? kDefaultSelectorAnimationStyle
      ..tickerModeNotifier = TickerMode.getNotifier(context)
      ..onChangeSelectorRange = onChange
      ..focusPosition = _getFocusPosition();
  }

  FocusPosition? _getFocusPosition() {
    if (focusTimePosition != null) {
      return FocusPosition(time: focusTimePosition!, alignment: focusTimeAlignment);
    }
    return null;
  }
}

class TimelineRenderObject extends RenderBox with SingleTickerProviderRenderObject {
  TimelineRenderObject({
    required double gap,
    required double space,
    required Color timeScaleColor,
    required double strokeWidth,
    required MaterialLocalizations localization,
    required TextStyle timeLabelStyle,
    required TextStyle enabledLabelStyle,
    required TextStyle disabledLabelStyle,
    required Set<TimeRange> availableRanges,
    required HatchStyle hatchStyle,
    required TimeOfDay minSelectorRange,
    required TimeRange? initialSelectorValue,
    required FocusPosition? focusPosition,
    required AnimationStyle animationStyle,
    required AnimationStyle scrollAnimationStyle,
    required ValueListenable<bool> tickerNotifier,
    required OnChangeSelectorRange? onChangeSelectorRange,
    required SelectorDecoration selectorDecoration,
    required ScrollableState scrollable,
  })  : _scrollable = scrollable,
        _gap = gap,
        _space = space,
        _initialSelectorRange = initialSelectorValue,
        _timeScaleColor = timeScaleColor,
        _strokeWidth = strokeWidth,
        _localization = localization,
        _timeLabelStyle = timeLabelStyle,
        _enabledLabelStyle = enabledLabelStyle,
        _disabledLabelStyle = disabledLabelStyle,
        _availableRanges = availableRanges,
        _hatchStyle = hatchStyle,
        _selectorDecoration = selectorDecoration,
        _minSelectorRange = minSelectorRange,
        _scrollAnimationStyle = scrollAnimationStyle,
        _animationStyle = animationStyle,
        _onChangeSelectorRange = onChangeSelectorRange,
        _focusPosition = focusPosition {
    tickerModeNotifier = tickerNotifier;

    _initializeAnimation(animationStyle);

    assert(() {
      _scrollable.position.addListener(() {
        if (!debugPaintSizeEnabled) return;
        markNeedsPaint();
      });
      return true;
    }());
  }

  final _timelineLayerHandler = LayerHandle<PictureLayer>();

  final _labelsLayerHandler = LayerHandle<PictureLayer>();

  final _hatchLayerHandler = LayerHandle<PictureLayer>();

  // Paint optimization
  late final _textPainter = TextPainter(textDirection: TextDirection.ltr, maxLines: 1);

  /// Animation
  late AnimationController _animationController;
  late CurvedAnimation _parentAnimation;
  Animation<Rect?>? _animation;

  /// Scroll controller
  ScrollableState _scrollable;

  // Time range selection
  Rect _selectorRect = Rect.zero;

  /// Selector drag direction
  DragDirection? _dragDirection;

  /// Previous selector position to determine drag direction
  Offset _previousSelectorPosition = Offset.zero;

  // Available selection zone
  Set<Rect> _availableZones = const <Rect>{};

  // Scale size (without time labels)
  Size _timeScaleSize = Size.zero;

  // Gesture flags
  bool _isDraggingRightCorner = false;
  bool _isDraggingLeftCorner = false;
  bool _isDraggingSelector = false;
  bool _isTap = false;
  bool _isMove = false;

  // Initial position when selector is pressed
  Offset _startTapPosition = Offset.zero;
  // Initial selector position when dragging
  Offset _startSelectorPosition = Offset.zero;

  /// Time scale constraints
  BoxConstraints get timeScaleConstraints => BoxConstraints.loose(_timeScaleSize);

  /// Minimum time selector width
  double get minSelectorWidth => minuteToDx(_minSelectorRange.totalMinutes);

  /// Visible part. Changes depending on scroll position
  /// Has [kHorizontalFocusPadding] horizontal padding
  Rect get viewportRect {
    final position = _scrollable.position;

    return Offset(position.pixels, .0) & Size(position.viewportDimension, timeScaleConstraints.maxHeight);
  }

  /// Time selector enabled/disabled
  bool get isEnabledSelector => initialSelectorRange != null && _selectorRect.width != 0;

  BoxBorder get effectiveSelectorBorder {
    var borderPainter = selectorDecoration.border;

    if (!_availableZones.any(_collisionDetectorPredicate) && selectorDecoration.errorBorder != null) {
      borderPainter = selectorDecoration.errorBorder!;
    }
    return borderPainter;
  }

  Offset get _leftEdgeCenter {
    return _selectorRect.centerLeft - Offset((kDragArea / 2) - effectiveSelectorBorder.dimensions.horizontal / 2, .0);
  }

  Offset get _rightEdgeCenter {
    return _selectorRect.centerRight + Offset((kDragArea / 2) - effectiveSelectorBorder.dimensions.horizontal / 2, .0);
  }

  OnChangeSelectorRange? _onChangeSelectorRange;
  OnChangeSelectorRange? get onChangeSelectorRange => _onChangeSelectorRange;
  set onChangeSelectorRange(OnChangeSelectorRange? value) {
    if (value == _onChangeSelectorRange) return;

    _onChangeSelectorRange = value;
  }

  Set<TimeRange> _availableRanges;
  Set<TimeRange> get availableRanges => _availableRanges;
  set availableRanges(Set<TimeRange> value) {
    if (setEquals(value, _availableRanges)) return;

    _availableRanges = value;
    _availableZones = _rangesToGeometry(value, _timeScaleSize);
    _redrawAvailableRanges();
    markNeedsPaint();
  }

  AnimationStyle _scrollAnimationStyle;
  AnimationStyle get scrollAnimationStyle => _scrollAnimationStyle;
  set scrollAnimationStyle(AnimationStyle value) {
    if (value == _scrollAnimationStyle) return;

    _scrollAnimationStyle = value;
  }

  AnimationStyle _animationStyle;
  AnimationStyle get animationStyle => _animationStyle;
  set animationStyle(AnimationStyle value) {
    if (value == _animationStyle) return;

    _animationStyle = value;

    _disposeAnimations();
    _initializeAnimation(value);
  }

  //----------Selector properties------------

  TimeRange? _initialSelectorRange;
  TimeRange? get initialSelectorRange => _initialSelectorRange;
  set initialSelectorRange(TimeRange? value) {
    if (value == _initialSelectorRange) return;

    _initialSelectorRange = value;

    if (value != null) {
      final newRect = _selectorRectFromRange(_timeScaleSize, value);
      _animatedUpdateSelectorRect(newRect, () {
        focusOnSelector(newRect, true);
      });
      return;
    }

    markNeedsPaint();
  }

  TimeOfDay _minSelectorRange;
  TimeOfDay get minSelectorRange => _minSelectorRange;
  set minSelectorRange(TimeOfDay value) {
    if (value == _minSelectorRange || !isEnabledSelector) return;

    _minSelectorRange = value;
    _selectorRect = _selectorRectFromRange(_timeScaleSize, initialSelectorRange!);
    markNeedsPaint();
  }

  SelectorDecoration _selectorDecoration;
  SelectorDecoration get selectorDecoration => _selectorDecoration;
  set selectorDecoration(SelectorDecoration value) {
    if (value == _selectorDecoration) return;

    _selectorDecoration = value;
    markNeedsPaint();
  }

  FocusPosition? _focusPosition;
  FocusPosition? get focusPosition => _focusPosition;
  set focusPosition(FocusPosition? value) {
    if (value == _focusPosition) return;

    _focusPosition = value;

    if (value != null) {
      focus(value);
    }
  }

  //------------------------------------------

  //----------Timescale properties------------

  MaterialLocalizations _localization;
  MaterialLocalizations get localization => _localization;
  set localization(MaterialLocalizations value) {
    if (identical(value, _localization)) return;

    _localization = value;
    _redrawLabels();
    markNeedsPaint();
  }

  HatchStyle _hatchStyle;
  HatchStyle get hatchStyle => _hatchStyle;
  set hatchStyle(HatchStyle value) {
    if (value == _hatchStyle) return;

    _hatchStyle = value;
    _redrawHatch();
    markNeedsPaint();
  }

  TextStyle _timeLabelStyle;
  TextStyle get timeLabelStyle => _timeLabelStyle;
  set timeLabelStyle(TextStyle value) {
    if (value == _timeLabelStyle) return;

    _timeLabelStyle = value;
    _redrawLabels();
    markNeedsPaint();
  }

  TextStyle _enabledLabelStyle;
  TextStyle get enabledLabelStyle => _enabledLabelStyle;
  set enabledLabelStyle(TextStyle value) {
    if (value == _enabledLabelStyle) return;

    _enabledLabelStyle = value;
    _redrawLabels();
    markNeedsPaint();
  }

  TextStyle _disabledLabelStyle;
  TextStyle get disabledLabelStyle => _disabledLabelStyle;
  set disabledLabelStyle(TextStyle value) {
    if (value == _disabledLabelStyle) return;

    _disabledLabelStyle = value;
    _redrawLabels();
    markNeedsPaint();
  }

  Color _timeScaleColor;
  Color get timeScaleColor => _timeScaleColor;
  set timeScaleColor(Color value) {
    if (value == _timeScaleColor) return;

    _timeScaleColor = value;
    _redrawTimeScale();
    markNeedsPaint();
  }

  double _strokeWidth;
  double get strokeWidth => _strokeWidth;
  set strokeWidth(double value) {
    assert(
      value > 0 && !value.isInfinite,
      'Invalid strokeWidth property value. Must be 0 < strokeWidth < double.infinity',
    );
    if (value == _strokeWidth) return;

    _strokeWidth = value;
    _redrawTimeScale();
    markNeedsPaint();
  }

  double _gap;
  double get gap => _gap;
  set gap(double value) {
    assert(value > 0 && !value.isInfinite, 'Invalid gap property value. Must be 0 < gap < double.infinity');
    if (value == _gap) return;

    _gap = value;
    _redrawAvailableRanges();
    _redrawTimeScale();
    markParentNeedsLayout();
  }

  double _space;
  double get space => _space;
  set space(double value) {
    if (value == _space) return;

    _space = value;
    markNeedsLayout();
  }

  //-------------------------------

  @override
  bool get sizedByParent => true;

  @override
  bool get isRepaintBoundary => true;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    _redrawTimeScale();
    _redrawAvailableRanges();

    final size = constraints.constrain(Size.fromWidth(_gap * kSteps));

    _timeScaleSize = layoutTimeline(BoxConstraints.tight(size));

    _availableZones = _rangesToGeometry(availableRanges, _timeScaleSize);

    if (initialSelectorRange != null) {
      _selectorRect = _selectorRectFromRange(_timeScaleSize, initialSelectorRange!);

      /// Фокусирует на области выбора доступного времени
      /// Работает только при наличие предка типа *Viewport
      focusOnSelector(_selectorRect);
    }

    if (focusPosition case FocusPosition position) {
      //calculate offset
      focus(position);
    }

    return size;
  }

  Size layoutTimeline(BoxConstraints layoutSize) {
    // Calculate how much height the text will take
    final maxFontSize = math.max(
      timeLabelStyle.fontSize ?? 0,
      math.max(disabledLabelStyle.fontSize ?? 0, enabledLabelStyle.fontSize ?? 0),
    );
    final maxHeight = math.max(
      timeLabelStyle.height ?? 0,
      math.max(disabledLabelStyle.height ?? 0, enabledLabelStyle.height ?? 0),
    );
    _textPainter
      ..text = TextSpan(
        text: localization.formatTimeOfDay(TimeRange.day.begin),
        style: TextStyle(fontSize: maxFontSize, height: maxHeight),
      )
      ..layout(maxWidth: layoutSize.maxWidth);
    return Size(layoutSize.maxWidth, layoutSize.maxHeight - (_textPainter.height + space));
  }

  @override
  void debugPaint(PaintingContext context, Offset offset) {
    assert(() {
      if (debugPaintSizeEnabled) {
        final canvas = context.canvas;

        // Viewport visualization
        canvas
          ..drawRect(
            viewportRect,
            Paint()
              ..color = Colors.red.withAlpha(50)
              ..strokeWidth = 12
              ..style = PaintingStyle.fill,
          )
          ..drawLine(
            Offset(viewportRect.center.dx, .0),
            Offset(viewportRect.center.dx, timeScaleConstraints.maxHeight),
            Paint()
              ..color = Colors.red
              ..strokeWidth = 4
              ..style = PaintingStyle.fill,
          );

        final anchorPaint = Paint()
          ..color = Colors.teal.withAlpha(80)
          ..style = PaintingStyle.fill;

        // left drag anchor
        canvas.drawRect(_dragAnchor(_leftEdgeCenter), anchorPaint);

        // Right drag anchor
        canvas.drawRect(_dragAnchor(_rightEdgeCenter), anchorPaint);
      }
      return true;
    }());

    super.debugPaint(context, offset);
  }

  // --- Handle gesture --- //

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!isEnabledSelector) return true;

    final hasGesture = _isNearLeftEdge(position) || _isNearRightEdge(position);

    if (hasGesture) {
      result.add(BoxHitTestEntry(this, position));
      return false;
    }

    // Проверяем, находится ли позиция внутри селектора (но не на краях)
    final isOutsideCorner = !_isNearLeftEdge(position) && !_isNearRightEdge(position);
    if (_selectorRect.contains(position) && isOutsideCorner) {
      result.add(BoxHitTestEntry(this, position));
      return false;
    }

    return super.hitTest(result, position: position);
  }

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    final localPosition = event.localPosition;

    /// Fix interaction
    if (event is PointerDownEvent) {
      _isTap = false;
      _isMove = false;
      _startTapPosition = event.position;
      _startSelectorPosition = _selectorRect.topLeft;
      _previousSelectorPosition = _selectorRect.topLeft;

      _isDraggingLeftCorner = _isNearLeftEdge(localPosition);
      _isDraggingRightCorner = _isNearRightEdge(localPosition);
      _isDraggingSelector = _selectorRect.contains(localPosition) && !_isDraggingLeftCorner && !_isDraggingRightCorner;

      // Fix possible tap
      if (_isOutsideTap(event.localPosition) &&
          !(_isDraggingLeftCorner || _isDraggingRightCorner || _isDraggingSelector)) {
        _isTap = true;
      }
    }
    // Changing rectangle size
    else if (event is PointerMoveEvent && (_isDraggingLeftCorner || _isDraggingRightCorner)) {
      _isTap = false;
      _isMove = true;
      final localOffset = globalToLocal(event.position);

      _updateSelectorSizeByOffset(localOffset, event.delta);
    }
    // Moving the entire selector
    else if (event is PointerMoveEvent && _isDraggingSelector) {
      _isTap = false;
      _isMove = true;
      final delta = event.position - _startTapPosition;

      // Check if the offset has exceeded the threshold
      if (delta.distance > kScrollThreshold) {
        _updateSelectorPositionByDrag(delta);
      }
    } else if (event is PointerMoveEvent && !(_isDraggingLeftCorner || _isDraggingRightCorner || _isDraggingSelector)) {
      final delta = event.position - _startTapPosition;
      // Check if the offset has exceeded the threshold
      if (delta.distance > kScrollThreshold) {
        _isTap = false;
      }
    }
    // If tap, move the rectangle to the position
    else if (event is PointerUpEvent && _isTap) {
      _updateSelectorPosition(event.position);
    }

    if (event is PointerUpEvent && _isMove) {
      _animatedSnapToSegment(() {
        onChangeSelectorRange?.call(_geometryToRange(_selectorRect));
      });
    }
  }

  // ---------------------- //

  @override
  void paint(PaintingContext context, Offset offset) {
    // кэшируем слой шкалы
    drawOnPictureLayer(layer: _timelineLayerHandler, context: context, size: size, draw: _drawTimescale);

    // кэшируем слой текста
    drawOnPictureLayer(layer: _labelsLayerHandler, context: context, size: size, draw: _drawLabels);

    // кэшируем слой заштриховки
    drawOnPictureLayer(layer: _hatchLayerHandler, context: context, size: size, draw: _drawHatch);

    // рисуем селектор
    if (isEnabledSelector) {
      _drawSelector(context.canvas, offset);
    }
  }

  // --- Utils --- //

  void _initializeAnimation(AnimationStyle animationStyle) {
    _animationController = AnimationController(vsync: this, duration: animationStyle.duration);
    _parentAnimation = CurvedAnimation(parent: _animationController, curve: animationStyle.curve ?? Curves.easeInOut);
  }

  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  Rect _dragAnchor(Offset center) =>
      Rect.fromCenter(center: center, width: kDragArea, height: timeScaleConstraints.maxHeight);

  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  bool _isNearLeftEdge(Offset position) => _dragAnchor(_leftEdgeCenter).contains(position);

  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  bool _isNearRightEdge(Offset position) => _dragAnchor(_rightEdgeCenter).contains(position);

  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  bool _isOutsideTap(Offset position) =>
      Rect.fromLTWH(0, 0, size.width, _timeScaleSize.height).contains(position) && !_selectorRect.contains(position);

  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  double _snapToSegment(double value) {
    return (value / gap).round() * gap;
  }

  Rect _selectorRectFromRange(Size size, TimeRange range) {
    final start = minuteToDx(range.beginMinute);

    final end = minuteToDx(switch (range.endMinute) {
      0 => kMinutesPerDay,
      final endMinute => endMinute,
    });

    return Rect.fromLTWH(start, .0, end - start, size.height);
  }

  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  TimeRange _geometryToRange(Rect rect) {
    final begin = _dxToTime(rect.left);
    final end = _dxToTime(rect.right);
    final range = TimeRange(begin: begin, end: end);

    return range;
  }

  Set<Rect> _rangesToGeometry(Set<TimeRange> ranges, Size size) {
    final geometrySet = <Rect>{};
    for (var range in ranges) {
      final startPosition = minuteToDx(range.beginMinute);
      final endPosition = minuteToDx(switch (range.endMinute) {
        .0 => kMinutesPerDay,
        final minute => minute,
      });

      geometrySet.add(Rect.fromLTRB(startPosition, .0, endPosition, size.height));
    }

    return geometrySet;
  }

  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  TimeOfDay _dxToTime(double dx) {
    final shift = dx / gap;
    final totalMinutes = shift * kMinutesShift;

    return timeOfDayFromMinute(totalMinutes);
  }

  void focus(FocusPosition position, [bool animated = false]) {
    if (position.time.totalMinutes <= 0) return;

    SchedulerBinding.instance.addPostFrameCallback((_) {
      final alignment = position.alignment;
      final viewportDimension = _scrollable.position.viewportDimension;
      final timeDx = minuteToDx(position.time.totalMinutes);

      // Вычисляем смещение внутри viewport для выравнивания
      var desiredOffsetInViewport = alignment.alongSize(Size(viewportDimension, 0)).dx;

      desiredOffsetInViewport += kHorizontalFocusPadding * (alignment.x * -1);

      // Целевая позиция скролла
      var targetScrollOffset = timeDx - desiredOffsetInViewport;

      // Учитываем границы прокрутки
      targetScrollOffset = targetScrollOffset.clamp(0.0, _scrollable.position.maxScrollExtent);

      _scrollable.position.moveTo(
        targetScrollOffset,
        duration: animated ? scrollAnimationStyle.duration ?? Duration.zero : Duration.zero,
        curve: animated ? scrollAnimationStyle.curve ?? Curves.ease : Curves.ease,
      );
    });
  }

  void focusOnSelector(Rect selector, [bool animated = false]) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      const padding = EdgeInsets.symmetric(horizontal: kHorizontalFocusPadding);

      final rect = padding.inflateRect(selector);
      _scrollable.position.moveTo(
        rect.left,
        duration: animated ? scrollAnimationStyle.duration ?? Duration.zero : Duration.zero,
        curve: animated ? scrollAnimationStyle.curve ?? Curves.ease : Curves.ease,
      );
      // parent?.showOnScreen(
      //   descendant: this,
      //   rect: rect,
      // duration: animated ? scrollAnimationStyle.duration ?? Duration.zero : Duration.zero,
      // curve: animated ? scrollAnimationStyle.curve ?? Curves.ease : Curves.ease,
      // );
    });
  }

  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  double minuteToDx(num minute) => (minute * gap) / kMinutesShift;

  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  bool _collisionDetectorPredicate(Rect rect) {
    return _selectorRect.right <= rect.right && _selectorRect.left >= rect.left;
  }

  // ------------- //

  // --- Change selector  --- //

  void _changeSelector() {
    if (_animation == null) return;
    _selectorRect = _animation!.value!;
    markNeedsPaint();
  }

  void _updateSelectorRect(Rect value) {
    if (value == _selectorRect) return;

    _selectorRect = value;
    markNeedsPaint();
  }

  // Animates the rectangle change. The [onComplete] callback can be used
  // for actions after the animation.
  void _animatedUpdateSelectorRect(Rect value, [VoidCallback? onComplete]) {
    if (value == _selectorRect && _animation?.isAnimating == true) return;

    _animation?.removeListener(_changeSelector);
    _animation = null;

    _animation ??= RectTween(begin: _selectorRect, end: value).animate(_parentAnimation);

    _animation?.addListener(_changeSelector);
    _animationController.forward(from: .0).whenCompleteOrCancel(() {
      onComplete?.call();
      _animation = null;
      _animation?.removeListener(_changeSelector);
    });
  }

  // Animates snapping the rectangle position to the scale divisions. The [onComplete] callback
  // can be used for actions after the animation.
  void _animatedSnapToSegment(VoidCallback onCompleted) {
    _animation?.removeListener(_changeSelector);
    _animation = null;

    _animation ??= RectTween(
      begin: _selectorRect,
      end: Rect.fromLTRB(
        _snapToSegment(_selectorRect.left),
        _selectorRect.top,
        _snapToSegment(_selectorRect.right),
        _selectorRect.bottom,
      ),
    ).animate(_parentAnimation);

    _animation?.addListener(_changeSelector);
    _animationController.forward(from: .0).whenCompleteOrCancel(() {
      onCompleted();
      _animation = null;
      _animation?.removeListener(_changeSelector);
    });
  }

  void _updateSelectorPosition(Offset position) {
    final dx = _snapToSegment(globalToLocal(position).dx);

    var left = timeScaleConstraints.constrainWidth(dx);

    if (left + _selectorRect.width >= timeScaleConstraints.maxWidth) {
      left -= _selectorRect.width;
    }

    final newRect = Rect.fromLTWH(left, _selectorRect.top, minSelectorWidth, _selectorRect.height);
    _animatedUpdateSelectorRect(newRect, () {
      onChangeSelectorRange?.call(_geometryToRange(newRect));
    });
  }

  void _updateSelectorSizeByOffset(Offset offset, Offset delta) {
    final dx = offset.dx;

    final leftExtent = clampDouble(viewportRect.left, .0, timeScaleConstraints.maxWidth);
    final rightExtent = math.min(viewportRect.right, timeScaleConstraints.maxWidth);

    if (_isDraggingLeftCorner) {
      final width = (_selectorRect.left - dx) + _selectorRect.width;

      final newRect = Rect.fromLTWH(
        dx,
        _selectorRect.top,
        clampDouble(width, minSelectorWidth, timeScaleConstraints.maxWidth),
        _selectorRect.height,
      );

      if (newRect.left < 0 || newRect.right > size.width) return;

      // Scrolling
      if ((offset.dx - viewportRect.left).round() <= kAxisScrollThreshold &&
          leftExtent > timeScaleConstraints.minWidth) {
        parent?.showOnScreen(
          descendant: this,
          rect: Rect.fromLTWH(viewportRect.left - kDragArea, .0, 1, newRect.height),
          curve: scrollAnimationStyle.curve ?? Curves.ease,
          duration: scrollAnimationStyle.duration ?? Durations.short2,
        );
      } else if ((viewportRect.right - newRect.right) < kAxisScrollThreshold && newRect.width == minSelectorWidth) {
        parent?.showOnScreen(
          descendant: this,
          rect: Rect.fromLTWH(rightExtent + kDragArea, .0, 1, newRect.height),
          curve: scrollAnimationStyle.curve ?? Curves.ease,
          duration: scrollAnimationStyle.duration ?? Durations.short2,
        );
      }

      _updateSelectorRect(newRect);
    } else if (_isDraggingRightCorner) {
      var left = _selectorRect.left;
      var width = _selectorRect.width;

      width = clampDouble(width + (dx - _selectorRect.right), minSelectorWidth, timeScaleConstraints.maxWidth);
      if (width == minSelectorWidth) {
        left -= _selectorRect.right - dx;
      }

      final newRect = Rect.fromLTWH(
        timeScaleConstraints.constrainWidth(left),
        _selectorRect.top,
        width,
        _selectorRect.height,
      );

      if (newRect.right > size.width) return;

      if ((viewportRect.right - offset.dx).round() <= kAxisScrollThreshold &&
          rightExtent < timeScaleConstraints.maxWidth) {
        parent?.showOnScreen(
          descendant: this,
          rect: Rect.fromLTWH(viewportRect.right + kDragArea, .0, 1, newRect.height),
          duration: scrollAnimationStyle.duration ?? Durations.short2,
        );
      } else if (!viewportRect.contains(newRect.topLeft - Offset(kAxisScrollThreshold, .0)) &&
          newRect.width == minSelectorWidth) {
        parent?.showOnScreen(
          descendant: this,
          rect: Rect.fromLTWH(leftExtent - kDragArea, .0, 1, newRect.height),
          duration: scrollAnimationStyle.duration ?? Durations.short2,
        );
      }

      _updateSelectorRect(newRect);
    }
  }

  /// Updates the selector position when dragging
  void _updateSelectorPositionByDrag(Offset delta) {
    // Calculate the new selector position taking into account the offset
    final newLeft = _startSelectorPosition.dx + delta.dx;
    final newRight = newLeft + _selectorRect.width;

    // Check boundaries and adjust position if necessary
    double correctedLeft = newLeft;
    if (newLeft < 0) {
      correctedLeft = 0;
    } else if (newRight > size.width) {
      correctedLeft = size.width - _selectorRect.width;
    }

    // Create a new rectangle with the updated position
    final newRect = Rect.fromLTWH(correctedLeft, _selectorRect.top, _selectorRect.width, _selectorRect.height);

    // Determine the drag direction
    _dragDirection = DragDirection.fromPoints(newRect.left, _previousSelectorPosition.dx);
    // Update the previous position
    _previousSelectorPosition = newRect.topLeft;

    // Check if we need to scroll the viewport
    // Scroll left if the selector's left edge approaches the viewport's left boundary
    if ((newRect.left - viewportRect.left) <= 20.0 && _dragDirection == DragDirection.left) {
      _scrollable.position.moveTo(newRect.left);
    }
    // Scroll right if the selector's right edge approaches the viewport's right boundary
    if ((viewportRect.right - newRect.right) <= 20.0 && _dragDirection == DragDirection.right) {
      final moveOffsetDx = newRect.right - viewportRect.right;
      _scrollable.position.moveTo(viewportRect.left + moveOffsetDx);
    }

    // Update the selector position
    _updateSelectorRect(newRect);
  }

  // ------------------------ //

  // --- Paint --- //

  void _drawSelector(Canvas canvas, Offset offset) {
    selectorDecoration.paint(canvas, _selectorRect, effectiveSelectorBorder);
  }

  void _drawTimescale(Canvas canvas) {
    final height = _timeScaleSize.height;

    final timeScalePaint = Paint()
      ..color = timeScaleColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.fill;
    canvas.drawLine(Offset(0, height), Offset(size.width, height), timeScalePaint);
    for (int step = 0; step < kSteps; step++) {
      final normalizedStep = step + 1;
      final shift = gap * normalizedStep;

      final minuteShift = (normalizedStep * kMinutesShift);
      final remainder = minuteShift.remainder(TimeOfDay.minutesPerHour);

      final topShift = switch (remainder) {
        15 || 45 => height * 0.5,
        30 => height * 0.2,
        _ => .0,
      };
      canvas.drawLine(Offset(shift, height), Offset(shift, topShift), timeScalePaint);
    }
  }

  void _drawLabels(Canvas canvas) {
    for (int step = 0; step < kSteps; step++) {
      final normalizedStep = step + 1;
      final shift = gap * normalizedStep;

      final minuteShift = (normalizedStep * kMinutesShift);
      final remainder = minuteShift.remainder(TimeOfDay.minutesPerHour);

      bool isHour(int remainder) => remainder == 0;

      if (isHour(remainder) && normalizedStep < kSteps) {
        _drawTimeLabel(canvas: canvas, offset: Offset(shift, _timeScaleSize.height), minuteShift: minuteShift);
      }
    }
  }

  void _drawHatch(Canvas canvas) {
    final height = _timeScaleSize.height;

    final backgroundPaint = Paint()
      ..color = hatchStyle.backgroundColor
      ..style = PaintingStyle.fill;

    const hatchAngle = 45 * math.pi / -180;
    final hatchPaint = Paint()
      ..color = hatchStyle.strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = hatchStyle.strokeWidth;

    final path = Path();
    final cosAngle = math.cos(hatchAngle);
    final sinAngle = math.sin(hatchAngle);

    final fullWidth = _timeScaleSize.width + height;
    for (double i = -height; i < fullWidth; i += hatchStyle.space) {
      final x = i;
      final y = 0.0;
      final dx = x + height * sinAngle / cosAngle;
      final dy = height;

      path.moveTo(x, y);
      path.lineTo(dx, dy);
    }

    final availableRangesPath = Path();
    for (final rect in _availableZones) {
      availableRangesPath.addRect(rect);
    }

    final clip = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & _timeScaleSize),
      availableRangesPath,
    );

    canvas
      ..save()
      ..clipPath(clip);
    canvas
      ..drawRect(Offset.zero & _timeScaleSize, backgroundPaint)
      ..drawPath(path, hatchPaint);
    canvas.restore();
  }

  void _drawTimeLabel({required Canvas canvas, required Offset offset, required int minuteShift}) {
    final time = timeOfDayFromMinute(minuteShift);

    var style = enabledLabelStyle;
    if (!availableRanges.any((range) => range.overlaps(time))) {
      style = disabledLabelStyle;
    }

    _textPainter
      ..text = TextSpan(text: localization.formatTimeOfDay(time), style: timeLabelStyle.merge(style))
      ..plainText
      ..layout();

    final dxCenter = offset.dx - (_textPainter.width / 2);
    final dyCenter = offset.dy + space;

    _textPainter.paint(canvas, Offset(dxCenter, dyCenter));
  }

  void _redrawTimeScale() {
    _timelineLayerHandler.layer = null;
  }

  void _redrawHatch() {
    _hatchLayerHandler.layer = null;
  }

  void _redrawLabels() {
    _labelsLayerHandler.layer = null;
  }

  void _redrawAvailableRanges() {
    _redrawHatch();
    _redrawLabels();
  }

  // ------------- //

  void _disposeAnimations() {
    _parentAnimation.dispose();
    _animationController.dispose();
  }

  @override
  void dispose() {
    _disposeAnimations();

    _labelsLayerHandler.layer = null;
    _hatchLayerHandler.layer = null;
    _timelineLayerHandler.layer = null;
    _textPainter.dispose();
    super.dispose();
  }
}
