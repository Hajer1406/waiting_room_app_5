// lib/providers/queue_provider.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:waiting_room_app/models/client.dart';
import 'package:waiting_room_app/services/local_queue_service.dart';
import 'package:waiting_room_app/services/geolocation_service.dart';

class QueueProvider extends ChangeNotifier {
  // ── Dependencies (injectable for testing) ──────────────────────────────────
  final SupabaseClient? _supabase;
  final LocalQueueService _localDb;
  final GeolocationService _geoService;

  // ── State ──────────────────────────────────────────────────────────────────
  final List<Client> _clients = [];
  List<Client> get clients => List.unmodifiable(_clients);

  RealtimeChannel? _channel;
  bool _isDisposed = false; // Guard against notifyListeners() after dispose()
  Future<void>? _initFuture;

  // ── Constructors ───────────────────────────────────────────────────────────

  /// Default constructor for production use.
  /// GeolocationService and LocalQueueService can be injected for testing.
  QueueProvider({
    SupabaseClient? supabaseClient,
    GeolocationService? geoService,
    LocalQueueService? localDb,
  })  : _supabase = supabaseClient ?? _getSafeSupabaseClient(),
        _geoService = geoService ?? GeolocationService(),
        _localDb = localDb ?? LocalQueueService() {
    _initFuture = _initialize();
  }

  /// Testing constructor: accepts a real Supabase client (integration tests).
  QueueProvider.forTesting(SupabaseClient supabase)
      : _supabase = supabase,
        _geoService = GeolocationService(),
        _localDb = LocalQueueService() {
    _initFuture = _initialize();
  }

  /// Mock-friendly constructor for unit tests with full injection.
  QueueProvider.withDependencies({
    required SupabaseClient? supabaseClient,
    required GeolocationService geoService,
    required LocalQueueService localDb,
  })  : _supabase = supabaseClient,
        _geoService = geoService,
        _localDb = localDb {
    _initFuture = _initialize();
  }

  static SupabaseClient? _getSafeSupabaseClient() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  // ── Initialization ─────────────────────────────────────────────────────────

  Future<void> _initialize() async {
    // 1. Load local DB immediately → UI shows data even offline
    await _loadLocalQueue();

    // 2. Try to sync any pending records to Supabase
    unawaited(_syncLocalToRemote());

    // 3. Subscribe to Supabase real-time changes
    _setupRealtimeSubscription();
  }

  Future<void> _loadLocalQueue() async {
    if (_isDisposed) return; // Don't update state after disposal
    final rows = await _localDb.getClients();
    if (_isDisposed) return; // Check again after async gap
    _clients.clear();
    for (final row in rows) {
      _clients.add(Client.fromMap(row));
    }
    notifyListeners();
  }

  // ── Sync Logic ─────────────────────────────────────────────────────────────

  /// Uploads all unsynced local records to Supabase.
  /// Called on startup and after each addClient().
  Future<void> _syncLocalToRemote() async {
    final supabase = _supabase;
    if (supabase == null) return;

    final unsynced = await _localDb.getUnsyncedClients();
    for (final row in unsynced) {
      try {
        // Build the Supabase record (remove local-only fields)
        final remoteRecord = {
          'id': row['id'],
          'name': row['name'],
          'created_at': row['created_at'],
          if (row['lat'] != null) 'lat': row['lat'],
          if (row['lng'] != null) 'lng': row['lng'],
        };

        await supabase.from('clients').upsert(remoteRecord);
        await _localDb.markClientAsSynced(row['id'] as String);
        debugPrint('Synced client: ${row['name']}');
      } catch (e) {
        // Don't crash — continue syncing other items, retry next time
        debugPrint('Sync failed for ${row['id']}: $e');
      }
    }

    // Refresh UI to show updated sync status
    await _loadLocalQueue();
  }

  // ── Public Actions ─────────────────────────────────────────────────────────

  Future<String?> addClient(String name) async {
    if (_initFuture != null) await _initFuture;
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      debugPrint('Cannot add empty client name');
      return 'Client name cannot be empty';
    }

    // Get location (returns null if denied — that's OK)
    final position = await _geoService.getCurrentPosition();

    // Create the client record
    final newClient = Client(
      id: const Uuid().v4(),
      name: trimmed,
      createdAt: DateTime.now(),
      lat: position?.latitude,
      lng: position?.longitude,
      isSynced: false, // starts as local-only
    );

    // Save locally first (works offline)
    await _localDb.insertClientLocally({
      'id': newClient.id,
      'name': newClient.name,
      'lat': newClient.lat,
      'lng': newClient.lng,
      'created_at': newClient.createdAt.toIso8601String(),
      'is_synced': 0,
    });

    // Update UI immediately (don't wait for Supabase)
    _clients.add(newClient);
    _clients.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    notifyListeners();

    // Sync to Supabase in background (non-blocking — keeps UI responsive)
    unawaited(_syncLocalToRemote());

    return null; // null = success
  }

  Future<String?> removeClient(String id) async {
    if (_initFuture != null) await _initFuture;
    // 1. Remove from local UI immediately
    _clients.removeWhere((c) => c.id == id || c.name == id);
    notifyListeners();

    // 2. Remove from local DB
    await _localDb.deleteClient(id);

    // 3. Sync deletion to Supabase in background (non-blocking, offline-safe)
    final supabase = _supabase;
    if (supabase != null) {
      try {
        await supabase.from('clients').delete().eq('id', id);
        debugPrint('Client removed from Supabase: $id');
      } catch (e) {
        // Offline or network error: local removal succeeds regardless
        debugPrint('Remote delete failed (offline/network): $e');
      }
    }

    return null; // Local removal is always successful in offline-first
  }

  Future<String?> nextClient() async {
    if (_clients.isEmpty) {
      debugPrint('Queue is empty!');
      return 'Queue is empty';
    }
    final firstClient = _clients.first;
    final result = await removeClient(firstClient.id);
    debugPrint('Next client: ${firstClient.name}');
    return result;
  }

  // ── Real-time Subscription ─────────────────────────────────────────────────

  void _setupRealtimeSubscription() {
    final supabase = _supabase;
    if (supabase == null) return;

    _channel = supabase
        .channel('public:clients')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'clients',
          callback: (payload) {
            final record = payload.newRecord;
            if (record.isNotEmpty) {
              final newClient = Client.fromMap(record);
              if (!_clients.any((c) => c.id == newClient.id)) {
                _clients.add(newClient);
                _clients.sort((a, b) => a.createdAt.compareTo(b.createdAt));
                // Also persist in local DB as synced (came from Supabase)
                _localDb.insertClientLocally({
                  ...record,
                  'is_synced': 1,
                });
                notifyListeners();
              }
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'clients',
          callback: (payload) {
            final deletedId = payload.oldRecord['id'];
            if (deletedId != null) {
              _clients.removeWhere((c) => c.id == deletedId);
              _localDb.deleteClient(deletedId as String);
              notifyListeners();
            }
          },
        )
        .subscribe();
  }

  // ── Dispose ────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _isDisposed = true; // Set before super.dispose() to block any in-flight async calls
    final channel = _channel;
    final supabase = _supabase;
    if (channel != null && supabase != null) {
      supabase.removeChannel(channel);
    }
    super.dispose();
  }
}