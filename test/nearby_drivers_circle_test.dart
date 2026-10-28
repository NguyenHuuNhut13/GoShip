import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goship_app/core/theme/app_theme.dart';
import 'package:goship_app/core/widgets/app_interactive_map.dart';
import 'package:goship_app/features/customer/order/models/simulated_driver_model.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Nearby Drivers Radius Circle & Filter Tests', () {
    const pickupLocation = LatLng(10.7946, 106.7218); // Điểm nhận / lấy hàng

    // Driver 1: 180m away (inside 1000m radius)
    final driverInside = SimulatedDriver(
      id: 'drv_inside',
      name: 'Tài xế Trong Vòng',
      phone: '0901 111 222',
      plate: '59A 111.11',
      vehicleType: 'van',
      vehicleName: 'Xe Van 500kg',
      rating: 4.9,
      tripsCount: 100,
      avatarUrl: '',
      currentPosition: const LatLng(10.7960, 106.7210), // ~180m away
      headingDegrees: 45.0,
      addressHint: 'Nguyễn Hữu Cảnh',
      roadPath: const [LatLng(10.7960, 106.7210), LatLng(10.7970, 106.7210)],
      currentPathIndex: 0,
      pathProgress: 0.0,
      movingForward: true,
    );

    // Driver 2: 2800m away (outside 1000m radius)
    final driverOutside = SimulatedDriver(
      id: 'drv_outside',
      name: 'Tài xế Ngoài Vòng',
      phone: '0902 222 333',
      plate: '59B 222.22',
      vehicleType: 'truck_1000kg',
      vehicleName: 'Xe Tải 1 Tấn',
      rating: 4.8,
      tripsCount: 200,
      avatarUrl: '',
      currentPosition: const LatLng(10.8200, 106.7218), // ~2800m away
      headingDegrees: 90.0,
      addressHint: 'Khu vực xa',
      roadPath: const [LatLng(10.8200, 106.7218), LatLng(10.8210, 106.7218)],
      currentPathIndex: 0,
      pathProgress: 0.0,
      movingForward: true,
    );

    testWidgets('default mode hides CircleLayer and tag but renders all nearby drivers on map', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: AppInteractiveMap(
              points: [
                LocationPoint(
                  title: 'Điểm lấy hàng',
                  address: 'Tòa Landmark 81, Vinhomes Central Park',
                  latLng: pickupLocation,
                  isPickup: true,
                ),
              ],
              nearbyDrivers: [driverInside, driverOutside],
              nearbySearchRadiusMeters: 1000.0,
              isMiniMap: false,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Verify CircleLayer is HIDDEN by default
      expect(find.byType(CircleLayer), findsNothing);

      // 2. Verify radius tag badge is HIDDEN by default
      expect(find.text('Bán kính 1.0 km'), findsNothing);

      // 3. Verify bottom-left chip indicates total drivers in area
      expect(find.text('2 xe quanh khu vực'), findsOneWidget);
    });

    testWidgets('renders CircleLayer and filters when showNearbyRadiusCircle is true', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: AppInteractiveMap(
              points: [
                LocationPoint(
                  title: 'Điểm lấy hàng',
                  address: 'Tòa Landmark 81, Vinhomes Central Park',
                  latLng: pickupLocation,
                  isPickup: true,
                ),
              ],
              nearbyDrivers: [driverInside, driverOutside],
              nearbySearchRadiusMeters: 1000.0,
              showNearbyRadiusCircle: true,
              isMiniMap: false,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Verify CircleLayer is rendered on map
      final circleLayerFinder = find.byType(CircleLayer);
      expect(circleLayerFinder, findsOneWidget);

      // Verify CircleMarker properties
      final circleLayer = tester.widget<CircleLayer>(circleLayerFinder);
      expect(circleLayer.circles.isNotEmpty, isTrue);
      expect(circleLayer.circles.first.point, equals(pickupLocation));
      expect(circleLayer.circles.first.radius, equals(1000.0));
      expect(circleLayer.circles.first.useRadiusInMeter, isTrue);

      // 2. Verify only 1 driver inside the circle is counted in the bottom-left chip
      expect(find.textContaining('Bán kính 1.0km: 1 xe sẵn sàng'), findsOneWidget);

      // 3. Verify radius badge is rendered
      expect(find.text('Bán kính 1.0 km'), findsOneWidget);
    });

    testWidgets('circle adapts dynamically when custom search center is provided with showNearbyRadiusCircle: true', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const customCenter = LatLng(10.8200, 106.7218); // Near driverOutside

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: AppInteractiveMap(
              nearbySearchCenter: customCenter,
              nearbyDrivers: [driverInside, driverOutside],
              nearbySearchRadiusMeters: 800.0,
              showNearbyRadiusCircle: true,
              isMiniMap: false,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Circle centered at customCenter
      final circleLayer = tester.widget<CircleLayer>(find.byType(CircleLayer));
      expect(circleLayer.circles.first.point, equals(customCenter));
      expect(circleLayer.circles.first.radius, equals(800.0));

      // Now driverOutside is within 800m of customCenter, and driverInside is outside
      expect(find.textContaining('Bán kính 0.8km: 1 xe sẵn sàng'), findsOneWidget);
    });
  });
}
