import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import '../test_utils/test_tile_provider.dart';

/// Two fingers that first spread (the pinch wins the race) and then turn
/// [degrees] around the centre of the map, in small steps.
Future<void> _pinchThenTurn(WidgetTester tester, double degrees) async {
  final centre = tester.getCenter(find.byType(FlutterMap));
  Offset at(double radius, double deg) =>
      centre +
      Offset(math.cos(deg * math.pi / 180), math.sin(deg * math.pi / 180)) *
          radius;

  final a = await tester.startGesture(at(30, 0), pointer: 1);
  final b = await tester.startGesture(at(30, 180), pointer: 2);
  await tester.pump();
  for (var r = 32.0; r <= 80; r += 2) {
    await a.moveTo(at(r, 0));
    await b.moveTo(at(r, 180));
    await tester.pump();
  }
  final sign = degrees.sign;
  for (var d = 2.0; d <= degrees.abs(); d += 2) {
    await a.moveTo(at(80, sign * d));
    await b.moveTo(at(80, 180 + sign * d));
    await tester.pump();
  }
  await a.up();
  await b.up();
  await tester.pumpAndSettle();
}

Widget _map(MapController controller, {required bool joinsLate}) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 200,
            height: 200,
            child: FlutterMap(
              mapController: controller,
              options: MapOptions(
                initialCenter: const LatLng(45.5231, -122.6765),
                interactionOptions: InteractionOptions(
                  flags: InteractiveFlag.pinchZoom |
                      InteractiveFlag.pinchMove |
                      InteractiveFlag.rotate,
                  enableMultiFingerGestureRace: true,
                  rotationThreshold: 15,
                  pinchZoomThreshold: 0.3,
                  rotationJoinsLate: joinsLate,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  tileProvider: TestTileProvider(),
                ),
              ],
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('a turn that comes after the pinch won still rotates the map',
      (tester) async {
    final controller = MapController();
    await tester.pumpWidget(_map(controller, joinsLate: true));
    await _pinchThenTurn(tester, 40);

    expect(controller.camera.zoom, greaterThan(13.3));
    // The degrees up to the threshold are not applied: no jump when it joins.
    expect(controller.camera.rotation.abs(), inInclusiveRange(20, 30));
  });

  testWidgets('a pinch with a slight twist does not rotate the map',
      (tester) async {
    final controller = MapController();
    await tester.pumpWidget(_map(controller, joinsLate: true));
    await _pinchThenTurn(tester, 12);

    expect(controller.camera.zoom, greaterThan(13.3));
    expect(controller.camera.rotation, 0);
  });

  testWidgets('by default the winner keeps the gesture to itself',
      (tester) async {
    final controller = MapController();
    await tester.pumpWidget(_map(controller, joinsLate: false));
    await _pinchThenTurn(tester, 40);

    expect(controller.camera.zoom, greaterThan(13.3));
    expect(controller.camera.rotation, 0);
  });
}
