Timeline widget.
Draws a 24-hour time scale with 15-minute increments, allowing you to select a time range.

## Features

* Limiting the available time range.
* Full customization.
* Animated

## Getting started

### 1. Add the Timeline widget at a dependency.

To add a package compatible with the Flutter SDK to your project, use dart pub add.

For example:

`dart pub add timeline_widget`

### 2. Usage

> 🚧 **For correct operation, a parent Scrollable widget is required!**

> 🚧 **Be sure to limit the height, the widget has no minimum height!**

> 🚧 **The scrollable parent element must have `hitTestBehavior` set to `HitTestBehavior.deferToChild`. Otherwise, events will not reach the selector.**

```dart
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
      home: SizedBox(
              height: 95,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                hitTestBehavior: HitTestBehavior.deferToChild,
                child: Timeline(
                  initialSelectorRange: TimeWindow(begin: TimeOfDay(hour: 9, minute: 0), end: TimeOfDay(hour: 10, minute: 0)),
                  availableWindow: TimeWindow(begin: TimeOfDay(hour: 9, minute: 0), end: TimeOfDay(hour: 18, minute: 0)),
                ),
            ),
        ),
    );
  }
}
```

## Additional information

WIP
