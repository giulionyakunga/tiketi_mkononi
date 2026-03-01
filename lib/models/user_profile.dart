class UserProfile {
  final int id;
  final int companyId;
  final int officeId;
  final int shopId;
  final String firstName;
  final String middleName;
  final String lastName;
  final String email;
  final String phoneNumber;
  final String password;
  String role;
  final String region;
  final String district;
  final String ward;
  final String street;
  final String token;
  final String? imageUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserProfile({
    required this.id,
    required this.companyId,
    required this.officeId,
    required this.shopId,
    required this.firstName,
    required this.middleName,
    required this.lastName,
    required this.email,
    required this.phoneNumber,
    required this.password,
    required this.role,
    required this.region,
    required this.district,
    required this.ward,
    required this.street,
    required this.token,
    this.imageUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company_id': companyId,
      'office_id': officeId,
      'shop_id': shopId,
      'firstName': firstName,
      'middleName': middleName,
      'lastName': lastName,
      'email': email,
      'phoneNumber': phoneNumber,
      'password': password,
      'role': role,
      'region': region,
      'district': district,
      'ward': ward,
      'street': street,
      'token': token,
      'imageUrl': imageUrl,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as int,
      companyId: (json['company_id'] ?? 0) as int,
      officeId: (json['office_id'] ?? 0) as int,
      shopId: (json['shop_id'] ?? 0) as int,
      firstName: json['firstName'] as String,
      middleName: json['middleName'] as String,
      lastName: json['lastName'] as String,
      email: json['email'] as String,
      phoneNumber: json['phoneNumber'] as String,
      password: json['password'] ?? '',
      role: json['role'] as String,
      region: json['region'] as String,
      district: json['district'] as String,
      ward: json['ward'] as String,
      street: json['street'] as String,
      token: json['token'] ?? '',
      imageUrl: json['imageUrl'] as String?,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  factory UserProfile.fromJson2(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as int,
      companyId: (json['company_id'] ?? 0) as int,
      officeId: (json['office_id'] ?? 0) as int,
      shopId: (json['shop_id'] ?? 0) as int,
      firstName: json['first_name'] as String,
      middleName: json['middle_name'] as String,
      lastName: json['last_name'] as String,
      email: json['email'] as String,
      phoneNumber: json['phone_number'] as String,
      password: json['password'] as String,
      role: json['role'] as String,
      region: json['region'] as String,
      district: json['district'] as String,
      ward: json['ward'] as String,
      street: json['street'] as String,
      token: json['token'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }
}