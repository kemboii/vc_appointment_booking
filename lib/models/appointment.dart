class Appointment {
  final String id;
  final String date;
  final String slot;
  final String bookedBy;
  final String reason;

  Appointment({
    required this.id,
    required this.date,
    required this.slot,
    required this.bookedBy,
    required this.reason,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'slot': slot,
      'bookedBy': bookedBy,
      'reason': reason,
    };
  }

  factory Appointment.fromMap(String id, Map<String, dynamic> map) {
    return Appointment(
      id: id,
      date: map['date'] ?? '',
      slot: map['slot'] ?? '',
      bookedBy: map['bookedBy'] ?? '',
      reason: map['reason'] ?? '',
    );
  }
}