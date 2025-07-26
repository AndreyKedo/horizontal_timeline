import 'dart:ui';

import 'package:flutter/foundation.dart' show ValueListenable, setEquals;
import 'package:flutter/material.dart';
import 'package:horizontal_timeline/animated_render_object.dart';
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:horizontal_timeline/styles/hatch_style.dart';
import 'package:horizontal_timeline/styles/selector_decoration.dart';
import 'package:horizontal_timeline/time_extension.dart';
import 'package:horizontal_timeline/time_range.dart';

export 'package:horizontal_timeline/styles/selector_decoration.dart';
export 'package:horizontal_timeline/styles/hatch_style.dart';
export 'package:horizontal_timeline/time_extension.dart';
export 'package:horizontal_timeline/time_range.dart';

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
const kMinGap = 24.0;

/// Горизонтальный отступ при фокусировки на доступной области.
const kHorizontalFocusPadding = 32.0;

/// Коэффициент чувствительности при которой будет обнаружен жест прокрутки.
const kScrollThreshold = 5.0;

/// Чувствительность горизонтальной прокрутки.
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

/// Стиль анимации для шкалы выбора времени по умолчанию.
final kDefaultSelectorAnimationStyle = AnimationStyle(curve: Curves.easeInOut, duration: Durations.short3);

/// Стиль анимации прокрутки по умолчанию .
final kDefaultScrollAnimationStyle = AnimationStyle(curve: Curves.linear, duration: Durations.short2);

/// Тип унарного обратного вызова, который принимает аргумент типа [TimeRange].
typedef OnChangeSelectorRange = void Function(TimeRange value);

