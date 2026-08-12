class Trip {
  const Trip({
    required this.tripId,
    required this.tripName,
    required this.destination,
    required this.startDate,
    required this.endDate,
  });

  final int tripId;
  final String tripName;
  final String destination;
  final DateTime startDate;
  final DateTime endDate;

  factory Trip.fromMap(Map<String, Object?> map) => Trip(
        tripId: map['trip_id']! as int,
        tripName: map['trip_name']! as String,
        destination: map['destination']! as String,
        startDate: DateTime.parse(map['start_date']! as String),
        endDate: DateTime.parse(map['end_date']! as String),
      );
}
