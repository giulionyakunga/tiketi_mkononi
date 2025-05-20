class Ticket {
  final int id;
  final int userId;
  final String userName;
  final int eventId;
  final String eventName;
  final String date;
  final String time;
  final String venue;
  final String ticketType;
  final double price;
  final int numberOfTickets;
  final String status;
  final String transactionId;
  final int scanStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  Ticket({
    required this.id,
    required this.userId,
    required this.userName,
    required this.eventId,
    required this.eventName,
    required this.date,
    required this.time,
    required this.venue,
    required this.ticketType,
    required this.price,
    required this.numberOfTickets,
    required this.status,
    required this.transactionId,
    required this.scanStatus,
    required this.createdAt,
    required this.updatedAt,
  });

  // Factory method to create a Ticket from JSON
  factory Ticket.fromJson(Map<String, dynamic> json) {
    return Ticket(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      userName: json['user_name'] ?? 0,
      eventId: json['event_id'] ?? 0,
      eventName: json['event_name'] ?? '',
      date: json['date'] ?? '',
      time: json['time'] ?? '',
      venue: json['venue'] ?? '',
      ticketType: json['ticket_type'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      numberOfTickets: (json['number_of_tickets'] ?? 0).toInt(),
      status: json['status'] ?? '',
      transactionId: json['transaction_id'] ?? '',
      scanStatus: (json['scan_status'] ?? 0).toInt(),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  DateTime get combinedDateTime {
    final dateParts = date.split('-');
    final timeParts = time.split(':');
    
    return DateTime(
      int.parse(dateParts[2]), // year
      int.parse(dateParts[1]), // month
      int.parse(dateParts[0]), // day
      (int.parse(timeParts[0]) + 6), // hour // make the ticket a past ticket after 5 hours
      int.parse(timeParts[1]), // minute
    );
  }
  
}