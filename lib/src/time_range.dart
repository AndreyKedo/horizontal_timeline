import 'package:flutter/material.dart';
import 'package:horizontal_timeline/src/time_extension.dart';

/// Number of minutes in a day.
const kMinutesPerDay = TimeOfDay.hoursPerDay * TimeOfDay.minutesPerHour;

/// Checks that [TimeOfDay] has correct hour and minute values.
bool debugTimeOfDayCheck(TimeOfDay value) {
  assert(() {
    if (value.hour > TimeOfDay.hoursPerDay || value.hour < 0) {
      throw FlutterError(
        'Invalid time value. Time must be 0 >= TimeOfDay.hour <= TimeOfDay.hoursPerDay',
      );
    }

    if (value.minute > TimeOfDay.minutesPerHour || value.minute < 0) {
      throw FlutterError(
        'Invalid time value. Time must be 0 >= TimeOfDay.minute <= TimeOfDay.minutesPerHour',
      );
    }
    return true;
  }());
  return true;
}

TimeOfDay timeOfDayFromMinute(num value) {
  assert(value <= kMinutesPerDay && value >= 0, 'Time must be in the range from 0 to 24');
  final hours = value ~/ TimeOfDay.minutesPerHour;

  final minutes = value.remainder(TimeOfDay.minutesPerHour).round();
  return TimeOfDay(hour: hours, minute: minutes);
}

/// Time range.
@immutable
class TimeRange {
  /// Creates a new time range.
  ///
  /// [begin] - the start time of the range.
  /// [end] - the end time of the range.
  TimeRange({this.begin = const TimeOfDay(hour: 0, minute: 0), this.end = const TimeOfDay(hour: 0, minute: 0)})
      : assert(
          end.hour == 0 || (end.hour > 0 && begin.isBefore(end)),
          'The lower time boundary must be less than the upper one.',
        ),
        assert(debugTimeOfDayCheck(begin)),
        assert(debugTimeOfDayCheck(end));

  /// Start of the range.
  final TimeOfDay begin;

  /// End of the range.
  final TimeOfDay end;

  /// Returns the start of the range in minutes.
  int get beginMinute => begin.totalMinutes;

  /// Returns the end of the range in minutes.
  int get endMinute => switch (end.totalMinutes) {
        0 => kMinutesPerDay,
        final value => value,
      };

  /// Returns the duration of the range in minutes.
  int get minutes => endMinute - beginMinute;

  /// Static instance representing the entire day (00:00 - 24:00).
  static final day = TimeRange();

  /// Returns the duration of the range as [TimeOfDay].
  TimeOfDay get time => timeOfDayFromMinute(minutes);

  /// Checks if the given time [value] overlaps with this range.
  bool overlaps(TimeOfDay value, {bool include = true}) {
    final inMinute = value.totalMinutes;

    if (include) {
      return inMinute >= beginMinute && inMinute <= endMinute;
    } else {
      return inMinute > beginMinute && inMinute < endMinute;
    }
  }

  /// Creates a copy of this range with the ability to change the start and/or end.
  ///
  /// [begin] - new start time (if not specified, the current one is used).
  /// [end] - new end time (if not specified, the current one is used).
  TimeRange copyWith({TimeOfDay? begin, TimeOfDay? end}) => TimeRange(begin: begin ?? this.begin, end: end ?? this.end);

  @override
  String toString() => '$begin - $end';

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
