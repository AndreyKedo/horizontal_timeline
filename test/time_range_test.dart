import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horizontal_timeline/src/time_range.dart';

void main() {
  test('Day', () {
    final day = TimeRange.day;

    expect(day.time, TimeOfDay(hour: 24, minute: 0));
  });

  test('Day minutes', () {
    final day = TimeRange.day;

    expect(day.minutes, kMinutesPerDay);
  });

  test('Comparison', () {
    final day = TimeRange.day;
    final other = TimeRange(begin: TimeOfDay(hour: 9, minute: 0), end: TimeOfDay(hour: 18, minute: 0));

    expect(day == other, isFalse);
  });

  test('Overlaps', () {
    final time = TimeRange(begin: TimeOfDay(hour: 9, minute: 0), end: TimeOfDay(hour: 18, minute: 0));

    expect(time.overlaps(TimeOfDay(hour: 0, minute: 0)), isFalse, reason: 'First expect fail');

    expect(time.overlaps(TimeOfDay(hour: 9, minute: 0)), isTrue, reason: 'Second expect fail');

    expect(time.overlaps(TimeOfDay(hour: 9, minute: 0), include: false), isFalse, reason: 'Three expect fail');

    expect(time.overlaps(TimeOfDay(hour: 14, minute: 0)), isTrue, reason: 'Four expect fail');
  });

  test('24-hour', () {
    final day = TimeRange.day;

    expect(day.endMinute, kMinutesPerDay);
  });
}
