// test/queue_provider_geolocation_test.dart
//
// NOTE: On Windows, build_runner requires Developer Mode to generate symlinks.
// We use a hand-written mock instead of @GenerateMocks to avoid this dependency.
// The mock is functionally identical to what build_runner would generate.
//
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mockito/mockito.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:waiting_room_app/providers/queue_provider.dart';
import 'package:waiting_room_app/services/geolocation_service.dart';
import 'package:waiting_room_app/services/local_queue_service.dart';

// ── Hand-written mock (equivalent to @GenerateMocks([GeolocationService])) ──
class MockGeolocationService extends Mock implements GeolocationService {
  @override
  Future<Position?> getCurrentPosition() =>
      super.noSuchMethod(
        Invocation.method(#getCurrentPosition, []),
        returnValue: Future<Position?>.value(null),
        returnValueForMissingStub: Future<Position?>.value(null),
      ) as Future<Position?>;
}

void main() {
  setUpAll(() {
    // Use in-memory SQLite for fast, isolated tests (no disk I/O)
    databaseFactory = databaseFactoryFfi;
  });

  late MockGeolocationService mockGeo;
  late LocalQueueService localDb;
  late QueueProvider provider;

  setUp(() {
    mockGeo = MockGeolocationService();
    localDb = LocalQueueService(inMemory: true);
    provider = QueueProvider.withDependencies(
      supabaseClient: null, // No Supabase in unit tests
      geoService: mockGeo,
      localDb: localDb,
    );
  });

  tearDown(() async {
    provider.dispose();
    await localDb.close();
  });

  test('addClient saves client with geolocation when permission granted',
      () async {
    // Arrange: mock GPS returns real coordinates
    final mockPosition = Position(
      latitude: 37.7749,
      longitude: -122.4194,
      timestamp: DateTime.now(),
      accuracy: 5.0,
      altitude: 0.0,
      altitudeAccuracy: 0.0,
      heading: 0.0,
      headingAccuracy: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
    );
    when(mockGeo.getCurrentPosition()).thenAnswer((_) async => mockPosition);

    // Act
    await provider.addClient('Test User');

    // Assert: client has the correct coordinates
    expect(provider.clients.length, 1);
    expect(provider.clients.last.name, 'Test User');
    expect(provider.clients.last.lat, 37.7749);
    expect(provider.clients.last.lng, -122.4194);
  });

  test('addClient saves client with null location when permission denied',
      () async {
    // Arrange: mock returns null (denied or GPS unavailable)
    when(mockGeo.getCurrentPosition()).thenAnswer((_) async => null);

    // Act
    await provider.addClient('No Location User');

    // Assert: client is added but without coordinates
    expect(provider.clients.length, 1);
    expect(provider.clients.last.name, 'No Location User');
    expect(provider.clients.last.lat, isNull);
    expect(provider.clients.last.lng, isNull);
  });

  test('addClient rejects empty name', () async {
    final error = await provider.addClient('   ');

    expect(error, isNotNull);
    expect(error, 'Client name cannot be empty');
    expect(provider.clients.isEmpty, true);
  });

  test('addClient stores record locally with is_synced = 0', () async {
    // Arrange: no location
    when(mockGeo.getCurrentPosition()).thenAnswer((_) async => null);

    // Act
    await provider.addClient('Offline User');

    // Assert: stored locally as unsynced (Supabase is null → never synced)
    final unsynced = await localDb.getUnsyncedClients();
    expect(unsynced.length, 1);
    expect(unsynced[0]['name'], 'Offline User');
    expect(unsynced[0]['is_synced'], 0);
  });

  test('removeClient removes from local list', () async {
    when(mockGeo.getCurrentPosition()).thenAnswer((_) async => null);
    await provider.addClient('To Remove');

    expect(provider.clients.length, 1);
    final clientId = provider.clients.first.id;

    await provider.removeClient(clientId);

    expect(provider.clients.isEmpty, true);
  });

  test('nextClient removes first client in queue', () async {
    when(mockGeo.getCurrentPosition()).thenAnswer((_) async => null);
    await provider.addClient('First');
    await provider.addClient('Second');

    expect(provider.clients.length, 2);
    expect(provider.clients.first.name, 'First');

    await provider.nextClient();

    expect(provider.clients.length, 1);
    expect(provider.clients.first.name, 'Second');
  });
}
