import 'dart:ui';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:timeline_widget/animated_render_object.dart';
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:timeline_widget/selector_decoration.dart';

export 'package:timeline_widget/selector_decoration.dart';

/// Количество минут в сутках.
const kMinutesPerDay = TimeOfDay.hoursPerDay * TimeOfDay.minutesPerHour;

/// Постоянное смещение в минутах.
const kMinutesShift = 15;

/// Количество делений на шкале времени.
const kSteps = kMinutesPerDay / kMinutesShift;

/// Отступ между текстом и нижней границей шкалы времени.
const kTopPaddingOfTimeLabel = 6;

/// Процент высоты занимаемой области шкалы.
const kSelectorAreaHeightPercentage = 0.6;

/// Ширина области в пределах которой работаю жесты захвата за левый и правый край области выделения.
const kDragArea = 48.0;

/// Минимально допустимое значения отступа между делениями.
const kMinGap = 24;

/// Горизонтальный отступ при фокусировки на доступной области.
const kHorizontalFocusPadding = 16.0;

/// Коэффициент чувствительности при которой будет обнаружен жест прокрутки.
const kScrollThreshold = 5.0;

/// Чувствительность горизонтальной прокрутки.
const kAxisScrollThreshold = 100.0;

/// Стиль анимации для шкалы выбора времени по умолчанию.
final kDefaultSelectorAnimationStyle = AnimationStyle(curve: Curves.easeInOut, duration: Durations.short3);

/// Стиль анимации прокрутки по умолчанию .
final kDefaultScrollAnimationStyle = AnimationStyle(curve: Curves.linear, duration: Durations.short2);

/// Тип унарного обратного вызова, который принимает аргумент типа [TimeRange].
typedef OnChangeSelectorRange = void Function(TimeRange value);

/// Проверка [TimeOfDay] в debug.
bool debugTimeOfDayCheck(TimeOfDay value) {
  assert(() {
    if (value.hour > TimeOfDay.hoursPerDay || value.hour < 0) {
      throw FlutterError(
        'Некорректное значение времени. Время должно быть 0 >= TimeOfDay.hour <= TimeOfDay.hoursPerDay',
      );
    }

    if (value.minute > TimeOfDay.minutesPerHour || value.minute < 0) {
      throw FlutterError(
        'Некорректное значение времени. Время должно быть 0 >= TimeOfDay.minute <= TimeOfDay.minutesPerHour',
      );
    }
    return true;
  }());
  return true;
}

/// Проверка [TimeRange] в debug.
bool debugTimeWindow(TimeRange value) {
  assert(value.begin.isBefore(value.end), 'Нижняя граница времени должна быть меньше верхней.');
  debugTimeOfDayCheck(value.begin);
  debugTimeOfDayCheck(value.end);
  return true;
}

/// Диапазон времени.
@immutable
class TimeRange {
  const TimeRange({
    this.begin = const TimeOfDay(hour: 0, minute: 0),
    this.end = const TimeOfDay(hour: TimeOfDay.hoursPerDay, minute: 0),
  });

  /// Начало диапазона.
  final TimeOfDay begin;

  /// Конец диапазона.
  final TimeOfDay end;

  /// Константное значение равное суткам.
  static const day = TimeRange();

  /// Константное значение выражающие пустой диапазон.
  static const empty = TimeRange(begin: TimeOfDay(hour: 0, minute: 0), end: TimeOfDay(hour: 0, minute: 0));

  /// Начало диапазона в минутах.
  int get beginMinute => begin.totalMinutes;

  /// Конец диапазона в минутах.
  int get endMinute => end.totalMinutes;

  /// Значение диапазона времени в минутах.
  int get minutes => endMinute - beginMinute;

  /// Значение диапазона времени в [TimeOfDay].
  TimeOfDay get time {
    int hours = (this.minutes ~/ TimeOfDay.minutesPerHour).remainder(TimeOfDay.hoursPerDay);
    int minutes = this.minutes.remainder(TimeOfDay.minutesPerHour);

    return TimeOfDay(hour: hours, minute: minutes);
  }

  TimeRange copyWith({TimeOfDay? begin, TimeOfDay? end}) => TimeRange(begin: begin ?? this.begin, end: end ?? this.end);

  @override
  int get hashCode => Object.hash(runtimeType, begin, end);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeRange && runtimeType == other.runtimeType && begin == other.begin && end == other.end;
}

