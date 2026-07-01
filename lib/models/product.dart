class Product {
  final int id;
  final int shopId;
  final String name;
  final String brand;
  final String unit;
  final double price;
  final int quantity;
  final DateTime createdAt;
  final DateTime updatedAt;

  Product({
    required this.id,
    required this.shopId,
    required this.name,
    required this.brand,
    required this.unit,
    required this.price,
    required this.quantity,
    required this.createdAt,
    required this.updatedAt,
  });

  // Factory method to create a Product from JSON
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] ?? 0,
      shopId: json['shop_id'] ?? 0,
      name: json['name'] ?? '',
      brand: json['brand'] ?? '',
      unit: json['unit'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      quantity: json['quantity'] ?? 0,
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