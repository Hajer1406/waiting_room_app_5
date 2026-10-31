class Client {
  final String id;
  final String name;
  final DateTime createdAt;
  final double? lat;   // Latitude (null if location not captured)
  final double? lng;   // Longitude (null if location not captured)
  final bool isSynced; // true = saved to Supabase, false = local only

  Client({
    required this.id,
    required this.name,
    required this.createdAt,
    this.lat,
    this.lng,
    this.isSynced = true, // Remote clients are always considered synced
  });

  factory Client.fromMap(Map<String, dynamic> map) {
    return Client(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'].toString())
          : DateTime.now(),
      lat: map['lat'] != null ? (map['lat'] as num).toDouble() : null,
      lng: map['lng'] != null ? (map['lng'] as num).toDouble() : null,
      isSynced: map['is_synced'] == 1 || map['is_synced'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.toIso8601String(),
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
    };
  }

  @override
  String toString() =>
      'Client(id: $id, name: $name, lat: $lat, lng: $lng, synced: $isSynced)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Client &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}