/// Стиль штриховки для отображения неактивно области.
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
        space: space ?? this.space,
        strokeColor: strokeColor ?? this.strokeColor,
        strokeWidth: strokeWidth ?? this.strokeWidth,
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

/// Виджет который рисует шкалу времени равную 24 часам с возможностью выбрать
/// определённый диапазон времени. При каждом изменение диапазона вызывается
/// обратный вызов [onChange] с типом [TimeRange].
///
/// Для указания начальной позиции элемента выбора диапазона используйте свойство [initialSelectorRange].
/// Чтобы задать минимально допустимое значение выбора диапазона используйте свойство [minSelectorRange].
/// Для кастомизации используйте свойства [selectorDecoration].
///
/// Для настройки шага шкалы времени используйте [gap] он не должен быть меньше [kMinGap].
/// Для установки доступного для выбора диапазона используйте свойство [availableWindow].
/// Для кастомизации используйте следующие свойства:
/// * [timeScaleColor] - цвет контура.
/// * [strokeWidth] - толщина контура.
/// * [timeLabelStyle] - стиль подписи.
/// * [enabledLabelStyle] - стиль подписи для времени, которое доступно для выбора.
/// * [disabledLabelStyle] - стиль времени для времени, которое не доступно для выбора.
/// * [hatchStyle] - стиль штриховки
///
/// Виджет ищет [Scrollable] выше по дереву для взаимодействия с прокруткой. Установите родителем для этого виджета
/// [SingleChildScrollView] или любой другой виджет, но не [CustomScrollView]. Так же обратите внимание, что виджет
/// поддерживает только [Axis.horizontal]. Также для обеспечения корректной работы жестов используйте свойство
/// [HitTestBehavior.deferToChild] для свойств hitTestBehavior в родительском виджете.
///
/// Виджет не имеет минимальной высоты по этому он использует высоту родителя. Будьте внимательны и
/// всегда устанавливайте максимальную высоту, например оберните его в [ConstrainedBox] перед те как
/// помещать его дочерним для [SingleChildScrollView].
///
/// Пример использования виджета
///
/// ```dart
/// import 'package:flutter/gestures.dart';
/// import 'package:flutter/material.dart';
/// import 'package:flutter_localizations/flutter_localizations.dart';
/// import 'package:timeline_widget/timeline.dart';
///
/// void main() {
///   runApp(const MainApp());
/// }
///
/// class MainApp extends StatelessWidget {
///   const MainApp({super.key});
///   @override
///   Widget build(BuildContext context) {
///     return MaterialApp(
///       locale: Locale('ru', 'RU'),
///       supportedLocales: [Locale('ru', 'RU')],
///       localizationsDelegates: GlobalMaterialLocalizations.delegates,
///       home: SizedBox(
///               height: 95,
///               child: SingleChildScrollView(
///                 scrollDirection: Axis.horizontal,
///                 hitTestBehavior: HitTestBehavior.deferToChild,
///                 child: Timeline(
///                   initialSelectorRange: TimeWindow(begin: TimeOfDay(hour: 9, minute: 0), end: TimeOfDay(hour: 10, minute: 0)),
///                   availableWindow: TimeWindow(begin: TimeOfDay(hour: 9, minute: 0), end: TimeOfDay(hour: 18, minute: 0)),
///                 ),
///             ),
///         ),
///     );
///   }
/// }
/// ```
class Timeline extends LeafRenderObjectWidget {
  const Timeline({
    super.key,
    this.initialSelectorRange,
    this.onChange,
    this.availableWindow = TimeRange.day,
    this.timeScaleColor = const Color(0xFFC2C5CC),
    this.strokeWidth = 1,
    this.gap = 18,
    this.timeLabelStyle = const TextStyle(color: Color(0xFF1A1A1A), fontSize: 8),
    this.enabledLabelStyle = const TextStyle(color: Color(0xFF1A1A1A)),
    this.disabledLabelStyle = const TextStyle(color: Color(0xFFACADB3)),
    this.hatchStyle = const HatchStyle(),
    this.selectorDecoration = const SelectorDecoration(
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
    ),
    this.minSelectorRange = const TimeOfDay(hour: 0, minute: 30),
    this.scrollAnimationStyle,
    this.animationStyle,
  });

  /// Начальное значение диапазона времени. Если равно null элемент выбора времени не отображается.
  final TimeRange? initialSelectorRange;

  /// Обратный вызов который вызывается каждый раз, когда изменяется выбранный диапазон времени.
  final OnChangeSelectorRange? onChange;

