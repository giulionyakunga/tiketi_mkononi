// services/ad_service.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/models/ad.dart';

class AdService {
  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<Map<String, dynamic>> createAd(
    Ad ad,
    String fileType,
    String base64EncodeString,
  ) async {
    try {
      final token = await _getAuthToken();

      final response = await http.post(
        Uri.parse('${backend_url}api/create_ad'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          ...ad.toJson(),
          'file_type': fileType,
          'base64_image': base64EncodeString,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {
          'status': true,
          'body': response.body,
        };
      } else {
        debugPrint('Failed to create ad: ${response.body}');

        return {
          'status': false,
          'body': response.body,
        };
      }
    } catch (e) {
      print('Error creating ad: $e');

      return {
        'status': false,
        'body': e.toString(),
      };
    }
  }


  Future<Map<String, dynamic>> updateAd(
    Ad ad,
    String fileType,
    String base64EncodeString,
  ) async {
    try {
      final token = await _getAuthToken();
      final response = await http.post(
        Uri.parse('${backend_url}api/edit_ad'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          ...ad.toJson(),
          'file_type': fileType,
          'base64_image': base64EncodeString,
        }),
      );

      if (response.statusCode == 200) {
        return {
          'status': true,
          'body': response.body,
        };
      } else {
        print('Failed to update ad: ${response.body}');

        return {
          'status': false,
          'body': response.body,
        };
      }
    } catch (e) {
      print('Error updating ad: $e');

      return {
        'status': false,
        'body': e.toString(),
      };
    }
  }
  
  Future<List<Ad>> getAds({bool useDNS = true}) async {
    try {
      final Uri uri = useDNS
          ? Uri.parse('${backend_url}api/get_ads')
          : Uri.parse('${backend_url_with_fallback_ip}get_ads');

      debugPrint('Fetching ads from: $uri');

      final response = await http.get(uri);

      debugPrint('Response Ad body 22: ${response.body}'); // Log the response body for debugging

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        List<dynamic> data;
       
        if (decoded is List) {
          data = decoded;
        } else if (decoded is Map && decoded['ads'] is List) {
          data = decoded['ads'];
        } else {
          data = [];
        }

        final ads = data
            .whereType<Map<String, dynamic>>()
            .map((json) => Ad.fromJson(json))
            .where((ad) => ad.isActive)
            .toList();

        ads.sort((a, b) => b.priority.compareTo(a.priority));

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_ads', jsonEncode(decoded));

        return ads;

      } else {
        debugPrint(
          'Failed to fetch ads. Status code: ${response.statusCode}',
        );
        return [];
      }
    } on SocketException catch (e) {
      debugPrint('Ads network error: ${e.message}');
      debugPrint('Error code: ${e.osError?.errorCode}');

      // DNS failed - retry using fallback IP.
      if ((e.osError?.errorCode == 11001 ||
              e.osError?.errorCode == 7) &&
          useDNS) {
        debugPrint(
          'DNS failed while loading ads. Retrying with fallback IP...',
        );
      }

      return [];
    
    } catch (e) {
      debugPrint('Error loading ads: $e');
      return [];
    }
  } 

  Future<List<Ad>> getMyAds(int userId, {bool useDNS = true}) async {
    try {
      final Uri uri = useDNS
          ? Uri.parse('${backend_url}api/get_user_ads/${userId}')
          : Uri.parse('${backend_url_with_fallback_ip}get_ads');

      debugPrint('Fetching ads from: $uri');

      final response = await http.get(uri);

      debugPrint('Response Ad body 22: ${response.body}'); // Log the response body for debugging

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        List<dynamic> data;
       
        if (decoded is List) {
          data = decoded;
        } else if (decoded is Map && decoded['ads'] is List) {
          data = decoded['ads'];
        } else {
          data = [];
        }

        final ads = data
            .whereType<Map<String, dynamic>>()
            .map((json) => Ad.fromJson(json))
            .where((ad) => ad.isActive)
            .toList();

        ads.sort((a, b) => b.priority.compareTo(a.priority));

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_ads', jsonEncode(decoded));

        return ads;

      } else {
        debugPrint(
          'Failed to fetch ads. Status code: ${response.statusCode}',
        );
        return [];
      }
    } on SocketException catch (e) {
      debugPrint('Ads network error: ${e.message}');
      debugPrint('Error code: ${e.osError?.errorCode}');

      // DNS failed - retry using fallback IP.
      if ((e.osError?.errorCode == 11001 ||
              e.osError?.errorCode == 7) &&
          useDNS) {
        debugPrint(
          'DNS failed while loading ads. Retrying with fallback IP...',
        );
      }

      return [];
    
    } catch (e) {
      debugPrint('Error loading ads: $e');
      return [];
    }
  }

  Future<bool> deleteAd(String adId) async {
    try {
      final token = await _getAuthToken();
      final response = await http.delete(
        Uri.parse('${backend_url}api/delete_ads/$adId'),
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