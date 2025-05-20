import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Swahili (`sw`).
class AppLocalizationsSw extends AppLocalizations {
  AppLocalizationsSw([String locale = 'sw']) : super(locale);

  @override
  String get appTitle => 'Programu ya Tiketi';

  @override
  String get home => 'Nyumbani';

  @override
  String get events => 'Matukio';

  @override
  String get myTickets => 'Tiketi Zangu';

  @override
  String get profile => 'Wasifu';

  @override
  String get searchEvents => 'Tafuta matukio...';

  @override
  String get featuredEvents => 'Matukio Maalum';

  @override
  String get categories => 'Kategoria';

  @override
  String get buyTickets => 'Nunua Tiketi';

  @override
  String ticketsSold(int count) {
    return 'Tiketi $count zimeuzwa';
  }

  @override
  String get eventDetails => 'Maelezo ya Tukio';

  @override
  String get language => 'Lugha';

  @override
  String get editProfile => 'Hariri Wasifu';

  @override
  String get logout => 'Toka';

  @override
  String get settings => 'Mipangilio';

  @override
  String get qrScanner => 'Skana Msimbo wa QR';

  @override
  String get scanQrCode => 'Skana Msimbo wa QR';

  @override
  String get alignQrCode => 'Weka msimbo wa QR ndani ya fremu';
}