  /// Доступное для выбора окно времени.
  final TimeRange availableWindow;

  /// Смещение между делениями шкалы.
  final double gap;

  /// Цвет шкалы.
  final Color timeScaleColor;

  /// Толщина делений шкалы и нижней лини.
  final double strokeWidth;

  /// Стиль текста времени.
  final TextStyle timeLabelStyle;

  /// Стиль текста доступного времени.
  final TextStyle enabledLabelStyle;

  /// Стиль текста недоступного времени.
  final TextStyle disabledLabelStyle;

  /// Стиль штриха зон недоступного времени.
  final HatchStyle hatchStyle;

  /// Стиль элемента выбора диапазона. Подробнее [SelectorDecoration].
  final SelectorDecoration selectorDecoration;

  /// Минимальный отрезок времени для выбора.
  final TimeOfDay minSelectorRange;

  /// Стиль анимации прокрутки. По умолчанию [kDefaultSelectorAnimationStyle].
  final AnimationStyle? scrollAnimationStyle;

  /// Стиль анимации элемента выбора диапазона. По умолчанию [kDefaultScrollAnimationStyle].
  final AnimationStyle? animationStyle;

  void _debug() {
    if (availableWindow != TimeRange.empty) {
      assert(debugTimeWindow(availableWindow));
    }

    assert(debugTimeOfDayCheck(minSelectorRange));

    if (initialSelectorRange != null) {
      assert(debugTimeWindow(initialSelectorRange!));
      assert(initialSelectorRange!.minutes >= minSelectorRange.totalMinutes);
    }

    assert(minSelectorRange.totalMinutes >= kMinutesShift, 'Некорректное время  0 < TimeOfDay.totalMinutes >= 15');
    assert(gap >= kMinGap, 'Некорректное значение gap. kMinGap <= gap');
  }

  @override
  RenderObject createRenderObject(BuildContext context) {
    _debug();

    final materialLocalization = MaterialLocalizations.of(context);
    final textDirection = Directionality.of(context);

    final scrollableState = Scrollable.of(context, axis: Axis.horizontal);

    return _TimelineRenderObject(
      gap: gap,
      timeScaleColor: timeScaleColor,
      strokeWidth: strokeWidth,
      localization: materialLocalization,
      timeLabelStyle: timeLabelStyle,
      textDirection: textDirection,
      enabledLabelStyle: enabledLabelStyle,
      disabledLabelStyle: disabledLabelStyle,
      timeWindow: availableWindow,
      hatchStyle: hatchStyle,
      selectorDecoration: selectorDecoration,
      minSelectorRange: minSelectorRange,
      scrollable: scrollableState,
      initialSelectorValue: initialSelectorRange,
      onChangeSelectorRange: onChange,
      scrollAnimationStyle: scrollAnimationStyle ?? kDefaultScrollAnimationStyle,
      tickerNotifier: TickerMode.getNotifier(context),
      animationStyle: animationStyle ?? kDefaultSelectorAnimationStyle,
    );
  }

  @override
  // ignore: library_private_types_in_public_api
  void updateRenderObject(BuildContext context, _TimelineRenderObject renderObject) {
    _debug();

    final materialLocalization = MaterialLocalizations.of(context);
    final textDirection = Directionality.of(context);
    final scrollableState = Scrollable.of(context, axis: Axis.horizontal);

    renderObject
      ..gap = gap
      ..timeScaleColor = timeScaleColor
      ..strokeWidth = strokeWidth
      ..localization = materialLocalization
      ..timeLabelStyle = timeLabelStyle
      ..textDirection = textDirection
      ..enabledLabelStyle = enabledLabelStyle
      ..disabledLabelStyle = disabledLabelStyle
      ..timeWindow = availableWindow
      ..hatchStyle = hatchStyle
      ..selectorDecoration = selectorDecoration
      ..minSelectorRange = minSelectorRange
      .._scrollable = scrollableState
      ..initialSelectorRange = initialSelectorRange
      ..scrollAnimationStyle = scrollAnimationStyle ?? kDefaultScrollAnimationStyle
      ..animationStyle = animationStyle ?? kDefaultSelectorAnimationStyle
      ..tickerModeNotifier = TickerMode.getNotifier(context)
      ..onChangeSelectorRange = onChange;
  }
}

