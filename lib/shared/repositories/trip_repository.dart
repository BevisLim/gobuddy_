import '../models/trip.dart';

abstract interface class TripRepository {
  Future<Trip?> getTripById(int tripId);
}