/// {@template timeline}
/// Виджет, который отображает временную шкалу длиной 24 часа с возможностью выбирать определённый временной диапазон.
/// При изменении выбранного диапазона автоматически вызывается обратный вызов [onChange], принимающий аргумент
/// типа [TimeRange].
///
/// Для задания начального положения элемента выбора временного диапазона используется свойство [initialSelectorRange].
/// Минимальное допустимое значение диапазона задаётся с помощью свойства [minSelectorRange].
/// Кастомизация внешнего вида доступна через свойство [selectorDecoration].
///
/// Настройка шага временной шкалы осуществляется с использованием параметра [gap] — его значение не
/// должно быть ниже значения [kMinGap].
/// Интервалы доступных временных промежутков указываются в свойстве [availableRanges].
///
/// Дополнительная настройка визуализации производится посредством следующих свойств:
/// * [timeScaleColor]: Цвет контура шкалы.
/// * [strokeWidth]: Толщина линии контура.
/// * [timeLabelStyle]: Стиль подписей временных меток.
/// * [enabledLabelStyle]: Стиль подписей доступных интервалов времени.
/// * [disabledLabelStyle]: Стиль подписей недоступных интервалов времени.
/// * [hatchStyle]: Стиль штриховки для обозначения не доступных интервалов.
///
/// Данный виджет автоматически находит ближайший родительский виджет [Scrollable] для взаимодействия с прокруткой.
/// Убедитесь, что этот виджет является потомком другого виджета вроде [SingleChildScrollView],
/// однако не **поддерживает** использование внутри [CustomScrollView].
/// Обратите внимание, что поддерживается только горизонтальная ориентация [Axis.horizontal], а также обязательно
/// применяйте свойство [Scrollable.hitTestBehavior] = [HitTestBehavior.deferToChild] в родительских виджетах для
/// правильной обработки жестов.
///
/// Сам виджет не устанавливает собственную минимальную высоту, поэтому он принимает высоту своего
/// родительского контейнера. Необходимо внимательно следить за заданием максимальной высоты виджета,
/// используя такие виджеты, как [ConstrainedBox], перед добавлением внутрь [SingleChildScrollView].
///
/// Пример использования
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
  });

  /// Начальное значение диапазона времени. Если равно null элемент выбора времени не отображается.
  final TimeRange? initialSelectorRange;

  /// Обратный вызов который вызывается каждый раз, когда изменяется выбранный диапазон времени.
  final OnChangeSelectorRange? onChange;

  /// Доступные для выбора временные диапазоны. Если список пустой ограничение не накладываются.
  final Set<TimeRange> availableRanges;

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
    assert(debugTimeOfDayCheck(minSelectorRange));

    if (initialSelectorRange != null) {
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
      ..availableRanges = availableRanges
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
    required Set<TimeRange> availableRanges,
    required HatchStyle hatchStyle,
    required TimeOfDay minSelectorRange,
    required TimeRange? initialSelectorValue,
    required AnimationStyle animationStyle,
    required AnimationStyle scrollAnimationStyle,
    required ValueListenable<bool> tickerNotifier,
    required OnChangeSelectorRange? onChangeSelectorRange,
    required SelectorDecoration selectorDecoration,
    required ScrollableState scrollable,
  }) : _scrollable = scrollable,
       _gap = gap,
       _initialSelectorRange = initialSelectorValue,
       _timeScaleColor = timeScaleColor,
       _strokeWidth = strokeWidth,
       _localization = localization,
       _timeLabelStyle = timeLabelStyle,
       _textDirection = textDirection,
       _enabledLabelStyle = enabledLabelStyle,
       _disabledLabelStyle = disabledLabelStyle,
       _availableRanges = availableRanges,
       _hatchStyle = hatchStyle,
       _selectorDecoration = selectorDecoration,
       _minSelectorRange = minSelectorRange,
       _scrollAnimationStyle = scrollAnimationStyle,
       _animationStyle = animationStyle,
       _onChangeSelectorRange = onChangeSelectorRange {
    tickerModeNotifier = tickerNotifier;

    _initializeAnimation(animationStyle);
  }

  // Paint optimization
  final _textPainterCache = <int, TextPainter>{};

  final _timelineLayerHandler = LayerHandle<PictureLayer>();

  final _hatchLayerHandler = LayerHandle<PictureLayer>();

  /// Animation
  late AnimationController _animationController;
  late CurvedAnimation _parentAnimation;
  Animation<Rect?>? _animation;

  /// Scroll controller
  ScrollableState _scrollable;

  // Выделения диапазона времени
  Rect _selectorRect = Rect.zero;

  // Доступная для выбора зона
  Set<Rect> _availableZones = const <Rect>{};

  // Нужен для обнаружения прокрутки
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

  /// Видимая часть. Меняется в зависимости от позиции прокрутки
  /// Имеет отступы [kHorizontalFocusPadding] по горизонтали
  Rect get viewportRect {
    final position = _scrollable.position;

    return Offset(position.pixels, .0) & Size(position.viewportDimension, selfConstraints.maxHeight);
  }

  /// Включен/Выключен выделитель времени
  bool get isEnabledSelector => initialSelectorRange != null && _selectorRect.width != 0;

  BoxBorder get effectiveSelectorBorder {
    var borderPainter = selectorDecoration.border;

    if (!_availableZones.any(_collisionDetectorPredicate) && selectorDecoration.errorBorder != null) {
      borderPainter = selectorDecoration.errorBorder!;
    }
    return borderPainter;
  }

  Offset get _leftEdgeCenter =>
      _selectorRect.centerLeft - Offset((kDragArea / 2) - effectiveSelectorBorder.dimensions.horizontal / 2, .0);

  Offset get _rightEdgeCenter =>
      _selectorRect.centerRight + Offset((kDragArea / 2) - effectiveSelectorBorder.dimensions.horizontal / 2, .0);

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
    _textPainterCache.clear();
    _availableZones = _rangesToGeometry(value, timeScaleSize);
    _redrawHatch();
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
    _redrawHatch();
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

  //-------------------------------

  @override
  bool get sizedByParent => true;

  @override
  bool get isRepaintBoundary => true;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    _redrawTimeScale();
    final size = constraints.constrain(Size.fromWidth(_gap * kSteps));

    final scaleSize = Size(size.width, size.height * kSelectorAreaHeightPercentage);
    _availableZones = _rangesToGeometry(availableRanges, scaleSize);

    if (initialSelectorRange != null) {
      _selectorRect = _getDefaultSelectorRect(scaleSize, initialSelectorRange!);

      /// Фокусирует на области выбора доступного времени
      /// Работает только при наличие предка типа *Viewport
      _focusOnSelector(_selectorRect);
    }

    return size;
  }

  @override
  void debugPaint(PaintingContext context, Offset offset) {
    if (debugPaintSizeEnabled) {
      final canvas = context.canvas;

      final scrollOffset = Offset(_scrollable.position.pixels + 2, selfConstraints.maxHeight / 2);

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

      final anchorPaint =
          Paint()
            ..color = Colors.teal.withAlpha(80)
            ..style = PaintingStyle.fill;

      // left drag anchor
      canvas.drawRect(_dragAnchor(_leftEdgeCenter), anchorPaint);

      // Right drag anchor
      canvas.drawRect(_dragAnchor(_rightEdgeCenter), anchorPaint);
    }

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
        onChangeSelectorRange?.call(_geometryToRange(_selectorRect));
      });
    }
  }

  // ---------------------- //

  @override
  void paint(PaintingContext context, Offset offset) {
    // кэшируем слой шкалы для дальнейшего переиспользовать
    drawOnPictureLayer(context: context, layer: _timelineLayerHandler, size: size, draw: _drawTimescale);

    // кэшируем слой заштриховки
    drawOnPictureLayer(context: context, layer: _hatchLayerHandler, size: size, draw: _drawHatch);

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

  Rect _dragAnchor(Offset center) =>
      Rect.fromCenter(center: center, width: kDragArea, height: selfConstraints.maxHeight);

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

  TimeRange _geometryToRange(Rect rect) {
    final begin = _dxToTime(rect.left);
    final end = _dxToTime(rect.right);

    return TimeRange(begin: begin, end: end);
  }

  Set<Rect> _rangesToGeometry(Set<TimeRange> ranges, Size size) {
    final geometrySet = <Rect>{};
    for (var range in availableRanges) {
      final startPosition = minuteToOffset(range.beginMinute / kMinutesShift);
      final endPosition = minuteToOffset(range.endMinute / kMinutesShift);

      final rect = Rect.fromLTRB(startPosition, .0, endPosition, size.height);
      geometrySet.add(rect);
    }

    return geometrySet;
  }

  TimeOfDay _dxToTime(double dx) {
    final shift = dx / gap;
    final totalMinutes = shift * kMinutesShift;
    final hours = switch (totalMinutes) {
      < TimeOfDay.minutesPerHour * TimeOfDay.hoursPerDay => (totalMinutes ~/ TimeOfDay.minutesPerHour).remainder(
        TimeOfDay.hoursPerDay,
      ),
      _ => 24,
    };
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

  bool isHour(int remainder) => remainder == 0;

  double minuteToOffset(num minute) => minute * gap;

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

  // Анимированно изменяет прямоугольник. Обратный вызов [onComplete] может быть использован
  // для действия после анимации.
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

  // Анимированно привязывает позицию прямоугольника к делениям на шкале. Обратный вызов [onComplete]
  // может быть использован для действия после анимации.
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
      onChangeSelectorRange?.call(_geometryToRange(newRect));
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
          rect: Rect.fromLTWH(rightExtent + kDragArea, .0, 1, newRect.height),
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
          rect: Rect.fromLTWH(leftExtent - kDragArea, .0, 1, newRect.height),
          duration: scrollAnimationStyle.duration ?? Durations.short2,
        );
      }

      _updateSelectorRect(newRect);
    }
  }

  // ------------------------ //

  // --- Paint --- //

  void _drawSelector(Canvas canvas, Offset offset) {
    selectorDecoration.paint(canvas, _selectorRect, effectiveSelectorBorder, textDirection);
  }

  void _drawTimescale(Canvas canvas) {
    final height = timeScaleSize.height;
    final timeScalePaint =
        Paint()
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
  }

  void _drawHatch(Canvas canvas) {
    final height = timeScaleSize.height;

    final backgroundPaint =
        Paint()
          ..color = hatchStyle.backgroundColor
          ..style = PaintingStyle.fill;

    const hatchAngle = 45 * math.pi / -180;
    final hatchPaint =
        Paint()
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
    path.close();

    final availableRangesPath = Path();
    for (var rect in _availableZones) {
      availableRangesPath.addRect(rect);
    }
    availableRangesPath.close();

    final clip = Path.combine(
      PathOperation.difference,
      Path()
        ..addRect(Offset.zero & timeScaleSize)
        ..close(),
      availableRangesPath,
    );

    canvas
      ..save()
      ..clipPath(clip);
    canvas
      ..drawRect(Offset.zero & timeScaleSize, backgroundPaint)
      ..drawPath(path, hatchPaint);
    canvas.restore();
  }

  void _drawTimeLabel({required Canvas canvas, required Offset offset, required int minuteShift}) {
    int hours = (minuteShift ~/ TimeOfDay.minutesPerHour).remainder(TimeOfDay.hoursPerDay);
    int minutes = minuteShift.remainder(TimeOfDay.minutesPerHour);

    TextStyle style = enabledLabelStyle;

    final time = TimeOfDay(hour: hours, minute: minutes);

    if (!availableRanges.any((range) => range.overlaps(time))) {
      style = disabledLabelStyle;
    }

    final timePainter = _textPainterCache.putIfAbsent(
      minuteShift,
      () => TextPainter(
        text: TextSpan(text: localization.formatTimeOfDay(time), style: timeLabelStyle.merge(style)),
        textDirection: textDirection,
        maxLines: 1,
      )..layout(),
    );

    final dx = offset.dx - (timePainter.width / 2);

    timePainter.paint(canvas, Offset(dx, offset.dy + kTopPaddingOfTimeLabel));
  }

  void _redrawTimeScale() {
    _timelineLayerHandler.layer = null;
  }

  void _redrawHatch() {
    _hatchLayerHandler.layer = null;
  }

  // ------------- //

  bool _collisionDetectorPredicate(Rect rect) {
    return _selectorRect.right <= rect.right && _selectorRect.left >= rect.left;
  }

  void _disposeAnimations() {
    _parentAnimation.dispose();
    _animationController.dispose();
  }

  @override
  void dispose() {
    _disposeAnimations();

    _hatchLayerHandler.layer = null;
    _timelineLayerHandler.layer = null;
    for (var painter in _textPainterCache.values) {
      painter.dispose();
    }
    _textPainterCache.clear();
    super.dispose();
  }
}

void drawOnPictureLayer({
  required LayerHandle<PictureLayer> layer,
  required PaintingContext context,
  required Size size,
  required ValueSetter<Canvas> draw,
}) {
  if (layer.layer == null) {
    final pictureRecorder = PictureRecorder();
    final canvas = Canvas(pictureRecorder);

    draw(canvas);

    final picture = pictureRecorder.endRecording();

    layer.layer = PictureLayer(Rect.fromLTWH(0, 0, size.width, size.height))..picture = picture;
  }

  if (layer.layer != null) {
    context.addLayer(layer.layer!);
  }
}
