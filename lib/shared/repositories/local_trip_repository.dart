import '../../core/database/app_database.dart';
import '../models/trip.dart';
import 'trip_repository.dart';

/// Development mirror only. The shared trip module will replace this.
class LocalTripRepository implements TripRepository {
  const LocalTripRepository(this._database);
  final AppDatabase _database;
  @override
  Future<Trip?> getTripById(int tripId) async {
    final db = await _database.database;
    final rows = await db.query('trips',
        where: 'trip_id = ?', whereArgs: [tripId], limit: 1);
    return rows.isEmpty ? null : Trip.fromMap(rows.first);
  }
}
