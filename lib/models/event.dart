class TicketType {
  final int id;
  final int userId;
  final int eventId;
  final String name;
  final double price;
  final int numberOfTickets;
  final int soldTickets;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isCustom;


  TicketType({
    required this.id,
    required this.userId,
    required this.eventId,
    required this.name,
    required this.price,
    required this.numberOfTickets,
    required this.isCustom,
    required this.soldTickets,
    required this.createdAt,
    required this.updatedAt,
  });

  // Factory method to create a TicketType from JSON
  factory TicketType.fromJson(Map<String, dynamic> json) {
    return TicketType(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      eventId: json['event_id'] ?? 0,
      name: json['name'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      numberOfTickets: (json['number_of_tickets'] ?? 0).toInt(),
      soldTickets: (json['sold_tickets'] ?? 0).toInt(),
      isCustom: json['is_custom'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }
}

class Event {
  final int id;
  final int userId;
  final String name;
  final String date;
  final String time;
  final String venue;
  final String imageUrl;
  final String category;
  final String type;
  final String description;
  final int soldTickets;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<TicketType> ticketTypes;
  final bool hasTicket;

  Event({
    required this.id,
    required this.userId,
    required this.name,
    required this.date,
    required this.time,
    required this.venue,
    required this.imageUrl,
    required this.category,
    required this.type,
    required this.description,
    required this.soldTickets,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.ticketTypes,
    required this.hasTicket,
  });

  // Factory method to create an Event from JSON
  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      name: json['name'] ?? '',
      date: json['date'] ?? '',
      time: json['time'] ?? '',
      venue: json['venue'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      category: json['category'] ?? '',
      type: json['type'] ?? '',
      description: json['description'] ?? '',
      soldTickets: json['soldTickets'] ?? 0,
      status: json['status'] ?? '',
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      ticketTypes: (json['ticket_types'] as List<dynamic>?)
              ?.map((ticket) => TicketType.fromJson(ticket))
              .toList() ??
          [], // Handle case when ticket_types is null
      hasTicket: json['has_ticket'] ?? '',
    );
  }
}
