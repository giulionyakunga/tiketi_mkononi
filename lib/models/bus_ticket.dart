class BusTicket {
  final int id;
  final int busRouteId;
  final String passengerName;
  final String paymentMethod;
  final String seatNumber;
  final String passengerPhoneNumber;
  final String pickupLocations;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  BusTicket({
    required this.id,
    required this.busRouteId,
    required this.passengerName,
    required this.paymentMethod,
    required this.seatNumber,
    required this.passengerPhoneNumber,
    required this.pickupLocations,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  // Factory method to create a BusTicket from JSON
  factory BusTicket.fromJson(Map<String, dynamic> json) {
    return BusTicket(
      id: json['id'] ?? 0,
      busRouteId: json['bus_route_id'] ?? 0,
      passengerName: json['passenger_name'] ?? "N/A",
      seatNumber: json['seat_number'] ?? "N/A",
      passengerPhoneNumber: json['passenger_phone_number'] ?? "N/A",
      pickupLocations: json['pickup_locations'] ?? "N/A",
      paymentMethod: json['payment_method'] ?? "N/A",
      status: json['status'] ?? "N/A",
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return DateTime.now();
    }
    return DateTime.parse(value.toString());
  }
  
}