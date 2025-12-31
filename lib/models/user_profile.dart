class UserProfile {
  final int id;
  final String firstName;
  final String middleName;
  final String lastName;
  final String email;
  final String phoneNumber;
  String role;
  final String region;
  final String district;
  final String ward;
  final String street;
  final String token;
  final String? imageUrl;

  UserProfile({
    required this.id,
    required this.firstName,
    required this.middleName,
    required this.lastName,
    required this.email,
    required this.phoneNumber,
    required this.role,
    required this.region,
    required this.district,
    required this.ward,
    required this.street,
    required this.token,
    this.imageUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'middleName': middleName,
      'lastName': lastName,
      'email': email,
      'phoneNumber': phoneNumber,
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
      firstName: json['firstName'] as String,
      middleName: json['middleName'] as String,
      lastName: json['lastName'] as String,
      email: json['email'] as String,
      phoneNumber: json['phoneNumber'] as String,
      role: json['role'] as String,
      region: json['region'] as String,
      district: json['district'] as String,
      ward: json['ward'] as String,
      street: json['street'] as String,
      token: json['token'] as String,
      imageUrl: json['imageUrl'] as String?,
    );
  }
}