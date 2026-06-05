class Pledge {
  final int id;
  final int eventId;
  final String fullName;
  final String phoneNumber;
  final double amount;
  final DateTime createdAt;
  final DateTime updatedAt;

  Pledge({
    required this.id,
    required this.eventId,
    required this.fullName,
    required this.phoneNumber,
    required this.amount,
    required this.createdAt,
    required this.updatedAt,
  });

  // Factory method to create a Pledge from JSON
  factory Pledge.fromJson(Map<String, dynamic> json) {
    return Pledge(
      id: json['id'] ?? 0,
      eventId: json['event_id'] ?? 0,
      fullName: json['name'] ?? "N/A",
      phoneNumber: json['phone_number'] ?? "N/A",
      amount: (json['amount'] ?? 0).toDouble(),
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return DateTime.now();
    }
    return DateTime.parse(value.toString());
  }
}