import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiketi_mkononi/models/user_profile.dart';

class StorageService {
  static const String _userProfileKey = 'user_profile';
  final SharedPreferences _prefs;

  StorageService(this._prefs);

  Future<void> saveUserProfile(UserProfile profile) async {
    await _prefs.setString(_userProfileKey, jsonEncode(profile.toJson()));
  }

  UserProfile? getUserProfile() {
    final String? profileJson = _prefs.getString(_userProfileKey);
    if (profileJson == null) return null;
    return UserProfile.fromJson(jsonDecode(profileJson));
  }

  // Add this function to clear the user profile on logout
  Future<void> clearUserProfile() async {
    await _prefs.remove("cached_events");
    await _prefs.remove("cached_tickets");
    await _prefs.remove(_userProfileKey);
  }
}