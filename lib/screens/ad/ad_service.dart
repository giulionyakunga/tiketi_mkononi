// services/ad_service.dart
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/models/ad_model.dart';

class AdService {
  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<bool> createAd(AdModel ad) async {
    try {
      final token = await _getAuthToken();
      final response = await http.post(
        Uri.parse('${backend_url}api/admin/ads'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(ad.toJson()),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return true;
      } else {
        print('Failed to create ad: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error creating ad: $e');
      return false;
    }
  }

  Future<bool> updateAd(String adId, AdModel ad) async {
    try {
      final token = await _getAuthToken();
      final response = await http.put(
        Uri.parse('${backend_url}api/admin/ads/$adId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(ad.toJson()),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print('Failed to update ad: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error updating ad: $e');
      return false;
    }
  }

  Future<String> uploadImage(File imageFile) async {
    try {
      final token = await _getAuthToken();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${backend_url}api/upload'),
      );
      
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
        ),
      );
      
      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final jsonData = jsonDecode(responseData);
      
      if (response.statusCode == 200) {
        return jsonData['image_url'] ?? '';
      } else {
        print('Failed to upload image: $responseData');
        return '';
      }
    } catch (e) {
      print('Error uploading image: $e');
      return '';
    }
  }

  Future<List<AdModel>> getAds() async {
    try {
      final token = await _getAuthToken();
      final response = await http.get(
        Uri.parse('${backend_url}api/ads'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> adsJson = data['data'];
        return adsJson.map((json) => AdModel.fromJson(json)).toList();
      } else {
        return [];
      }
    } catch (e) {
      print('Error fetching ads: $e');
      return [];
    }
  }

  Future<bool> deleteAd(String adId) async {
    try {
      final token = await _getAuthToken();
      final response = await http.delete(
        Uri.parse('${backend_url}api/admin/ads/$adId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting ad: $e');
      return false;
    }
  }
}