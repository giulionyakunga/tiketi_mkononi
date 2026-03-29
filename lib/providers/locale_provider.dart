import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tiketi_mkononi/services/language_service.dart';


final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('en')) {
    _load();
  }

  Future<void> _load() async {
    final locale = await LanguageService.loadLocale();
    state = locale;
  }

  Future<void> changeLocale(String languageCode) async {
    final newLocale = Locale(languageCode);
    state = newLocale;

    await LanguageService.saveLocale(languageCode); // persist
  }
}