class _TimelineRenderObject extends RenderBox with SingleTickerProviderRenderObject {
  _TimelineRenderObject({
    required double gap,
    required Color timeScaleColor,
    required double strokeWidth,
    required MaterialLocalizations localization,
    required TextStyle timeLabelStyle,
    required TextStyle enabledLabelStyle,
    required TextStyle disabledLabelStyle,
    required TextDirection textDirection,
    required TimeRange timeWindow,
    required HatchStyle hatchStyle,
    required TimeOfDay minSelectorRange,
    required TimeRange? initialSelectorValue,
    required AnimationStyle animationStyle,
    required AnimationStyle scrollAnimationStyle,
    required ValueListenable<bool> tickerNotifier,
    required OnChangeSelectorRange? onChangeSelectorRange,
    required SelectorDecoration selectorDecoration,
    required ScrollableState scrollable,
  })  : _scrollable = scrollable,
        _gap = gap,
        _initialSelectorRange = initialSelectorValue,
        _timeScaleColor = timeScaleColor,
        _strokeWidth = strokeWidth,
        _localization = localization,
        _timeLabelStyle = timeLabelStyle,
        _textDirection = textDirection,
        _enabledLabelStyle = enabledLabelStyle,
        _disabledLabelStyle = disabledLabelStyle,
        _timeWindow = timeWindow,
        _hatchStyle = hatchStyle,
        _selectorDecoration = selectorDecoration,
        _minSelectorRange = minSelectorRange,
        _scrollAnimationStyle = scrollAnimationStyle,
        _animationStyle = animationStyle,
        _onChangeSelectorRange = onChangeSelectorRange {
    tickerModeNotifier = tickerNotifier;

    _animationController = AnimationController(vsync: this, duration: animationStyle.duration);
    _parentAnimation = CurvedAnimation(parent: _animationController, curve: animationStyle.curve ?? Curves.easeInOut);
  }

  // Paint optimization
  final _textPainterCache = <int, TextPainter>{};
  final _timelineLayerHandler = LayerHandle<PictureLayer>();

  /// Animation
  late AnimationController _animationController;
  late CurvedAnimation _parentAnimation;
  Animation<Rect?>? _animation;

  /// Scroll controller
  ScrollableState _scrollable;

  // Выделения диапазона времени
  Rect _selectorRect = Rect.zero;

  // Доступная для выбора зона
  Rect _availableZoneRect = Rect.zero;

  // Нужен для обнаружения скролла
  Offset _startTapPosition = Offset.zero;

  // Флаги жестов
  bool _isDraggingRightCorner = false;
  bool _isDraggingLeftCorner = false;
  bool _isTap = false;
  bool _isMove = false;

  /// Размер шкалы без временных меток
  Size get timeScaleSize => Size(size.width, size.height * kSelectorAreaHeightPercentage);

  /// Ограничения временной шкалы
  BoxConstraints get selfConstraints => BoxConstraints.loose(timeScaleSize);

  /// Минимальная ширина выделителя времени
  double get minSelectorWidth => minuteToOffset(_minSelectorRange.totalMinutes / kMinutesShift);

  /// Видимая часть. Меняется в зависимости от скролла
  /// Имеет отступы [kHorizontalFocusPadding] по горизонтали
  Rect get viewportRect {
    final position = _scrollable.position;
    return Offset(position.pixels, .0) & Size(position.viewportDimension, _availableZoneRect.height);
  }

  /// Включен/Выключен выделитель времени
  bool get isEnabledSelector => initialSelectorRange != null && _selectorRect.width != 0;

  BoxBorder get selectorBorder {
    var borderPainter = selectorDecoration.border;

    if (!(_selectorRect.right <= _availableZoneRect.right && _selectorRect.left >= _availableZoneRect.left) &&
        selectorDecoration.errorBorder != null) {
      borderPainter = selectorDecoration.errorBorder!;
    }
    return borderPainter;
  }

  Offset get _leftEdgeCenter =>
      _selectorRect.centerLeft - Offset((kDragArea / 2) - selectorBorder.dimensions.horizontal / 2, .0);

  Offset get _rightEdgeCenter =>
      _selectorRect.centerRight + Offset((kDragArea / 2) - selectorBorder.dimensions.horizontal / 2, .0);

  OnChangeSelectorRange? _onChangeSelectorRange;
  OnChangeSelectorRange? get onChangeSelectorRange => _onChangeSelectorRange;
  set onChangeSelectorRange(OnChangeSelectorRange? value) {
    if (value == _onChangeSelectorRange) return;

    _onChangeSelectorRange = value;
  }

