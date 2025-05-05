import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:timeline_widget/timeline.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: Locale('ru', 'RU'),
      supportedLocales: [Locale('ru', 'RU')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: TimelineScroll(),
    );
  }
}

final class TimelineScroll extends StatefulWidget {
  const TimelineScroll({super.key});

  @override
  State<TimelineScroll> createState() => _TimelineScrollState();
}

/// State for widget TimelineScroll
class _TimelineScrollState extends State<TimelineScroll> {
  static const defaultMinSelectorRange = TimeOfDay(hour: 0, minute: 30);

  final valueNotifier = ValueNotifier<TimeRange?>(null);

  TimeRange? initial = TimeRange(begin: TimeOfDay(hour: 9, minute: 0), end: TimeOfDay(hour: 10, minute: 0));
  double gap = 24;
  TimeOfDay minSelectorRange = TimeOfDay(hour: 0, minute: 30);
  TimeRange timeWindow = TimeRange(begin: TimeOfDay(hour: 9, minute: 0), end: TimeOfDay(hour: 18, minute: 0));
  double stroke = 1;

  @override
  void dispose() {
    valueNotifier.dispose();
    super.dispose();
  }

  String _rangeToString(TimeRange value) {
    final materialLocalization = MaterialLocalizations.of(context);
    final strBuilder =
        StringBuffer()
          ..write(materialLocalization.formatTimeOfDay(value.begin))
          ..write(' - ')
          ..write(materialLocalization.formatTimeOfDay(value.end));

    return strBuilder.toString();
  }

  @override
  Widget build(BuildContext context) {
    final defaultConfiguration = ScrollConfiguration.of(context);
    final materialLocalization = MaterialLocalizations.of(context);

    return ScrollConfiguration(
      behavior: defaultConfiguration.copyWith(dragDevices: {PointerDeviceKind.mouse, PointerDeviceKind.touch}),
      child: Scaffold(
        floatingActionButton: FloatingActionButton(
          child: Text(gap.toString()),
          onPressed: () {
            setState(() {
              if (gap == 24) {
                gap = 48;
              } else if (gap == 48) {
                gap = 24;
              }
            });
          },
        ),
        body: SafeArea(
          child: Center(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 16,
                    children: [
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          OutlinedButton(
                            onPressed: () async {
                              final begin = await showTimePicker(context: context, initialTime: minSelectorRange);
                              if (begin == null) return;

                              if (!context.mounted) return;
                              final end = await showTimePicker(context: context, initialTime: minSelectorRange);
                              if (end == null) return;

                              if (end < begin) return;
                              setState(() {
                                initial = TimeRange(begin: begin, end: end);
                              });
                            },
                            child: Text('Set selector position'),
                          ),
                          OutlinedButton(
                            onPressed: () {
                              setState(() {
                                initial = null;
                              });
                            },
                            child: Text('Reset'),
                          ),
                        ],
                      ),
                      OutlinedButton(
                        onPressed: () async {
                          final value = await showTimePicker(context: context, initialTime: minSelectorRange);
                          if (value == null || value.totalMinutes < defaultMinSelectorRange.totalMinutes) return;

                          setState(() {
                            minSelectorRange = value;
                          });
                        },
                        child: Text('Min selector range'),
                      ),
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          OutlinedButton(
                            onPressed:
                                () => setState(() {
                                  timeWindow = TimeRange.empty;
                                }),
                            style: ButtonStyle(foregroundColor: WidgetStatePropertyAll(Colors.redAccent)),
                            child: Text('All unavailable'),
                          ),
                          OutlinedButton(
                            onPressed:
                                () => setState(() {
                                  timeWindow = TimeRange.day;
                                }),
                            style: ButtonStyle(foregroundColor: WidgetStatePropertyAll(Colors.green)),
                            child: Text('All available '),
                          ),
                          OutlinedButton(
                            onPressed: () async {
                              final begin = await showTimePicker(context: context, initialTime: minSelectorRange);
                              if (begin == null) return;

                              if (!context.mounted) return;
                              final end = await showTimePicker(context: context, initialTime: minSelectorRange);
                              if (end == null) return;

                              if (end < begin) return;

                              setState(() {
                                timeWindow = TimeRange(begin: begin, end: end);
                              });
                            },
                            child: Text('Set available range'),
                          ),
                        ],
                      ),
                      Slider.adaptive(
                        value: stroke,
                        min: 1,
                        max: 3,
                        divisions: 3,
                        onChanged: (value) {
                          setState(() {
                            stroke = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 48,
                      children: [
                        ValueListenableBuilder(
                          valueListenable: valueNotifier,
                          builder: (context, value, child) {
                            var effectiveValue = value ?? initial ?? TimeRange.empty;
                            return Offstage(
                              offstage: value == null && initial == null,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _rangeToString(effectiveValue),
                                    style: Theme.of(context).textTheme.displayMedium,
                                  ),

                                  Text(
                                    materialLocalization.formatTimeOfDay(effectiveValue.time),
                                    style: Theme.of(context).textTheme.displayMedium,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        ConstrainedBox(
                          constraints: BoxConstraints.loose(Size.fromHeight(95)),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            hitTestBehavior: HitTestBehavior.deferToChild,
                            child: Timeline(
                              gap: gap,
                              initialSelectorRange: initial,
                              minSelectorRange: minSelectorRange,
                              availableWindow: timeWindow,
                              strokeWidth: stroke,
                              onChange: (value) {
                                valueNotifier.value = value;
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
