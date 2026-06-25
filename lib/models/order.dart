class OrderItem {
  final int id;
  String name;
  double price;
  int quantity;
  final DateTime createdAt;
  final DateTime updatedAt;

  OrderItem({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    required this.createdAt,
    required this.updatedAt,
  });

    // Factory method to create a Product from JSON
  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      quantity: json['quantity'] ?? 1,
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

class Order {
  final int id;
  String orderId;
  final int userId;
  final int shopId;
  String customerName;
  String customerPhoneNumber;
  double totalPrice;
  final bool paymentStatus;
  String issuedBy;
  String issuerPhoneNumber;
  String status;
  final List<OrderItem> orderItems;
  final String date;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  Order({
    required this.id,
    required this.orderId,
    required this.userId,
    required this.shopId,
    required this.customerName,
    required this.customerPhoneNumber,
    required this.totalPrice,
    required this.paymentStatus,
    required this.issuedBy,
    required this.issuerPhoneNumber,
    required this.status,
    required this.orderItems,
    required this.date,
    required this.createdAt,
    required this.updatedAt,
  });

  // Factory method to create an Order from JSON
  factory Order.fromJson(Map<String, dynamic> json) {    
    return Order(
      id: json['id'] ?? 0,
      orderId: json['order_id'] ?? '',
      userId: json['user_id'] ?? 0,
      shopId: json['shop_id'] ?? 0,
      customerName: json['customer_name'] ?? '',
      customerPhoneNumber: json['customer_phone_number'] ?? '',
      totalPrice: (json['total_price'] ?? 0).toDouble(),
      paymentStatus: json['payment_status'] ?? false,
      issuedBy: json['issued_by'] ?? '',
      issuerPhoneNumber: json['issuer_phone_number'] ?? '',
      status: json['status'] ?? '',
      orderItems: (json['order_items'] as List<dynamic>?)
              ?.map((ticket) => OrderItem.fromJson(ticket))
              .toList() ??
          [], // Handle case when order_items is null
      date: json['date'] ?? '',
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
