import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiketi_mkononi/models/user_profile.dart';

class StorageService {
  static const String _userProfileKey = 'user_profile';
  final SharedPreferences _prefs;

  StorageService(this._prefs);

  Future<void> saveUserProfile(UserProfile profile) async {
    await _prefs.setString(_userProfileKey, jsonEncode(profile.toJson()));
    await _prefs.setBool('first_launch', false);
  }

  UserProfile? getUserProfile() {
    final String? profileJson = _prefs.getString(_userProfileKey);
    if (profileJson == null) return null;
    return UserProfile.fromJson(jsonDecode(profileJson));
  }

  // Add this function to clear the user profile on logout
  Future<void> clearUserProfile() async {
    await _prefs.remove("first_launch");
    await _prefs.remove("cached_events");
    await _prefs.remove("cached_tickets");
    await _prefs.remove("purchased_events");
    await _prefs.remove("favorite_events");
    await _prefs.remove("selected_event_categories");
    await _prefs.remove("use_dns");
    await _prefs.remove(_userProfileKey);
    await _prefs.remove("receipts_balance");
    // await _prefs.remove("number_of_receipts_to_print");
    // await _prefs.remove("selected_printer_name");
    // await _prefs.remove("selected_printer_url");
    // await _prefs.remove("printer_name");
    // await _prefs.remove("printer_mac");
    // await _prefs.remove("selectedPrinterUrl");
  }
}