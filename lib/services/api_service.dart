import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/models/user_profile.dart';


class ApiService {

  Future<String> updateUserProfile(UserProfile profile, String password, String? imagePath, {bool useDNS = true}) async {
    try {

      // If all validations pass, proceed with registration
      final Uri uri = useDNS ? Uri.parse('${backend_url}api/update_user') // Original URL 
      : Uri.parse('${backend_url_with_fallback_ip}api/update_user'); // Use IP
        
      final response = await http.post(
        uri,
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
    } on SocketException catch (e) {
      debugPrint('Network error occurred:');
      debugPrint('- Exception type: ${e.runtimeType}');
      debugPrint('- Message: ${e.message}');
      
      String response = "";
      if (e.osError != null) {
        debugPrint('  - Error number (errno): ${e.osError!.errorCode}');
        debugPrint('  - OS message: ${e.osError!.message}');

        // Retry with IP if DNS fails (errno = 7) and not already retrying
        if (e.osError!.errorCode == 7 && useDNS) {
          debugPrint('DNS failed! Retrying with IP: ${backend_url_with_fallback_ip}...');
          response = await updateUserProfile(profile, password, imagePath, useDNS: false); // Recursive retry
        }
      }
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<String> deleteUserProfile(int user_id, {bool useDNS = true}) async {
    try {

      // If all validations pass, proceed with registration
      final Uri uri = useDNS ? Uri.parse('${backend_url}api/delete_user/$user_id') // Original URL 
      : Uri.parse('${backend_url_with_fallback_ip}api/delete_user/$user_id'); // Use IP
      
      final response = await http.post(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: '{"user_id": $user_id}',
      );

      if (response.statusCode == 200) {
        return response.body;
      } else {
        // throw Exception('Failed to update profile');
        return 'Failed to delete you account';
      }
    } on SocketException catch (e) {
      debugPrint('Network error occurred:');
      debugPrint('- Exception type: ${e.runtimeType}');
      debugPrint('- Message: ${e.message}');
      
      String response = "";
      if (e.osError != null) {
        debugPrint('  - Error number (errno): ${e.osError!.errorCode}');
        debugPrint('  - OS message: ${e.osError!.message}');

        // Retry with IP if DNS fails (errno = 7) and not already retrying
        if (e.osError!.errorCode == 7 && useDNS) {
          debugPrint('DNS failed! Retrying with IP: ${backend_url_with_fallback_ip}...');
          response = await deleteUserProfile(user_id, useDNS: false); // Recursive retry
        }
      }
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<String> sendMessage(int user_id, String name, String phoneNumber, String email, String message, {bool useDNS = true}) async {
    try {

      // If all validations pass, proceed with registration
      final Uri uri = useDNS ? Uri.parse('${backend_url}api/send_message') // Original URL 
      : Uri.parse('${backend_url_with_fallback_ip}api/send_message'); // Use IP
        
      final response = await http.post(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: '{"user_id": "$user_id", "name": "$name", "phone_number": "$phoneNumber", "email": "$email", "message": "$message" }',
      );

      if (response.statusCode == 200) {
        return response.body;
      } else {
        // throw Exception('Failed to update profile');
        return 'Failed to send message';
      }
    } on SocketException catch (e) {
      debugPrint('Network error occurred:');
      debugPrint('- Exception type: ${e.runtimeType}');
      debugPrint('- Message: ${e.message}');
      
      String response = "";
      if (e.osError != null) {
        debugPrint('  - Error number (errno): ${e.osError!.errorCode}');
        debugPrint('  - OS message: ${e.osError!.message}');

        // Retry with IP if DNS fails (errno = 7) and not already retrying
        if (e.osError!.errorCode == 7 && useDNS) {
          debugPrint('DNS failed! Retrying with IP: ${backend_url_with_fallback_ip}...');
          response = await  sendMessage(user_id, name, phoneNumber, email, message, useDNS: false); // Recursive retry
        }
      }
      return response;
    } catch (e) {
      rethrow;
    }
  }
}