// test/local_queue_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:waiting_room_app/services/local_queue_service.dart';

void main() {
  setUpAll(() {
    // Use in-memory SQLite engine for fast, isolated unit tests
    databaseFactory = databaseFactoryFfi;
  });

  // Each test gets its own fresh service instance (no shared state)
  late LocalQueueService service;

  setUp(() {
    service = LocalQueueService(inMemory: true);
  });

  tearDown(() async {
    await service.close();
  });

  test('insertClientLocally adds a record to the database', () async {
    await service.insertClientLocally({
      'id': 'test-123',
      'name': 'Alice',
      'lat': 40.71,
      'lng': -74.00,
      'created_at': '2024-01-01T00:00:00Z',
      'is_synced': 0,
    });

    final clients = await service.getUnsyncedClients();
    expect(clients.length, 1);
    expect(clients[0]['name'], 'Alice');
    expect(clients[0]['id'], 'test-123');
  });

  test('getUnsyncedClients returns only unsynced records', () async {
    // Insert one synced and one unsynced
    await service.insertClientLocally({
      'id': 'synced-1',
      'name': 'Bob',
      'lat': null,
      'lng': null,
      'created_at': '2024-01-01T01:00:00Z',
      'is_synced': 1, // already synced
    });
    await service.insertClientLocally({
      'id': 'unsynced-1',
      'name': 'Charlie',
      'lat': 48.85,
      'lng': 2.35,
      'created_at': '2024-01-01T02:00:00Z',
      'is_synced': 0, // not yet synced
    });

    final unsynced = await service.getUnsyncedClients();
    expect(unsynced.length, 1);
    expect(unsynced[0]['name'], 'Charlie');
  });

  test('markClientAsSynced updates is_synced flag to 1', () async {
    await service.insertClientLocally({
      'id': 'mark-test',
      'name': 'Diana',
      'lat': null,
      'lng': null,
      'created_at': '2024-01-01T03:00:00Z',
      'is_synced': 0,
    });

    await service.markClientAsSynced('mark-test');

    final unsynced = await service.getUnsyncedClients();
    expect(unsynced.isEmpty, true); // no more unsynced

    final all = await service.getClients();
    expect(all.length, 1);
    expect(all[0]['is_synced'], 1);
  });

  test('getClients returns all records ordered by created_at', () async {
    await service.insertClientLocally({
      'id': 'c2',
      'name': 'Second',
      'lat': null,
      'lng': null,
      'created_at': '2024-01-02T00:00:00Z',
      'is_synced': 0,
    });
    await service.insertClientLocally({
      'id': 'c1',
      'name': 'First',
      'lat': null,
      'lng': null,
      'created_at': '2024-01-01T00:00:00Z',
      'is_synced': 0,
    });

    final clients = await service.getClients();
    expect(clients.length, 2);
    expect(clients[0]['name'], 'First');  // oldest first
    expect(clients[1]['name'], 'Second');
  });
}
