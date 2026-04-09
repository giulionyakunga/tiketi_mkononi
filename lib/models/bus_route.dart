import 'package:tiketi_mkononi/models/bus.dart';
import 'package:tiketi_mkononi/models/company.dart';

class BusRoute {
  int id;
  int userId;
  int busId;
  String from;
  String to;
  final String departureDate;
  String departureTime;
  final String arrivalDate;
  String arrivalTime;
  double ticketPrice;
  double totalCollection;
  final String status;
  final Bus? bus;
  final Company? company;


  BusRoute({
    required this.id,
    required this.userId,
    required this.busId,
    required this.from,
    required this.to,
    required this.departureDate,
    required this.departureTime,
    required this.arrivalDate,
    required this.arrivalTime,
    required this.ticketPrice,
    required this.totalCollection,
    required this.status,
    required this.bus,
    required this.company,
  });

   // Factory method to create an BusRoute from JSON
  factory BusRoute.fromJson(Map<String, dynamic> json) {    
    return BusRoute(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      busId: json['bus_id'] ?? 0,
      from: json['from'] ?? '',
      to: json['to'] ?? '',
      departureDate: json['departure_date'] ?? '',
      departureTime: json['departure_time'] ?? '',
      arrivalDate: json['arrival_date'] ?? '',
      arrivalTime: json['arrival_time'] ?? '', 
      ticketPrice: (json['ticket_price'] ?? 0).toDouble(),
      totalCollection: (json['total_collection'] ?? 0).toDouble(),
      status: json['status'] ?? '',
      bus: json['bus'] != null ? Bus.fromJson(json['bus']) : null,
      company: json['company'] != null ? Company.fromJson(json['company']) : null,
    );
  }
}