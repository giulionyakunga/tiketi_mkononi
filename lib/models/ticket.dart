import 'package:flutter/foundation.dart';

class Ticket {
  final int id;
  final int userId;
  final String ticketCode;
  final String userName;
  final String userEmail;
  final String userPhoneNumber;
  final int eventId;
  final String eventName;
  final String date;
  final String time;
  final String venue;
  final String locationLink;
  final String ticketType;
  final double price;
  final int numberOfTickets;
  final String status;
  final String transactionId;
  final String seatNumber;
  final int scanStatus;
  final int scanTimes;
  final int maxScanTimes;
  final bool hasLeft;
  final int confirmStatus;
  final DateTime scannedAt;
  final bool smsSent;
  final bool whatsappSent;
  final DateTime createdAt;
  final DateTime updatedAt;

  Ticket({
    required this.id,
    required this.userId,
    required this.ticketCode,
    required this.userName,
    required this.userEmail,
    required this.userPhoneNumber,
    required this.eventId,
    required this.eventName,
    required this.date,
    required this.time,
    required this.venue,
    required this.locationLink,
    required this.ticketType,
    required this.price,
    required this.numberOfTickets,
    required this.status,
    required this.transactionId,
    required this.seatNumber,
    required this.scanStatus,
    required this.scanTimes,
    required this.maxScanTimes,
    required this.hasLeft,
    required this.confirmStatus,
    required this.scannedAt,
    required this.smsSent,
    required this.whatsappSent,
    required this.createdAt,
    required this.updatedAt,
  });

  // Factory method to create a Ticket from JSON
  factory Ticket.fromJson(Map<String, dynamic> json) {
    return Ticket(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      ticketCode: json['ticket_code'] ?? "",
      userName: json['user_name'] ?? "N/A",
      userEmail: json['user_email'] ?? "N/A",
      userPhoneNumber: json['user_phone_number'] ?? "N/A",
      eventId: json['event_id'] ?? 0,
      eventName: json['event_name'] ?? '',
      date: json['date'] ?? '',
      time: json['time'] ?? '',
      venue: json['venue'] ?? '',
      locationLink: json['location_link'] ?? '',
      ticketType: json['ticket_type'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      numberOfTickets: (json['number_of_tickets'] ?? 0).toInt(),
      status: json['status'] ?? '',
      transactionId: json['transaction_id'] ?? '',
      seatNumber: json['seat_number'] ?? '',
      scanStatus: (json['scan_status'] ?? 0).toInt(),
      scanTimes: (json['scan_times'] ?? 0).toInt(),
      maxScanTimes: (json['max_scan_times'] ?? 0).toInt(),
      hasLeft: json['has_left'] ?? false,
      confirmStatus: (json['confirm_status'] ?? 0).toInt(),
      scannedAt: _parseDate(json['scannedAt']),
      smsSent: json['sms_sent'] ?? false,
      whatsappSent: json['whatsapp_sent'] ?? false,
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }

  DateTime get combinedDateTime {
    final dateParts = date.split('-');
    final timeParts = time.split(':');
    
    return DateTime(
      int.parse(dateParts[2]), // year
      int.parse(dateParts[1]), // month
      int.parse(dateParts[0]), // day
      (int.parse(timeParts[0]) + 12), // hour // make the ticket a past ticket after 12 hours
      int.parse(timeParts[1]), // minute
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return DateTime.now();
    }
    return DateTime.parse(value.toString());
  }
  
}