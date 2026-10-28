import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:goship_app/core/services/driver_simulation_service.dart';

void main() {
  group('DriverSimulationService Tests', () {
    test('calculateBearing calculates directional compass degrees correctly', () {
      // Due North
      final northBearing = DriverSimulationService.calculateBearing(
        const LatLng(10.0, 106.0),
        const LatLng(11.0, 106.0),
      );
      expect(northBearing, closeTo(0.0, 1.0));

      // Due East
      final eastBearing = DriverSimulationService.calculateBearing(
        const LatLng(10.0, 106.0),
        const LatLng(10.0, 107.0),
      );
      expect(eastBearing, closeTo(90.0, 1.5));

      // Due South
      final southBearing = DriverSimulationService.calculateBearing(
        const LatLng(11.0, 106.0),
        const LatLng(10.0, 106.0),
      );
      expect(southBearing, closeTo(180.0, 1.0));

      // Due West
      final westBearing = DriverSimulationService.calculateBearing(
        const LatLng(10.0, 107.0),
        const LatLng(10.0, 106.0),
      );
      expect(westBearing, closeTo(270.0, 1.5));
    });

    test('generateNearbyDrivers produces valid simulated drivers around center', () {
      const center = LatLng(10.7725, 106.6980);
      final drivers = DriverSimulationService.generateNearbyDrivers(center, count: 5);

      expect(drivers.length, 5);
      const distanceCalc = Distance();
      const allowedVehicleTypes = {'van', 'pickup', 'truck_1000kg', 'truck_1500kg'};

      for (final driver in drivers) {
        expect(driver.id, isNotEmpty);
        expect(driver.name, isNotEmpty);
        expect(driver.phone, isNotEmpty);
        expect(driver.plate, isNotEmpty);
        expect(driver.rating, greaterThanOrEqualTo(4.5));
        expect(driver.headingDegrees, greaterThanOrEqualTo(0.0));
        expect(driver.headingDegrees, lessThan(360.0));
        expect(driver.addressHint, isNotEmpty);

        // Verify strictly truck fleet (no motorbikes)
        expect(allowedVehicleTypes.contains(driver.vehicleType), isTrue);
        expect(driver.vehicleType, isNot('bike'));

        final distMeters = distanceCalc.as(LengthUnit.Meter, center, driver.currentPosition);
        expect(distMeters, lessThan(3000));
        expect(distMeters, greaterThan(100));
      }
    });

    test('generateNearbyDrivers around Landmark 81 stays inland (no vehicles in Saigon River)', () {
      // Landmark 81 coordinate: Saigon River is directly to the East (longitude > 106.7218)
      const landmark81 = LatLng(10.7946, 106.7218);
      final drivers = DriverSimulationService.generateNearbyDrivers(landmark81, count: 5);

      for (final driver in drivers) {
        // All road offsets are westward/inland (longitude <= 106.7218), NEVER east into the river!
        expect(driver.currentPosition.longitude, lessThanOrEqualTo(landmark81.longitude));
        expect(driver.addressHint, isNotEmpty);
      }
    });

    test('LiveTrackingEngine jumpToEnd completes simulation accurately', () {
      final route = [
        const LatLng(10.7725, 106.6980),
        const LatLng(10.7780, 106.7020),
        const LatLng(10.7850, 106.7100),
      ];

      bool isCompleted = false;
      LatLng? finalPosition;

      final engine = LiveTrackingEngine(
        routePoints: route,
        onUpdate: (pos, heading, traveled, remaining, remKm, remMins, progress) {
          finalPosition = pos;
        },
        onCompleted: () {
          isCompleted = true;
        },
      );

      engine.jumpToEnd();
      expect(isCompleted, isTrue);
      expect(finalPosition?.latitude, closeTo(10.7850, 0.0001));
      expect(finalPosition?.longitude, closeTo(106.7100, 0.0001));

      engine.dispose();
    });
  });
}
