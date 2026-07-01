import 'package:tiketi_mkononi/models/Order.dart';
import 'package:tiketi_mkononi/models/user_profile.dart';

class Shop {
  final int id;
  final int userId;
  final String name;
  final String location;
  final int productCount;
  final int orderCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  Shop({
    required this.id,
    required this.userId,
    required this.name,
    required this.location,
    required this.createdAt,
    required this.updatedAt,
    required this.productCount,
    required this.orderCount,
  });

  factory Shop.fromJson(Map<String, dynamic> json) {
    return Shop(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      name: json['name'] ?? '',
      location: json['location'] ?? '',
      productCount: json['product_count'] ?? 0,
      orderCount: json['order_count'] ?? 0,
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