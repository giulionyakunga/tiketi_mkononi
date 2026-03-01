
class AccountRecord {
  final int id;
  final int userId;
  final String itemName;
  final String date;
  final String time;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final String paymentMethod;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  AccountRecord({
    required this.id,
    required this.userId,
    required this.itemName,
    required this.date,
    required this.time,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    required this.paymentMethod,
    required this.createdAt,
    required this.updatedAt,
  });

  // Factory method to create an AccountRecord from JSON
  factory AccountRecord.fromJson(Map<String, dynamic> json) {    
    return AccountRecord(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      itemName: json['item_name'] ?? '',
      date: json['date'] ?? '',
      time: json['time'] ?? '',
      quantity: json['quantity'] ?? 0,
      unitPrice: (json['unit_price'] ?? 0).toDouble(),
      totalPrice: (json['total_price'] ?? 0).toDouble(),
      paymentMethod: json['payment_method'] ?? '',
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }
}