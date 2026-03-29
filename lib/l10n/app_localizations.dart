import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_sw.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('sw')
  ];

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @events.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get events;

  /// No description provided for @myTickets.
  ///
  /// In en, this message translates to:
  /// **'My Tickets'**
  String get myTickets;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @addParcel.
  ///
  /// In en, this message translates to:
  /// **'Add Parcel'**
  String get addParcel;

  /// No description provided for @addConsignment.
  ///
  /// In en, this message translates to:
  /// **'Add Consignment'**
  String get addConsignment;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @packageAddedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Package added successfully.'**
  String get packageAddedSuccessfully;

  /// No description provided for @addNewConsignment.
  ///
  /// In en, this message translates to:
  /// **'Add New Consignment'**
  String get addNewConsignment;

  /// No description provided for @packageName.
  ///
  /// In en, this message translates to:
  /// **'Package Name'**
  String get packageName;

  /// No description provided for @senderName.
  ///
  /// In en, this message translates to:
  /// **'Sender Name'**
  String get senderName;

  /// No description provided for @senderPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Sender Phone Number'**
  String get senderPhoneNumber;

  /// No description provided for @from.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get from;

  /// No description provided for @to.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get to;

  /// No description provided for @receiverName.
  ///
  /// In en, this message translates to:
  /// **'Receiver Name'**
  String get receiverName;

  /// No description provided for @receiverPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Receiver Phone Number'**
  String get receiverPhoneNumber;

  /// No description provided for @consignmentItems.
  ///
  /// In en, this message translates to:
  /// **'Consignment Items'**
  String get consignmentItems;

  /// No description provided for @packageValue.
  ///
  /// In en, this message translates to:
  /// **'Package Value'**
  String get packageValue;

  /// No description provided for @paidAmount.
  ///
  /// In en, this message translates to:
  /// **'Paid Amount'**
  String get paidAmount;

  /// No description provided for @addItems.
  ///
  /// In en, this message translates to:
  /// **'Add Items'**
  String get addItems;

  /// No description provided for @addParcelButton.
  ///
  /// In en, this message translates to:
  /// **'Add Parcel'**
  String get addParcelButton;

  /// No description provided for @addConsignmentButton.
  ///
  /// In en, this message translates to:
  /// **'Add Consignment'**
  String get addConsignmentButton;

  /// No description provided for @itemName.
  ///
  /// In en, this message translates to:
  /// **'Item Name'**
  String get itemName;

  /// No description provided for @price.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get price;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// No description provided for @paymentStatus.
  ///
  /// In en, this message translates to:
  /// **'Payment Status'**
  String get paymentStatus;

  /// No description provided for @paid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paid;

  /// No description provided for @notPaid.
  ///
  /// In en, this message translates to:
  /// **'Not Paid'**
  String get notPaid;

  /// No description provided for @packageType.
  ///
  /// In en, this message translates to:
  /// **'Package Type'**
  String get packageType;

  /// No description provided for @parcel.
  ///
  /// In en, this message translates to:
  /// **'Parcel'**
  String get parcel;

  /// No description provided for @consignment.
  ///
  /// In en, this message translates to:
  /// **'Consignment'**
  String get consignment;

  /// No description provided for @pleaseEnterPackageName.
  ///
  /// In en, this message translates to:
  /// **'Please enter package name'**
  String get pleaseEnterPackageName;

  /// No description provided for @packageNameMaxLength.
  ///
  /// In en, this message translates to:
  /// **'Package name must be 100 characters or less'**
  String get packageNameMaxLength;

  /// No description provided for @pleaseEnterSenderName.
  ///
  /// In en, this message translates to:
  /// **'Please enter sender name'**
  String get pleaseEnterSenderName;

  /// No description provided for @senderNameMaxLength.
  ///
  /// In en, this message translates to:
  /// **'Sender name must be 100 characters or less'**
  String get senderNameMaxLength;

  /// No description provided for @pleaseEnterSenderPhone.
  ///
  /// In en, this message translates to:
  /// **'Please enter sender phone number'**
  String get pleaseEnterSenderPhone;

  /// No description provided for @senderPhoneMaxLength.
  ///
  /// In en, this message translates to:
  /// **'Sender phone number must be 15 characters or less'**
  String get senderPhoneMaxLength;

  /// No description provided for @pleaseEnterOrigin.
  ///
  /// In en, this message translates to:
  /// **'Please enter origin'**
  String get pleaseEnterOrigin;

  /// No description provided for @originMaxLength.
  ///
  /// In en, this message translates to:
  /// **'Origin name must be 100 characters or less'**
  String get originMaxLength;

  /// No description provided for @pleaseSelectOrigin.
  ///
  /// In en, this message translates to:
  /// **'Please select an origin'**
  String get pleaseSelectOrigin;

  /// No description provided for @pleaseSelectDestination.
  ///
  /// In en, this message translates to:
  /// **'Please select a destination'**
  String get pleaseSelectDestination;

  /// No description provided for @pleaseEnterDestination.
  ///
  /// In en, this message translates to:
  /// **'Please enter or select a destination'**
  String get pleaseEnterDestination;

  /// No description provided for @pleaseEnterReceiverName.
  ///
  /// In en, this message translates to:
  /// **'Please enter receiver name'**
  String get pleaseEnterReceiverName;

  /// No description provided for @receiverNameMaxLength.
  ///
  /// In en, this message translates to:
  /// **'Receiver name must be 100 characters or less'**
  String get receiverNameMaxLength;

  /// No description provided for @pleaseEnterReceiverPhone.
  ///
  /// In en, this message translates to:
  /// **'Please enter receiver phone number'**
  String get pleaseEnterReceiverPhone;

  /// No description provided for @receiverPhoneMaxLength.
  ///
  /// In en, this message translates to:
  /// **'Receiver phone number must be 15 characters or less'**
  String get receiverPhoneMaxLength;

  /// No description provided for @pleaseEnterPackageValue.
  ///
  /// In en, this message translates to:
  /// **'Please enter package value'**
  String get pleaseEnterPackageValue;

  /// No description provided for @packageValueMaxLength.
  ///
  /// In en, this message translates to:
  /// **'Package value must be 8 characters or less'**
  String get packageValueMaxLength;

  /// No description provided for @pleaseEnterPaidAmount.
  ///
  /// In en, this message translates to:
  /// **'Please enter Paid Amount'**
  String get pleaseEnterPaidAmount;

  /// No description provided for @paidAmountMaxLength.
  ///
  /// In en, this message translates to:
  /// **'Paid amount must be 8 characters or less'**
  String get paidAmountMaxLength;

  /// No description provided for @pleaseAddAtLeastOneItem.
  ///
  /// In en, this message translates to:
  /// **'Please add at least one item'**
  String get pleaseAddAtLeastOneItem;

  /// No description provided for @pleaseEnterItemName.
  ///
  /// In en, this message translates to:
  /// **'Please enter item name'**
  String get pleaseEnterItemName;

  /// No description provided for @itemPriceGreaterThanZero.
  ///
  /// In en, this message translates to:
  /// **'Item price must be greater than 0'**
  String get itemPriceGreaterThanZero;

  /// No description provided for @itemQuantityGreaterThanZero.
  ///
  /// In en, this message translates to:
  /// **'Number of items must be greater than 0'**
  String get itemQuantityGreaterThanZero;

  /// No description provided for @itemNamesCannotBeEmpty.
  ///
  /// In en, this message translates to:
  /// **'Item name cannot be empty'**
  String get itemNamesCannotBeEmpty;

  /// No description provided for @itemNamesMaxLength.
  ///
  /// In en, this message translates to:
  /// **'Item names must be 100 characters or less'**
  String get itemNamesMaxLength;

  /// No description provided for @itemNamesShouldBeDifferent.
  ///
  /// In en, this message translates to:
  /// **'Item names should be different'**
  String get itemNamesShouldBeDifferent;

  /// No description provided for @originDestinationSame.
  ///
  /// In en, this message translates to:
  /// **'Origin and destination cannot be the same location.'**
  String get originDestinationSame;

  /// No description provided for @consignmentAddedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Package added successfully.'**
  String get consignmentAddedSuccess;

  /// No description provided for @connectionError.
  ///
  /// In en, this message translates to:
  /// **'Connection Error'**
  String get connectionError;

  /// No description provided for @couldNotConnectToServer.
  ///
  /// In en, this message translates to:
  /// **'Could not connect to the server. Please check your internet connection.'**
  String get couldNotConnectToServer;

  /// No description provided for @qrCodeUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'QR Code Scanning Unavailable'**
  String get qrCodeUnavailableTitle;

  /// No description provided for @qrCodeUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'This feature is only supported in the Tiketi Mkononi mobile app. Please download and open the application on your smartphone to scan QR codes'**
  String get qrCodeUnavailableMessage;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @installApp.
  ///
  /// In en, this message translates to:
  /// **'Install App'**
  String get installApp;

  /// No description provided for @moreOptions.
  ///
  /// In en, this message translates to:
  /// **'More Options'**
  String get moreOptions;

  /// No description provided for @reprintReceipt.
  ///
  /// In en, this message translates to:
  /// **'Reprint Receipt'**
  String get reprintReceipt;

  /// No description provided for @myReceipt.
  ///
  /// In en, this message translates to:
  /// **'My Receipt'**
  String get myReceipt;

  /// No description provided for @refreshPrinters.
  ///
  /// In en, this message translates to:
  /// **'Refresh Printers'**
  String get refreshPrinters;

  /// No description provided for @printReceipts.
  ///
  /// In en, this message translates to:
  /// **'Print {count} Receipts'**
  String printReceipts(Object count);

  /// No description provided for @receiptsBalance.
  ///
  /// In en, this message translates to:
  /// **'Receipts Balance: {balance}'**
  String receiptsBalance(Object balance);

  /// No description provided for @topupReceipt.
  ///
  /// In en, this message translates to:
  /// **'Topup Receipt'**
  String get topupReceipt;

  /// No description provided for @exit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get exit;

  /// No description provided for @selectPrinter.
  ///
  /// In en, this message translates to:
  /// **'Select Printer'**
  String get selectPrinter;

  /// No description provided for @noPairedPrinterFound.
  ///
  /// In en, this message translates to:
  /// **'No paired Bluetooth printer found'**
  String get noPairedPrinterFound;

  /// No description provided for @foundPairedPrinters.
  ///
  /// In en, this message translates to:
  /// **'Found {count} paired Bluetooth printer'**
  String foundPairedPrinters(Object count);

  /// No description provided for @printerNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Printer not connected'**
  String get printerNotConnected;

  /// No description provided for @noPrintersFound.
  ///
  /// In en, this message translates to:
  /// **'No printers found.'**
  String get noPrintersFound;

  /// No description provided for @selectNumberOfReceipts.
  ///
  /// In en, this message translates to:
  /// **'Select number of receipts'**
  String get selectNumberOfReceipts;

  /// No description provided for @printOneReceipt.
  ///
  /// In en, this message translates to:
  /// **'Print 1 receipt'**
  String get printOneReceipt;

  /// No description provided for @printTwoReceipts.
  ///
  /// In en, this message translates to:
  /// **'Print 2 receipts'**
  String get printTwoReceipts;

  /// No description provided for @parcelReceipt.
  ///
  /// In en, this message translates to:
  /// **'PARCEL RECEIPT'**
  String get parcelReceipt;

  /// No description provided for @consignmentReceipt.
  ///
  /// In en, this message translates to:
  /// **'CONSIGNMENT RECEIPT'**
  String get consignmentReceipt;

  /// No description provided for @packageNo.
  ///
  /// In en, this message translates to:
  /// **'Package No: {number}'**
  String packageNo(Object number);

  /// No description provided for @packageNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Package Name: {name}'**
  String packageNameLabel(Object name);

  /// No description provided for @packageValueLabel.
  ///
  /// In en, this message translates to:
  /// **'Package Value: TZS {value}'**
  String packageValueLabel(Object value);

  /// No description provided for @paymentStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment Status: {status}'**
  String paymentStatusLabel(Object status);

  /// No description provided for @paidAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Paid Amount: TZS {amount}'**
  String paidAmountLabel(Object amount);

  /// No description provided for @route.
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get route;

  /// No description provided for @fromLabel.
  ///
  /// In en, this message translates to:
  /// **'From: {from}'**
  String fromLabel(Object from);

  /// No description provided for @toLabel.
  ///
  /// In en, this message translates to:
  /// **'To: {to}'**
  String toLabel(Object to);

  /// No description provided for @sender.
  ///
  /// In en, this message translates to:
  /// **'Sender'**
  String get sender;

  /// No description provided for @nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name: {name}'**
  String nameLabel(Object name);

  /// No description provided for @phoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone: {phone}'**
  String phoneLabel(Object phone);

  /// No description provided for @receiver.
  ///
  /// In en, this message translates to:
  /// **'Receiver'**
  String get receiver;

  /// No description provided for @items.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get items;

  /// No description provided for @issuedBy.
  ///
  /// In en, this message translates to:
  /// **'Issued By'**
  String get issuedBy;

  /// No description provided for @totalAmount.
  ///
  /// In en, this message translates to:
  /// **'Total Amount'**
  String get totalAmount;

  /// No description provided for @parcelInfo.
  ///
  /// In en, this message translates to:
  /// **'PARCEL INFO'**
  String get parcelInfo;

  /// No description provided for @consignmentInfo.
  ///
  /// In en, this message translates to:
  /// **'CONSIGNMENT INFO'**
  String get consignmentInfo;

  /// No description provided for @pkgNo.
  ///
  /// In en, this message translates to:
  /// **'PKG No: {number}'**
  String pkgNo(Object number);

  /// No description provided for @pkgName.
  ///
  /// In en, this message translates to:
  /// **'PKG Name: {name}'**
  String pkgName(Object name);

  /// No description provided for @routeTo.
  ///
  /// In en, this message translates to:
  /// **'{from} to {to}'**
  String routeTo(Object from, Object to);

  /// No description provided for @nameOnly.
  ///
  /// In en, this message translates to:
  /// **'Name:{name}'**
  String nameOnly(Object name);

  /// No description provided for @phoneOnly.
  ///
  /// In en, this message translates to:
  /// **'Phone:{phone}'**
  String phoneOnly(Object phone);

  /// No description provided for @poweredBy.
  ///
  /// In en, this message translates to:
  /// **'Powered by Tiketi Mkononi'**
  String get poweredBy;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email: tiketimkononi@telabs.co.tz'**
  String get email;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone: +255 651 138 380'**
  String get phoneNumber;

  /// No description provided for @requestFailed.
  ///
  /// In en, this message translates to:
  /// **'Request failed: {statusCode}'**
  String requestFailed(Object statusCode);

  /// No description provided for @imageTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Image is Too Large'**
  String get imageTooLarge;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String error(Object error);

  /// No description provided for @processingPayment.
  ///
  /// In en, this message translates to:
  /// **'Processing payment!'**
  String get processingPayment;

  /// No description provided for @paymentRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Ombi la malipo limetumwa'**
  String get paymentRequestSent;

  /// No description provided for @paymentFailed.
  ///
  /// In en, this message translates to:
  /// **'Malipo yameshindwa'**
  String get paymentFailed;

  /// No description provided for @phoneNumberCannotBeEmpty.
  ///
  /// In en, this message translates to:
  /// **'Phone number cannot be empty'**
  String get phoneNumberCannotBeEmpty;

  /// No description provided for @choosePackage.
  ///
  /// In en, this message translates to:
  /// **'Chagua kifurushi'**
  String get choosePackage;

  /// No description provided for @paymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Njia ya Malipo'**
  String get paymentMethod;

  /// No description provided for @paymentPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Namba ya simu ya malipo'**
  String get paymentPhoneNumber;

  /// No description provided for @pay.
  ///
  /// In en, this message translates to:
  /// **'Lipa'**
  String get pay;

  /// No description provided for @receipts.
  ///
  /// In en, this message translates to:
  /// **'Receipts {count} - TSH {price}'**
  String receipts(Object count, Object price);

  /// No description provided for @connectionErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Could not connect to the server. Please check your internet connection.'**
  String get connectionErrorMessage;

  /// No description provided for @searchPackageOrSender.
  ///
  /// In en, this message translates to:
  /// **'Search package or sender name...'**
  String get searchPackageOrSender;

  /// No description provided for @failedToLoadConsignments.
  ///
  /// In en, this message translates to:
  /// **'Failed to load consignments ({statusCode})'**
  String failedToLoadConsignments(Object statusCode);

  /// No description provided for @networkError.
  ///
  /// In en, this message translates to:
  /// **'Network error. Please check your connection.'**
  String get networkError;

  /// No description provided for @unexpectedError.
  ///
  /// In en, this message translates to:
  /// **'Unexpected error occurred: {error}'**
  String unexpectedError(Object error);

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @totalRevenue.
  ///
  /// In en, this message translates to:
  /// **'Total Revenue'**
  String get totalRevenue;

  /// No description provided for @selectConsignmentToViewDetails.
  ///
  /// In en, this message translates to:
  /// **'Select a consignment to view details'**
  String get selectConsignmentToViewDetails;

  /// No description provided for @unnamedPackage.
  ///
  /// In en, this message translates to:
  /// **'Unnamed Package'**
  String get unnamedPackage;

  /// No description provided for @thankYou.
  ///
  /// In en, this message translates to:
  /// **'Thank you'**
  String get thankYou;

  /// No description provided for @couldNotLaunchPhone.
  ///
  /// In en, this message translates to:
  /// **'Could not launch phone app'**
  String get couldNotLaunchPhone;

  /// No description provided for @itemsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String itemsCount(Object count);

  /// No description provided for @unnamedItem.
  ///
  /// In en, this message translates to:
  /// **'Unnamed Item'**
  String get unnamedItem;

  /// No description provided for @packageInformation.
  ///
  /// In en, this message translates to:
  /// **'Package Information'**
  String get packageInformation;

  /// No description provided for @routeInformation.
  ///
  /// In en, this message translates to:
  /// **'Route Information'**
  String get routeInformation;

  /// No description provided for @senderDetails.
  ///
  /// In en, this message translates to:
  /// **'Sender Details'**
  String get senderDetails;

  /// No description provided for @receiverDetails.
  ///
  /// In en, this message translates to:
  /// **'Receiver Details'**
  String get receiverDetails;

  /// No description provided for @parcelDetails.
  ///
  /// In en, this message translates to:
  /// **'Parcel Details'**
  String get parcelDetails;

  /// No description provided for @consignmentDetails.
  ///
  /// In en, this message translates to:
  /// **'Consignment Details'**
  String get consignmentDetails;

  /// No description provided for @noConsignmentsYet.
  ///
  /// In en, this message translates to:
  /// **'No Consignments Yet'**
  String get noConsignmentsYet;

  /// No description provided for @consignmentsYouCreateWillAppearHere.
  ///
  /// In en, this message translates to:
  /// **'Consignments you create will appear here'**
  String get consignmentsYouCreateWillAppearHere;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgain;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @parcels.
  ///
  /// In en, this message translates to:
  /// **'Parcels'**
  String get parcels;

  /// No description provided for @consignments.
  ///
  /// In en, this message translates to:
  /// **'Consignments'**
  String get consignments;

  /// No description provided for @unpaid.
  ///
  /// In en, this message translates to:
  /// **'Unpaid'**
  String get unpaid;

  /// No description provided for @exportUnpaid.
  ///
  /// In en, this message translates to:
  /// **'Export Unpaid'**
  String get exportUnpaid;

  /// No description provided for @exportPaid.
  ///
  /// In en, this message translates to:
  /// **'Export Paid'**
  String get exportPaid;

  /// No description provided for @exportAll.
  ///
  /// In en, this message translates to:
  /// **'Export All'**
  String get exportAll;

  /// No description provided for @noPackagesFound.
  ///
  /// In en, this message translates to:
  /// **'No packages found'**
  String get noPackagesFound;

  /// No description provided for @packageNumber.
  ///
  /// In en, this message translates to:
  /// **'Package Number'**
  String get packageNumber;

  /// No description provided for @senderPhone.
  ///
  /// In en, this message translates to:
  /// **'Sender Phone'**
  String get senderPhone;

  /// No description provided for @receiverPhone.
  ///
  /// In en, this message translates to:
  /// **'Receiver Phone'**
  String get receiverPhone;

  /// No description provided for @to2.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get to2;

  /// No description provided for @amountToBePaid.
  ///
  /// In en, this message translates to:
  /// **'Amount to be Paid'**
  String get amountToBePaid;

  /// No description provided for @isParcel.
  ///
  /// In en, this message translates to:
  /// **'Is Parcel'**
  String get isParcel;

  /// No description provided for @issuerPhone.
  ///
  /// In en, this message translates to:
  /// **'Issuer Phone'**
  String get issuerPhone;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @errorExportingToExcel.
  ///
  /// In en, this message translates to:
  /// **'Error exporting to Excel: {error}'**
  String errorExportingToExcel(Object error);

  /// No description provided for @unpaidPackages.
  ///
  /// In en, this message translates to:
  /// **'Unpaid_Packages'**
  String get unpaidPackages;

  /// No description provided for @paidPackages.
  ///
  /// In en, this message translates to:
  /// **'Paid_Packages'**
  String get paidPackages;

  /// No description provided for @allPackages.
  ///
  /// In en, this message translates to:
  /// **'All_Packages'**
  String get allPackages;

  /// No description provided for @selectConsignment.
  ///
  /// In en, this message translates to:
  /// **'Select a consignment to view details'**
  String get selectConsignment;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'sw'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'sw':
      return AppLocalizationsSw();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
