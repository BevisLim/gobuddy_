import 'package:sqflite/sqflite.dart';

import '../model/traveller.dart';
import 'traveller_repository.dart';

/// Development mirror only. Replace with the owning account/trip module.
class LocalTravellerRepository implements TravellerRepository {
  const LocalTravellerRepository(this.database);

  final Database database;

  @override
  Future<Traveller?> getTravellerById(int userId) async {
    final rows = await database.query(
      'travellers',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    return rows.isEmpty ? null : Traveller.fromMap(rows.first);
  }

  @override
  Future<List<Traveller>> getTravellersForTrip(int tripId) async {
    // Membership is supplied by the trip module later; all seeded travellers
    // belong to the one local development trip.
    final rows = await database.query('travellers', orderBy: 'user_id');
    return rows.map(Traveller.fromMap).toList(growable: false);
  }
}
