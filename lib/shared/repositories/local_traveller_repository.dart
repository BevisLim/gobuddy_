import '../../core/database/app_database.dart';
import '../models/traveller.dart';
import 'traveller_repository.dart';

/// Development mirror only. A trip-membership repository will replace this.
class LocalTravellerRepository implements TravellerRepository {
  const LocalTravellerRepository(this._database);
  final AppDatabase _database;

  @override
  Future<Traveller?> getTravellerById(int userId) async {
    final db = await _database.database;
    final rows = await db.query('travellers',
        where: 'user_id = ?', whereArgs: [userId], limit: 1);
    return rows.isEmpty ? null : Traveller.fromMap(rows.first);
  }

  @override
  Future<List<Traveller>> getTravellersForTrip(int tripId) async {
    final db = await _database.database;
    final rows = await db.query('travellers', orderBy: 'user_id');
    return rows.map(Traveller.fromMap).toList(growable: false);
  }
}