  TimeRange _timeWindow;
  TimeRange get timeWindow => _timeWindow;
  set timeWindow(TimeRange value) {
    if (value == _timeWindow) return;

    _timeWindow = value;
    _textPainterCache.clear();
    _availableZoneRect = _getAvailableZoneRect(timeScaleSize);
    _redrawTimeScale();
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
  }

  //----------Selector properties------------

  TimeRange? _initialSelectorRange;
  TimeRange? get initialSelectorRange => _initialSelectorRange;
  set initialSelectorRange(TimeRange? value) {
    if (value == _initialSelectorRange) return;

    _initialSelectorRange = value;

    if (value != null) {
      final newRect = _getDefaultSelectorRect(timeScaleSize, value);
      _animatedUpdateSelectorRect(newRect, () {
        _focusOnSelector(newRect, true);
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
    _selectorRect = _getDefaultSelectorRect(timeScaleSize, initialSelectorRange!);
    markNeedsPaint();
  }

  SelectorDecoration _selectorDecoration;
  SelectorDecoration get selectorDecoration => _selectorDecoration;
  set selectorDecoration(SelectorDecoration value) {
    if (value == _selectorDecoration) return;

    _selectorDecoration = value;
    markNeedsPaint();
  }

  //------------------------------------------

  //----------Timescale properties------------

  MaterialLocalizations _localization;
  MaterialLocalizations get localization => _localization;
  set localization(MaterialLocalizations value) {
    if (identical(value, _localization)) return;

    _localization = value;
    _redrawTimeScale();
    markNeedsPaint();
  }

  HatchStyle _hatchStyle;
  HatchStyle get hatchStyle => _hatchStyle;
  set hatchStyle(HatchStyle value) {
    if (value == _hatchStyle) return;

    _hatchStyle = value;
    _redrawTimeScale();
    markNeedsPaint();
  }

  TextDirection _textDirection;
  TextDirection get textDirection => _textDirection;
  set textDirection(TextDirection value) {
    if (_textDirection == value) return;

    _textPainterCache.clear();
    _textDirection = value;
    _redrawTimeScale();
    markNeedsPaint();
  }

  TextStyle _timeLabelStyle;
  TextStyle get timeLabelStyle => _timeLabelStyle;
  set timeLabelStyle(TextStyle value) {
    if (value == _timeLabelStyle) return;

    _textPainterCache.clear();
    _timeLabelStyle = value;
    _redrawTimeScale();
    markNeedsPaint();
  }

  TextStyle _enabledLabelStyle;
  TextStyle get enabledLabelStyle => _enabledLabelStyle;
  set enabledLabelStyle(TextStyle value) {
    if (value == _enabledLabelStyle) return;

    _textPainterCache.clear();
    _enabledLabelStyle = value;
    _redrawTimeScale();
    markNeedsPaint();
  }

  TextStyle _disabledLabelStyle;
  TextStyle get disabledLabelStyle => _disabledLabelStyle;
  set disabledLabelStyle(TextStyle value) {
    if (value == _disabledLabelStyle) return;

    _textPainterCache.clear();
    _disabledLabelStyle = value;
    _redrawTimeScale();
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
      'Некорректное значение свойства strokeWidth. Должно быть 0 < strokeWidth < double.infinity',
    );
    if (value == _strokeWidth) return;

    _strokeWidth = value;
    _redrawTimeScale();
    markNeedsPaint();
  }

  double _gap;
  double get gap => _gap;
  set gap(double value) {
    assert(value > 0 && !value.isInfinite, 'Некорректное значение свойства gap. Должно быть 0 < gap < double.infinity');
    if (value == _gap) return;

    _gap = value;
    _redrawTimeScale();
    markNeedsLayoutForSizedByParentChange();
  }

  @override
  void debugPaint(PaintingContext context, Offset offset) {
    if (debugPaintSizeEnabled) {
      final canvas = context.canvas;

      final scrollOffset = Offset(_scrollable.position.pixels + 2, _availableZoneRect.height / 2);

      /// Draw scroll offset
      canvas.drawPoints(
        PointMode.points,
        [scrollOffset],
        Paint()
          ..color = Colors.red
          ..strokeWidth = 12
          ..style = PaintingStyle.fill,
      );

      canvas.drawRect(
        viewportRect,
        Paint()
          ..color = Colors.red.withAlpha(50)
          ..strokeWidth = 12
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

    super.debugPaint(context, offset);
  }

  //-------------------------------

  @override
  bool get sizedByParent => true;

  @override
  bool get isRepaintBoundary => true;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final size = constraints.constrain(Size.fromWidth(_gap * kSteps));

    final scaleSize = Size(size.width, size.height * kSelectorAreaHeightPercentage);
    _availableZoneRect = _getAvailableZoneRect(scaleSize);

    if (initialSelectorRange != null) {
      _selectorRect = _getDefaultSelectorRect(scaleSize, initialSelectorRange!);

      /// Фокусирует на области выбора доступного времени
      /// Работает только при наличие предка типа *Viewport
      _focusOnSelector(_selectorRect);
    }

    return size;
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

    return super.hitTest(result, position: position);
  }

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    final localPosition = event.localPosition;

    /// Фиксируем взаимодеиствие
    if (event is PointerDownEvent) {
      _isTap = false;
      _isMove = false;
      _startTapPosition = event.position;

      _isDraggingLeftCorner = _isNearLeftEdge(localPosition);
      _isDraggingRightCorner = _isNearRightEdge(localPosition);

      // Фиксируем возможный тап
      if (_isOutsideTap(event.localPosition) && !(_isDraggingLeftCorner || _isDraggingRightCorner)) {
        _isTap = true;
      }
    }
    // Изменение размера прямоугольника
    if (event is PointerMoveEvent && (_isDraggingLeftCorner || _isDraggingRightCorner)) {
      _isTap = false;
      _isMove = true;
      final localOffset = globalToLocal(event.position);

      _updateSelectorSizeByOffset(localOffset, event.delta);
    } else if (event is PointerMoveEvent && !(_isDraggingLeftCorner || _isDraggingRightCorner)) {
      final delta = event.position - _startTapPosition;
      // Проверяем, превысило ли смещение порог
      if (delta.distance > kScrollThreshold) {
        _isTap = false;
      }
    }
    // Если тап то перемещаем прямоугольник на позицию
    else if (event is PointerUpEvent && _isTap) {
      _updateSelectorPosition(event.position);
    }

    if (event is PointerUpEvent && _isMove) {
      _animatedSnapToSegment(() {
        onChangeSelectorRange?.call(_geometryToData(_selectorRect));
      });
    }
  }

  // ---------------------- //

  @override
  void paint(PaintingContext context, Offset offset) {
    // кэшируем слой шкалы для дальнейшего переиспользовать
    if (_timelineLayerHandler.layer == null) {
      final pictureRecorder = PictureRecorder();
      final canvas = Canvas(pictureRecorder);

      _drawTimescale(canvas);

      final picture = pictureRecorder.endRecording();

      _timelineLayerHandler.layer = PictureLayer(Rect.fromLTWH(0, 0, size.width, size.height))..picture = picture;
    }

    if (_timelineLayerHandler.layer != null) {
      context.addLayer(_timelineLayerHandler.layer!);
    }

    if (isEnabledSelector) {
      _drawSelector(context, offset);
    }
  }

  // --- Utils --- //

  Rect _dragAnchor(Offset center) => Rect.fromCenter(
        center: center,
        width: kDragArea,
        height: selfConstraints.maxHeight,
      );

  bool _isNearLeftEdge(Offset position) => _dragAnchor(_leftEdgeCenter).contains(position);

  bool _isNearRightEdge(Offset position) => _dragAnchor(_rightEdgeCenter).contains(position);

  bool _isOutsideTap(Offset position) =>
      Rect.fromLTWH(0, 0, size.width, timeScaleSize.height).contains(position) && !_selectorRect.contains(position);

  double _snapToSegment(double value) {
    return (value / gap).round() * gap;
  }

  Rect _getDefaultSelectorRect(Size size, TimeRange range) {
    final start = minuteToOffset(range.beginMinute) / kMinutesShift;
    final end = minuteToOffset(range.endMinute) / kMinutesShift;

    return Rect.fromLTWH(start, .0, end - start, size.height);
  }

  Rect _getAvailableZoneRect(Size size) {
    final startPosition = minuteToOffset(timeWindow.beginMinute / kMinutesShift);
    final endPosition = minuteToOffset(timeWindow.endMinute / kMinutesShift);

    return Rect.fromLTRB(startPosition, .0, endPosition, size.height);
  }

  TimeRange _geometryToData(Rect rect) {
    final begin = _dxToTime(rect.left);
    final end = _dxToTime(rect.right);

    return TimeRange(begin: begin, end: end);
  }

  TimeOfDay _dxToTime(double dx) {
    final shift = dx / gap;
    final totalMinutes = (shift * kMinutesShift).remainder(kMinutesPerDay);

    final hours = (totalMinutes ~/ TimeOfDay.minutesPerHour).remainder(TimeOfDay.hoursPerDay);
    final minutes = totalMinutes.remainder(TimeOfDay.minutesPerHour).round();

    return TimeOfDay(hour: hours, minute: minutes);
  }

  void _focusOnSelector(Rect selector, [bool animated = false]) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      parent?.showOnScreen(
        descendant: this,
        rect: EdgeInsets.only(
          right: viewportRect.right - selector.width - kHorizontalFocusPadding,
          left: kHorizontalFocusPadding,
        ).inflateRect(selector),
        duration: animated ? scrollAnimationStyle.duration ?? Duration.zero : Duration.zero,
        curve: animated ? scrollAnimationStyle.curve ?? Curves.ease : Curves.ease,
      );
    });
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

