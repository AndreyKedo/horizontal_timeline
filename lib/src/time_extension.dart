import 'package:flutter/material.dart' show TimeOfDay;

extension TimeOfDayExtension on TimeOfDay {
  int get totalMinutes => (hour * TimeOfDay.minutesPerHour) + minute;

  bool operator <(TimeOfDay value) => totalMinutes < value.totalMinutes;
  bool operator <=(TimeOfDay value) => totalMinutes <= value.totalMinutes;

  bool operator >(TimeOfDay value) => totalMinutes > value.totalMinutes;
  bool operator >=(TimeOfDay value) => totalMinutes >= value.totalMinutes;
}
