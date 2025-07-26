## 1.0.0

* Initial

## 1.1.0

* `availableWindow` changed to `availableRanges`
* bump sdk version to 3.7.2
* update example.

## 1.2.0

* if the collection of `availableRanges` is empty the timeline is completely filled

## 1.2.1

* Update documentation.

## 1.2.2

* Fixed incorrect calculation of time range

## 1.3.0

Refactor time handling and add styling features

* Added TimeOfDay extension and TimeRange class for better time comparison and management
* Introduced HatchStyle and updated selector styling
* Moved selector_decoration.dart to styles directory
* Updated paint logic to use separate layers for hatch and timescale
* Updated example