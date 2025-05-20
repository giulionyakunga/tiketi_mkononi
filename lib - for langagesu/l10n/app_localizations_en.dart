import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Ticket App';

  @override
  String get home => 'Home';

  @override
  String get events => 'Events';

  @override
  String get myTickets => 'My Tickets';

  @override
  String get profile => 'Profile';

  @override
  String get searchEvents => 'Search events...';

  @override
  String get featuredEvents => 'Featured Events';

  @override
  String get categories => 'Categories';

  @override
  String get buyTickets => 'Buy Tickets';

  @override
  String ticketsSold(int count) {
    return '$count tickets sold';
  }

  @override
  String get eventDetails => 'Event Details';

  @override
  String get language => 'Language';

  @override
  String get editProfile => 'Edit Profile';

  @override
  String get logout => 'Logout';

  @override
  String get settings => 'Settings';

  @override
  String get qrScanner => 'QR Code Scanner';

  @override
  String get scanQrCode => 'Scan QR Code';

  @override
  String get alignQrCode => 'Align QR code within the frame';
}
