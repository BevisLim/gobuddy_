import '../models/traveller.dart';

abstract interface class TravellerRepository {
  Future<List<Traveller>> getTravellersForTrip(int tripId);
  Future<Traveller?> getTravellerById(int userId);
}
