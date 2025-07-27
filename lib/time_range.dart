import 'package:flutter/material.dart';
import 'package:horizontal_timeline/time_extension.dart';

/// Количество минут в сутках.
const kMinutesPerDay = TimeOfDay.hoursPerDay * TimeOfDay.minutesPerHour;

/// Проверяет, что [TimeOfDay] имеет корректные значения часов и минут.
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

TimeOfDay timeOfDayFromMinute(num value) {
  assert(value <= kMinutesPerDay && value > 0, 'Время должно быть в диапазоне от 0 до 24');
  final hours = value ~/ TimeOfDay.minutesPerHour;
  final minutes = value.remainder(TimeOfDay.minutesPerHour).round();

  return TimeOfDay(hour: hours, minute: minutes);
}

/// Диапазон времени.
@immutable
class TimeRange {
  /// Создает новый временной диапазон.
  ///
  /// [begin] - время начала диапазона.
  /// [end] - время окончания диапазона.
  TimeRange({this.begin = const TimeOfDay(hour: 0, minute: 0), this.end = const TimeOfDay(hour: 0, minute: 0)})
    : assert(
        end.hour == 0 || (end.hour > 0 && begin.isBefore(end)),
        'Нижняя граница времени должна быть меньше верхней.',
      ),
      assert(debugTimeOfDayCheck(begin)),
      assert(debugTimeOfDayCheck(end));

  /// Начало диапазона.
  final TimeOfDay begin;

  /// Конец диапазона.
  final TimeOfDay end;

  /// Возвращает начало диапазона в минутах.
  int get beginMinute => begin.totalMinutes;

  /// Возвращает конец диапазона в минутах.
  int get endMinute {
    if (end.hour == 0) return kMinutesPerDay;

    return end.totalMinutes;
  }

  /// Возвращает продолжительность диапазона в минутах.
  int get minutes => endMinute - beginMinute;

  /// Статический экземпляр, представляющий весь день (00:00 - 24:00).
  static final day = TimeRange();

  /// Возвращает продолжительность диапазона в виде [TimeOfDay].
  TimeOfDay get time => timeOfDayFromMinute(minutes);
  //  {
  //   int hours = this.minutes ~/ TimeOfDay.minutesPerHour;

  //   int minutes = this.minutes.remainder(TimeOfDay.minutesPerHour);
  //   return TimeOfDay(hour: hours, minute: minutes);
  // }

  /// Проверяет, пересекается ли заданное время [value] с этим диапазоном.
  bool overlaps(TimeOfDay value, {bool include = true}) {
    final inMinute = value.totalMinutes;

    if (include) {
      return inMinute >= beginMinute && inMinute <= endMinute;
    } else {
      return inMinute > beginMinute && inMinute < endMinute;
    }
  }

  /// Создает копию этого диапазона с возможностью изменить начало и/или конец.
  ///
  /// [begin] - новое время начала (если не указано, используется текущее).
  /// [end] - новое время окончания (если не указано, используется текущее).
  TimeRange copyWith({TimeOfDay? begin, TimeOfDay? end}) => TimeRange(begin: begin ?? this.begin, end: end ?? this.end);

  @override
  int get hashCode => Object.hash(runtimeType, beginMinute, endMinute);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeRange &&
          runtimeType == other.runtimeType &&
          beginMinute == other.beginMinute &&
          endMinute == other.endMinute;
}
