import 'package:http/http.dart' as http;
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/models/user_profile.dart';


class ApiService {

  Future<String> updateUserProfile(UserProfile profile, String password, String? imagePath) async {
    try {

      // If all validations pass, proceed with registration
      String url = '${backend_url}api/update_user';
      final response = await http.post(
        Uri.parse(url),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: '{"user_id": "${profile.id}", "first_name": "${profile.firstName}", "middle_name": "${profile.middleName}", "last_name": "${profile.lastName}", "email": "${profile.email}", "phone_number": "${profile.phoneNumber}", "password": "$password", "region": "${profile.region}", "district": "${profile.district}", "ward": "${profile.ward}", "street": "${profile.street}"}',
      );

      if (response.statusCode == 200) {
        return response.body;
      } else {
        // throw Exception('Failed to update profile');
        return 'Failed to update profile';
      }
    } catch (e) {
      rethrow;
    }
  }
}