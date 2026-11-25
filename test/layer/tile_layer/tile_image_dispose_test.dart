import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/src/layer/tile_layer/tile_image.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hands out one image per load, so a reload delivers a new one.
class _Provider extends ImageProvider<_Provider> {
  _Provider(this.images);

  final List<ui.Image> images;
  int _next = 0;

  @override
  Future<_Provider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(_Provider key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(
          SynchronousFuture(ImageInfo(image: images[_next++])));
}

TileImage _tile(ImageProvider provider) => TileImage(
      vsync: const TestVSync(),
      coordinates: const TileCoordinates(0, 0, 0),
      imageProvider: provider,
      onLoadComplete: (_) {},
      onLoadError: (_, __, ___) {},
      tileDisplay: const TileDisplay.instantaneous(),
      errorImage: null,
      cancelLoading: Completer<void>(),
    );

void main() {
  // The image cache would keep its own handle; without it, the tile's handle
  // is the only one left once the stream completer lets go.
  setUp(() => PaintingBinding.instance.imageCache.maximumSize = 0);

  testWidgets('a tile disposes its image when it is disposed', (tester) async {
    final image = (await tester.runAsync(createTestImage))!;
    final tile = _tile(_Provider([image]))..load();
    expect(tile.imageInfo, isNotNull);
    final received = tile.imageInfo!.image;

    tile.dispose();

    expect(tile.imageInfo, isNull);
    expect(received.debugDisposed, isTrue);
  });

  testWidgets('a reload in place disposes the previous image', (tester) async {
    final first = (await tester.runAsync(createTestImage))!;
    final second = (await tester.runAsync(createTestImage))!;
    final provider = _Provider([first, second]);
    final tile = _tile(provider)..load();
    final received = tile.imageInfo!.image;

    // A new key, as a provider with other options would have.
    PaintingBinding.instance.imageCache.clear();
    tile
      ..imageProvider = _Provider([second])
      ..load();

    expect(received.debugDisposed, isTrue);
    expect(tile.imageInfo!.image.debugDisposed, isFalse);
    tile.dispose();
  });
}
