import 'dart:ui';

import 'package:flutter/rendering.dart';

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
