class TicketType {
  final int id;
  final int userId;
  final int eventId;
  final String name;
  final double price;
  final int numberOfTickets;
  final String ticketInformation;
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
    required this.ticketInformation,
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
      ticketInformation: json['ticket_information'] ?? '',
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
  final int venueId;
  final String locationLink;
  final String organizerPhoneNumber;
  final String imageUrl;
  final String cardUrl;
  final String category;
  final String type;
  final String visibility;
  final String daily_event;
  final String description;
  final int soldTickets;
  final String status;
  final int ticketScannerId;
  final double qrOffsetDx;
  final double qrOffsetDy;
  final double textOffsetDx;
  final double textOffsetDy;
  final double qrSize;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<TicketType> ticketTypes;
  final List<dynamic> tickets;
  final bool hasTicket;
  final String familyName;
  final String networkNameAccountNumber1;
  final String networkNameAccountNumber2;
  final String networkNameAccountNumber3;
  final String accountName;
  final String accountName2;
  final String accountName3;
  final String language;
  
  Event({
    required this.id,
    required this.userId,
    required this.name,
    required this.date,
    required this.time,
    required this.venue,
    required this.venueId,
    required this.locationLink,
    required this.organizerPhoneNumber,
    required this.imageUrl,
    required this.cardUrl,
    required this.category,
    required this.type,
    required this.visibility,
    required this.daily_event,
    required this.description,
    required this.soldTickets,
    required this.status,
    required this.ticketScannerId,
    required this.qrOffsetDx,
    required this.qrOffsetDy,
    required this.textOffsetDx,
    required this.textOffsetDy,
    required this.qrSize,
    required this.createdAt,
    required this.updatedAt,
    required this.ticketTypes,
    required this.tickets,
    required this.hasTicket,
    required this.familyName,
    required this.networkNameAccountNumber1,
    required this.networkNameAccountNumber2,
    required this.networkNameAccountNumber3,
    required this.accountName,
    required this.accountName2,
    required this.accountName3,
    required this.language,
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
      venueId: json['venue_id'] ?? 0,
      locationLink: json['location_link'] ?? '',
      organizerPhoneNumber: json['organizer_phone_number'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      cardUrl: json['card_url'] ?? '',
      category: json['category'] ?? '',
      type: json['type'] ?? '',
      visibility: json['visibility'] ?? '',
      daily_event: json['daily_event'] ?? '',
      description: json['description'] ?? '',
      soldTickets: json['ticket_count'] ?? 0,
      status: json['status'] ?? '',
      ticketScannerId: json['ticket_scanner_id'] ?? 0,
      qrOffsetDx: (json['qr_offset_dx'] ?? 0.1).toDouble(),
      qrOffsetDy: (json['qr_offset_dy'] ?? 0.1).toDouble(),
      textOffsetDx: (json['text_offset_dx'] ?? 0.1).toDouble(),
      textOffsetDy: (json['text_offset_dy'] ?? 0.1).toDouble(),
      qrSize: (json['qr_size'] ?? 0.1).toDouble(),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      ticketTypes: (json['ticket_types'] as List<dynamic>?)
              ?.map((ticket) => TicketType.fromJson(ticket))
              .toList() ??
          [], // Handle case when ticket_types is null
      tickets: (json['tickets'] as List<dynamic>?) ?? [], 
      hasTicket: json['has_ticket'] ?? false,
      familyName: json['family_name'] ?? '',
      networkNameAccountNumber1: json['network_name_account_number_1'] ?? '',
      networkNameAccountNumber2: json['network_name_account_number_2'] ?? '',
      networkNameAccountNumber3: json['network_name_account_number_3'] ?? '',
      accountName: json['account_name'] ?? '',
      accountName2: json['account_name_2'] ?? '',
      accountName3: json['account_name_3'] ?? '',
      language: json['language'] ?? 'sw',
    );
  }
}
