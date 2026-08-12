import 'package:sqflite/sqflite.dart';

import '../model/trip.dart';
import 'trip_repository.dart';

/// Development mirror only. Replace with the owning trip module.
class LocalTripRepository implements TripRepository {
  const LocalTripRepository(this.database);

  final Database database;

  @override
  Future<Trip?> getTripById(int tripId) async {
    final rows = await database.query(
      'trips',
      where: 'trip_id = ?',
      whereArgs: [tripId],
      limit: 1,
    );
    return rows.isEmpty ? null : Trip.fromMap(rows.first);
  }
}
