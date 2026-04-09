class Company {
  int id;
  int userId;
  String name;


  Company({
    required this.id,
    required this.userId,
    required this.name,
  });

  // Factory method to create an Company from JSON
  factory Company.fromJson(Map<String, dynamic> json) {    
    return Company(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      name: json['name'] ?? '',
    );
  }
}