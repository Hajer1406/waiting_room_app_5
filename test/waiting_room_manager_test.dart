import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:waiting_room_app/providers/queue_provider.dart';
import 'package:waiting_room_app/services/geolocation_service.dart';
import 'package:waiting_room_app/services/local_queue_service.dart';

class _FakeGeoService extends GeolocationService {
  @override
  Future<Position?> getCurrentPosition() async => null;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late LocalQueueService localDb;
  late QueueProvider manager;

  setUp(() {
    localDb = LocalQueueService(inMemory: true);
    manager = QueueProvider(
      geoService: _FakeGeoService(),
      localDb: localDb,
    );
  });

  tearDown(() async {
    manager.dispose();
    await localDb.close();
  });

  test('should add a client to the waiting list', () async {
    await manager.addClient('John Doe');

    expect(manager.clients.length, 1);
    expect(manager.clients.first.name, 'John Doe');
  });

  test('should remove a client from the waiting list', () async {
    await manager.addClient('John Doe');
    await manager.addClient('Jane Doe');

    await manager.removeClient('John Doe');

    expect(manager.clients.length, 1);
    expect(manager.clients.first.name, 'Jane Doe');
  });

  test('should remove the first client when nextClient() is called', () async {
    await manager.addClient('Client A');
    await manager.addClient('Client B');

    await manager.nextClient();

    expect(manager.clients.length, 1);
    expect(manager.clients.first.name, 'Client B');
  });
}
