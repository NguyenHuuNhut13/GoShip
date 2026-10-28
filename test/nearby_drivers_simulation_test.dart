import 'package:flutter_test/flutter_test.dart';
import 'package:goship_app/core/services/driver_simulation_service.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('Nearby Drivers Road Simulation Tests', () {
    const center = LatLng(10.7946, 106.7218); // Landmark 81
    const hoVanThanhCenter = LatLng(10.7968, 106.7183); // Văn Thánh Lake

    test('generates nearby drivers with non-empty roadPath and valid heading', () {
      final drivers = DriverSimulationService.generateNearbyDrivers(center, count: 5);

      expect(drivers.length, 5);
      for (final driver in drivers) {
        expect(driver.roadPath.length, greaterThanOrEqualTo(2));
        expect(driver.currentPosition.latitude, inInclusiveRange(10.78, 10.82));
        expect(driver.currentPosition.longitude, inInclusiveRange(106.70, 106.73));
        expect(driver.headingDegrees, inInclusiveRange(0.0, 360.0));
      }
    });

    test('drivers are strictly NEVER positioned inside Hồ Văn Thánh body of water', () {
      final drivers = DriverSimulationService.generateNearbyDrivers(center, count: 5);
      const distanceCalc = Distance();

      for (final driver in drivers) {
        // Hồ Văn Thánh radius is ~60m. The old buggy offset was ~10m from lake center.
        // With our real road corridors (Điện Biên Phủ, Nguyễn Hữu Cảnh, D1, D2, Ung Văn Khiêm),
        // drivers must be on the roadways, at least 80m away from the water center.
        final distToLakeCenter = distanceCalc.as(
          LengthUnit.Meter,
          driver.currentPosition,
          hoVanThanhCenter,
        );
        expect(distToLakeCenter, greaterThan(80.0),
            reason: '${driver.name} is too close to or inside Hồ Văn Thánh: ${driver.currentPosition}');
      }
    });

    test('stepNearbyDrivers advances driver coordinates and preserves road path continuity with 5s refresh', () {
      final drivers = DriverSimulationService.generateNearbyDrivers(center, count: 5);
      final initialPos = drivers.first.currentPosition;

      // Step forward 5.0 seconds as configured
      final movedDrivers = DriverSimulationService.stepNearbyDrivers(drivers, deltaSeconds: 5.0);
      final newPos = movedDrivers.first.currentPosition;

      // Ensure position changed forward
      expect(newPos.latitude != initialPos.latitude || newPos.longitude != initialPos.longitude, isTrue);

      // Ensure heading is valid degrees
      expect(movedDrivers.first.headingDegrees, inInclusiveRange(0.0, 360.0));
    });

    test('drivers roam surrounding streets strictly outside the predefined delivery route line', () {
      final mockRoute = List.generate(
        30,
        (i) => LatLng(10.7900 + i * 0.001, 106.7100 + i * 0.001),
      );

      final drivers = DriverSimulationService.generateNearbyDrivers(
        center,
        routePoints: mockRoute,
        count: 5,
      );

      expect(drivers.length, 5);
      for (final d in drivers) {
        // Drivers roam neighborhood streets outside the blue delivery route
        expect(mockRoute.contains(d.currentPosition), isFalse);
      }
    });
  });
}
