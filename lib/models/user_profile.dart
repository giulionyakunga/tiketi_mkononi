class UserProfile {
  final int id;
  int companyId;
  String companyName;
  final int officeId;
  int shopId;
  int paidSms;
  String shopName;
  final String firstName;
  final String middleName;
  final String lastName;
  final String email;
  final String phoneNumber;
  final String tin;
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
    required this.companyName,
    required this.officeId,
    required this.shopId,
    required this.shopName,
    required this.paidSms,
    required this.firstName,
    required this.middleName,
    required this.lastName,
    required this.email,
    required this.phoneNumber,
    required this.tin,
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

  // ── Safe coercion helpers ─────────────────────────────
  static String _s(dynamic v, [String fallback = '']) =>
      v == null ? fallback : v.toString();

  static int _i(dynamic v, [int fallback = 0]) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? fallback;
  }

  static DateTime? _d(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company_id': companyId,
      'companyName': companyName,
      'office_id': officeId,
      'shop_id': shopId,
      'shopName': shopName,
      'paid_sms': paidSms,
      'firstName': firstName,
      'middleName': middleName,
      'lastName': lastName,
      'email': email,
      'phoneNumber': phoneNumber,
      'tin': tin,
      'password': password,
      'role': role,
      'region': region,
      'district': district,
      'ward': ward,
      'street': street,
      'token': token,
      'imageUrl': imageUrl,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// Handles the *camelCase* shape produced by [toJson] / local storage.
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: _i(json['id']),
      companyId: _i(json['company_id'] ?? json['companyId']),
      companyName: _s(json['companyName'] ?? json['company_name']),
      officeId: _i(json['office_id'] ?? json['officeId']),
      shopId: _i(json['shop_id'] ?? json['shopId']),
      shopName: _s(json['shop_name'] ?? json['shopName']),
      paidSms: _i(json['paid_sms'] ?? json['paidSms']),
      firstName: _s(json['firstName'] ?? json['first_name']),
      middleName: _s(json['middleName'] ?? json['middle_name']),
      lastName: _s(json['lastName'] ?? json['last_name']),
      email: _s(json['email']),
      phoneNumber: _s(json['phoneNumber'] ?? json['phone_number']),
      tin: _s(json['tin']),
      password: _s(json['password']),
      role: _s(json['role']),
      region: _s(json['region']),
      district: _s(json['district']),
      ward: _s(json['ward']),
      street: _s(json['street']),
      token: _s(json['token']),
      imageUrl: json['imageUrl'] != null ? _s(json['imageUrl']) : null,
      createdAt: _d(json['createdAt'] ?? json['created_at']),
      updatedAt: _d(json['updatedAt'] ?? json['updated_at']),
    );
  }

  /// Handles the *snake_case* shape returned by your API login/profile endpoint.
  factory UserProfile.fromJson2(Map<String, dynamic> json) {
    return UserProfile(
      id: _i(json['id']),
      companyId: _i(json['company_id']),
      companyName: _s(json['company_name']),
      officeId: _i(json['office_id']),
      shopId: _i(json['shop_id']),
      shopName: _s(json['shop_name']),
      paidSms: _i(json['paid_sms']),
      firstName: _s(json['first_name']),
      middleName: _s(json['middle_name']),
      lastName: _s(json['last_name']),
      email: _s(json['email']),
      phoneNumber: _s(json['phone_number']),
      tin: _s(json['tin']),                        // ← null-safe now
      password: _s(json['password']),
      role: _s(json['role']),
      region: _s(json['region']),
      district: _s(json['district']),
      ward: _s(json['ward']),
      street: _s(json['street']),
      token: _s(json['token']),
      imageUrl: json['image_url'] != null ? _s(json['image_url']) : null,
      createdAt: _d(json['createdAt'] ?? json['created_at']),
      updatedAt: _d(json['updatedAt'] ?? json['updated_at']),
    );
  }
}