  // Анимированно привязывает позицию прямоугольника к делениям на шкале
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

    var left = selfConstraints.constrainWidth(dx);

    if (left + _selectorRect.width >= selfConstraints.maxWidth) {
      left -= _selectorRect.width;
    }

    final newRect = Rect.fromLTWH(left, _selectorRect.top, minSelectorWidth, _selectorRect.height);
    _animatedUpdateSelectorRect(newRect, () {
      onChangeSelectorRange?.call(_geometryToData(newRect));
    });
  }

  void _updateSelectorSizeByOffset(Offset offset, Offset delta) {
    var dx = offset.dx;

    final leftExtent = clampDouble(viewportRect.left, .0, selfConstraints.maxWidth);
    final rightExtent = math.min(viewportRect.right, selfConstraints.maxWidth);

    if (_isDraggingLeftCorner) {
      final width = (_selectorRect.left - dx) + _selectorRect.width;

      final newRect = Rect.fromLTWH(
        dx,
        _selectorRect.top,
        clampDouble(width, minSelectorWidth, selfConstraints.maxWidth),
        _selectorRect.height,
      );

      if (newRect.left < 0 || newRect.right > size.width) return;

      // Scrolling
      if ((offset.dx - viewportRect.left).round() <= kAxisScrollThreshold && leftExtent > selfConstraints.minWidth) {
        parent?.showOnScreen(
          descendant: this,
          rect: Rect.fromLTWH(viewportRect.left - kDragArea, .0, 1, newRect.height),
          curve: scrollAnimationStyle.curve ?? Curves.ease,
          duration: scrollAnimationStyle.duration ?? Durations.short2,
        );
      } else if ((viewportRect.right - newRect.right) < kAxisScrollThreshold && newRect.width == minSelectorWidth) {
        parent?.showOnScreen(
          descendant: this,
          rect: Rect.fromLTWH(rightExtent + kDragArea, .0, kDragArea, newRect.height),
          curve: scrollAnimationStyle.curve ?? Curves.ease,
          duration: scrollAnimationStyle.duration ?? Durations.short2,
        );
      }

      _updateSelectorRect(newRect);
    } else if (_isDraggingRightCorner) {
      var left = _selectorRect.left;
      var width = _selectorRect.width;

      width = clampDouble(width + (dx - _selectorRect.right), minSelectorWidth, selfConstraints.maxWidth);
      if (width == minSelectorWidth) {
        left -= _selectorRect.right - dx;
      }

      final newRect = Rect.fromLTWH(
        selfConstraints.constrainWidth(left),
        _selectorRect.top,
        width,
        _selectorRect.height,
      );

      if (newRect.right > size.width) return;

      if ((viewportRect.right - offset.dx).round() <= kAxisScrollThreshold && rightExtent < selfConstraints.maxWidth) {
        parent?.showOnScreen(
          descendant: this,
          rect: Rect.fromLTWH(viewportRect.right + kDragArea, .0, 1, newRect.height),
          duration: scrollAnimationStyle.duration ?? Durations.short2,
        );
      } else if (!viewportRect.contains(newRect.topLeft - Offset(kAxisScrollThreshold, .0)) &&
          newRect.width == minSelectorWidth) {
        parent?.showOnScreen(
          descendant: this,
          rect: Rect.fromLTWH(leftExtent - kDragArea, .0, kDragArea, newRect.height),
          duration: scrollAnimationStyle.duration ?? Durations.short2,
        );
      }

      _updateSelectorRect(newRect);
    }
  }

  // ------------------------ //

  void _drawSelector(PaintingContext context, Offset offset) {
    final canvas = context.canvas;

    selectorDecoration.paint(
      canvas,
      _selectorRect,
      selectorBorder,
      textDirection,
    );

    final linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.fill;

    final shift = Offset(3, 0);

    final verticalSpace = _selectorRect.height * .21;

    canvas.drawLine(
      (_selectorRect.topLeft + shift) + Offset(0, verticalSpace),
      (_selectorRect.bottomLeft + shift) - Offset(0, verticalSpace),
      linePaint,
    );

    canvas.drawLine(
      (_selectorRect.topRight - shift) + Offset(0, verticalSpace),
      (_selectorRect.bottomRight - shift) - Offset(0, verticalSpace),
      linePaint,
    );
  }

  void _drawTimescale(Canvas canvas) {
    final height = timeScaleSize.height;
    final timeScalePaint = Paint()
      ..color = timeScaleColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.fill;
    canvas.drawLine(Offset(0, height), Offset(size.width, height), timeScalePaint);
    for (int step = 0; step < kSteps; step++) {
      var normalizedStep = step + 1;
      final shift = gap * normalizedStep;

      final minuteShift = (normalizedStep * kMinutesShift);

      final remainder = minuteShift.remainder(TimeOfDay.minutesPerHour);

      final topShift = switch (remainder) {
        15 || 45 => height * 0.5,
        30 => height * 0.2,
        _ => .0,
      };
      final hourOffset = Offset(shift, height);
      canvas.drawLine(hourOffset, Offset(shift, topShift), timeScalePaint);

      if (isHour(remainder) && normalizedStep < kSteps) {
        _drawTimeLabel(canvas: canvas, offset: hourOffset, minuteShift: minuteShift);
      }
    }

    if (timeWindow == TimeRange.day) return;
    _drawHatch(canvas, _availableZoneRect);
  }

  void _drawHatch(Canvas canvas, Rect rect) {
    final height = timeScaleSize.height;

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

    for (double i = -height; i < gap * (kSteps + 2); i += hatchStyle.space) {
      final x = i;
      final y = 0.0;
      final dx = x + height * sinAngle / cosAngle;
      final dy = height;

      path.moveTo(x, y);
      path.lineTo(dx, dy);
    }

    canvas.save();
    canvas.clipRect(rect, clipOp: ClipOp.difference);
    canvas.clipRect(Offset.zero & timeScaleSize);
    canvas.drawRect(Offset.zero & timeScaleSize, backgroundPaint);
    canvas.drawPath(path, hatchPaint);
    canvas.restore();
  }

  void _drawTimeLabel({required Canvas canvas, required Offset offset, required int minuteShift}) {
    int hours = (minuteShift ~/ TimeOfDay.minutesPerHour).remainder(TimeOfDay.hoursPerDay);
    int minutes = minuteShift.remainder(TimeOfDay.minutesPerHour);

    TextStyle style = enabledLabelStyle;

    if (minuteShift < timeWindow.beginMinute || minuteShift > timeWindow.endMinute) {
      style = disabledLabelStyle;
    }

    final timePainter = _textPainterCache.putIfAbsent(
      minuteShift,
      () => TextPainter(
        text: TextSpan(
          text: localization.formatTimeOfDay(TimeOfDay(hour: hours, minute: minutes)),
          style: timeLabelStyle.merge(style),
        ),
        textDirection: textDirection,
        maxLines: 1,
      )..layout(),
    );

    final dx = offset.dx - (timePainter.width / 2);

    timePainter.paint(canvas, Offset(dx, offset.dy + kTopPaddingOfTimeLabel));
  }

  bool isHour(int remainder) => remainder == 0;

  double minuteToOffset(num minute) => minute * gap;

  void _redrawTimeScale() {
    _timelineLayerHandler.layer = null;
  }

  @override
  void dispose() {
    _parentAnimation.dispose();
    _animationController.dispose();

    _timelineLayerHandler.layer = null;
    for (var painter in _textPainterCache.values) {
      painter.dispose();
    }
    _textPainterCache.clear();
    super.dispose();
  }
}

extension TimeOfDayExtension on TimeOfDay {
  int get totalMinutes => (hour * TimeOfDay.minutesPerHour) + minute;

  bool operator <(TimeOfDay value) => totalMinutes < value.totalMinutes;

  bool operator >(TimeOfDay value) => totalMinutes > value.totalMinutes;
}
