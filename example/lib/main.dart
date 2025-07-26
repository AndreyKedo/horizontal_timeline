import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:horizontal_timeline/timeline.dart';

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
  Set<TimeRange> ranges = {TimeRange(begin: TimeOfDay(hour: 9, minute: 0), end: TimeOfDay(hour: 12, minute: 0))};
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
    final size = MediaQuery.sizeOf(context);
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
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints.expand(width: size.width, height: math.max(size.height, 500)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isSmall = constraints.maxWidth <= 600;
                          return Flex(
                            direction: isSmall ? Axis.vertical : Axis.horizontal,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 16,
                            children: [
                              Flexible(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  spacing: 16,
                                  children: [
                                    Wrap(
                                      spacing: 16,
                                      runSpacing: 16,
                                      children: [
                                        OutlinedButton(
                                          onPressed: () async {
                                            final begin = await showTimePicker(
                                              context: context,
                                              initialTime: minSelectorRange,
                                            );
                                            if (begin == null) return;

                                            if (!context.mounted) return;
                                            final end = await showTimePicker(
                                              context: context,
                                              initialTime: minSelectorRange,
                                            );
                                            if (end == null) return;

                                            if (end.hour > 0 && end < begin) return;
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
                                        final value = await showTimePicker(
                                          context: context,
                                          initialTime: minSelectorRange,
                                        );
                                        if (value == null ||
                                            value.totalMinutes < defaultMinSelectorRange.totalMinutes) {
                                          return;
                                        }

                                        setState(() {
                                          minSelectorRange = value;
                                        });
                                      },
                                      child: Text('Min selector range'),
                                    ),
                                    Flexible(
                                      child: Slider.adaptive(
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
                                    ),
                                  ],
                                ),
                              ),
                              if (!isSmall)
                                LayoutBuilder(
                                  builder:
                                      (context, constraints) => ConstrainedBox(
                                        constraints: BoxConstraints.expand(width: 1, height: constraints.maxHeight),
                                        child: VerticalDivider(),
                                      ),
                                ),
                              Flexible(
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Ranges', style: Theme.of(context).textTheme.headlineSmall),
                                        Flexible(
                                          child: ConstrainedBox(
                                            constraints: BoxConstraints.expand(
                                              width: 300,
                                              height: constraints.maxHeight,
                                            ),
                                            child: ListView.builder(
                                              itemCount: ranges.length,
                                              padding: EdgeInsets.symmetric(vertical: 16),
                                              itemBuilder: (context, index) {
                                                final item = ranges.elementAt(index);

                                                return ListTile(
                                                  leading: Text('${index + 1}.'),
                                                  title: Text(_rangeToString(item)),
                                                  trailing: IconButton(
                                                    onPressed: () {
                                                      setState(() {
                                                        ranges.remove(item);
                                                      });
                                                    },
                                                    icon: Icon(Icons.remove),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                        OutlinedButton(
                                          onPressed: () async {
                                            final begin = await showTimePicker(
                                              context: context,
                                              initialTime: minSelectorRange,
                                            );
                                            if (begin == null) return;

                                            if (!context.mounted) return;
                                            final end = await showTimePicker(
                                              context: context,
                                              initialTime: minSelectorRange,
                                            );
                                            if (end == null) return;

                                            if (end.hour > 0 && end < begin) return;

                                            setState(() {
                                              ranges.add(TimeRange(begin: begin, end: end));
                                            });
                                          },
                                          child: Text('Add'),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 48,
                      children: [
                        ValueListenableBuilder(
                          valueListenable: valueNotifier,
                          builder: (context, value, child) {
                            var effectiveValue = value ?? initial ?? TimeRange();
                            return Offstage(
                              offstage: value == null && initial == null,
                              child: FittedBox(
                                fit: BoxFit.fitWidth,
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
                              availableRanges: ranges.toSet(),
                              strokeWidth: stroke,
                              selectorDecoration: SelectorDecoration(
                                gradient: LinearGradient(colors: [Colors.blue, Colors.teal]),
                                border: BoxBorder.all(color: Colors.grey, width: 8),
                                borderRadius: BorderRadius.horizontal(
                                  right: Radius.circular(8),
                                  left: Radius.circular(8),
                                ),
                                errorBorder: BoxBorder.all(color: Colors.redAccent, width: 8),
                                dragHandleColor: Colors.white54,
                              ),
                              onChange: (value) {
                                valueNotifier.value = value;
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
