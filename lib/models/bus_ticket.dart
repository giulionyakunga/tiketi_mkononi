class BusTicket {
  final int id;
  final int userId;
  final int busRouteId;
  final String pickupLocation;
  final String dropoffLocation;
  final String departureDate;
  final String departureTime;
  final double ticketPrice;
  final String paymentMethod;
  final String ticketCode;
  final String passengerName;
  final String seatNumber;
  final String phoneNumber;
  final String status;
  final String issuedBy;
  final String issuerPhoneNumber;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  BusTicket({
    required this.id,
    required this.userId,
    required this.busRouteId,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.departureDate,
    required this.departureTime, 
    required this.ticketPrice, 
    required this.paymentMethod,
    required this.ticketCode, 
    required this.passengerName,
    required this.seatNumber,
    required this.phoneNumber,
    required this.status,
    required this.issuedBy, 
    required this.issuerPhoneNumber,
    required this.createdAt,
    required this.updatedAt, 
  });

  // Factory method to create a BusTicket from JSON
  factory BusTicket.fromJson(Map<String, dynamic> json) {
    return BusTicket(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      busRouteId: json['bus_route_id'] ?? 0,
      pickupLocation: json['pickup_location'] ?? "N/A",
      dropoffLocation: json['dropoff_location'] ?? 'N/A',
      departureDate: json['departure_date'] ?? 'N/A',
      departureTime: json['departure_time'] ?? 'N/A',
      ticketPrice: (json['ticket_price'] ?? 0).toDouble(),
      paymentMethod: json['payment_method'] ?? "N/A",
      ticketCode: json['ticket_code'] ?? "N/A",
      seatNumber: json['seat_number'] ?? "N/A",
      passengerName: json['passenger_name'] ?? "N/A",
      phoneNumber: json['phone_number'] ?? "N/A",
      status: json['status'] ?? "N/A",
      issuedBy: json['issued_by'] ?? "N/A",
      issuerPhoneNumber: json['issuer_phone_number'] ?? "N/A",
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