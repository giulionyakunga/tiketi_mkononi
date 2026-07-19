// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get home => 'Home';

  @override
  String get events => 'Events';

  @override
  String get myTickets => 'My Tickets';

  @override
  String get profile => 'Profile';

  @override
  String get myProfile => 'My Profile';

  @override
  String get searchEvent => 'Search event';

  @override
  String get featuredEvents => 'Featured Events';

  @override
  String get seeAll => 'See All';

  @override
  String get categories => 'Categories';

  @override
  String get concerts => 'Concerts';

  @override
  String get buses => 'Buses';

  @override
  String get cargo => 'Cargo';

  @override
  String get cargos => 'Cargos';

  @override
  String get myOrders => 'My Orders';

  @override
  String officeCargos(Object officeName) {
    return '$officeName Cargos';
  }

  @override
  String get cargosYouAddWillAppearHere => 'Cargos you add will appear here';

  @override
  String get noCargosYet => 'No Cargos Yet';

  @override
  String get sports => 'Sports';

  @override
  String get comedy => 'Comedy';

  @override
  String get fun => 'Fun';

  @override
  String get barsAndGrills => 'Bars & Grills';

  @override
  String get training => 'Training';

  @override
  String get theater => 'Theater';

  @override
  String get wedding => 'Wedding';

  @override
  String get celebration => 'Celebration';

  @override
  String get addParcel => 'Add Parcel';

  @override
  String get addConsignment => 'Add Consignment';

  @override
  String get placeOrder => 'Place Order';

  @override
  String get success => 'Success';

  @override
  String get packageAddedSuccessfully => 'Package added successfully.';

  @override
  String get addNewConsignment => 'Add New Consignment';

  @override
  String get packageName => 'Package Name';

  @override
  String get senderName => 'Sender Name';

  @override
  String get senderPhoneNumber => 'Sender Phone Number';

  @override
  String get from => 'From';

  @override
  String get to => 'Destination';

  @override
  String get selectProduct => 'Select Product';

  @override
  String get customerName => 'Customer Name';

  @override
  String get customerPhoneNumber => 'Customer Phone Number';

  @override
  String get passingThrough => 'Passing Through';

  @override
  String get startingPoint => 'Starting point';

  @override
  String get finalPoint => 'Final point';

  @override
  String get availableSeats => 'Available Seats';

  @override
  String get pricePerSeat => 'Price per seat';

  @override
  String get departure => 'departure';

  @override
  String get arrival => 'arrival';

  @override
  String get deleteRoute => 'Delete Route';

  @override
  String get searchRouteByName => 'Search route by name...';

  @override
  String get receiverName => 'Receiver Name';

  @override
  String get receiverPhoneNumber => 'Receiver Phone Number';

  @override
  String get consignmentItems => 'Consignment Items';

  @override
  String get packageValue => 'Package Value';

  @override
  String get paidAmount => 'Paid Amount';

  @override
  String get addItems => 'Add Items';

  @override
  String get addParcelButton => 'Add Parcel';

  @override
  String get addConsignmentButton => 'Add Consignment';

  @override
  String get itemName => 'Item Name';

  @override
  String get orderItems => 'Order Items';

  @override
  String get price => 'Price';

  @override
  String get quantity => 'Quantity';

  @override
  String get paymentStatus => 'Payment Status';

  @override
  String get paid => 'Paid';

  @override
  String get notPaid => 'Not Paid';

  @override
  String get packageType => 'Package Type';

  @override
  String get parcel => 'Parcel';

  @override
  String get consignment => 'Consignment';

  @override
  String get pleaseEnterPackageName => 'Please enter package name';

  @override
  String get packageNameMaxLength =>
      'Package name must be 100 characters or less';

  @override
  String get pleaseEnterSenderName => 'Please enter sender name';

  @override
  String get pleaseEnterCustomerName => 'Please enter customer name';

  @override
  String get senderNameMaxLength =>
      'Sender name must be 100 characters or less';

  @override
  String get customerNameMaxLength =>
      'Customer name must be 100 characters or less';

  @override
  String get pleaseEnterSenderPhone => 'Please enter sender phone number';

  @override
  String get pleaseEnterCustomerPhone => 'Please enter customer phone number';

  @override
  String get senderPhoneMaxLength =>
      'Sender phone number must be 15 characters or less';

  @override
  String get pleaseEnterOrigin => 'Please enter origin';

  @override
  String get originMaxLength => 'Origin name must be 100 characters or less';

  @override
  String get pleaseSelectOrigin => 'Please select an origin';

  @override
  String get pleaseSelectDestination => 'Please select a destination';

  @override
  String get pleaseEnterDestination => 'Please enter or select a destination';

  @override
  String get pleaseEnterReceiverName => 'Please enter receiver name';

  @override
  String get receiverNameMaxLength =>
      'Receiver name must be 100 characters or less';

  @override
  String get pleaseEnterReceiverPhone => 'Please enter receiver phone number';

  @override
  String get receiverPhoneMaxLength =>
      'Receiver phone number must be 15 characters or less';

  @override
  String get pleaseEnterPackageValue => 'Please enter package value';

  @override
  String get packageValueMaxLength =>
      'Package value must be 8 characters or less';

  @override
  String get pleaseEnterPaidAmount => 'Please enter Paid Amount';

  @override
  String get paidAmountMaxLength => 'Paid amount must be 8 characters or less';

  @override
  String get pleaseAddAtLeastOneItem => 'Please add at least one item';

  @override
  String get pleaseEnterItemName => 'Please enter item name';

  @override
  String get itemPriceGreaterThanZero => 'Item price must be greater than 0';

  @override
  String get itemQuantityGreaterThanZero =>
      'Number of items must be greater than 0';

  @override
  String get itemNamesCannotBeEmpty => 'Item name cannot be empty';

  @override
  String get itemNamesMaxLength => 'Item names must be 100 characters or less';

  @override
  String get itemNamesShouldBeDifferent => 'Item names should be different';

  @override
  String get originDestinationSame =>
      'Origin and destination cannot be the same location.';

  @override
  String get consignmentAddedSuccess => 'Package added successfully.';

  @override
  String get connectionError => 'Connection Error';

  @override
  String get couldNotConnectToServer =>
      'Could not connect to the server. Please check your internet connection.';

  @override
  String get qrCodeUnavailableTitle => 'QR Code Scanning Unavailable';

  @override
  String get qrCodeUnavailableMessage =>
      'This feature is only supported in the Tiketi Mkononi mobile app. Please download and open the application on your smartphone to scan QR codes';

  @override
  String get cancel => 'Cancel';

  @override
  String get installApp => 'Install App';

  @override
  String get moreOptions => 'More Options';

  @override
  String get reprintReceipt => 'Reprint Receipt';

  @override
  String get myReceipt => 'My Receipt';

  @override
  String get refreshPrinters => 'Refresh Printers';

  @override
  String printReceipts(Object count) {
    return 'Print $count Receipts';
  }

  @override
  String receiptsBalance(Object balance) {
    return 'Receipts Balance: $balance';
  }

  @override
  String cardsBalance(Object balance) {
    return 'Cards Balance: $balance';
  }

  @override
  String get topupReceipts => 'Topup Receipts';

  @override
  String get topupCards => 'Topup Cards';

  @override
  String get viewCards => 'View Cards';

  @override
  String get exit => 'Exit';

  @override
  String get selectPrinter => 'Select Printer';

  @override
  String get noPairedPrinterFound => 'No paired Bluetooth printer found';

  @override
  String foundPairedPrinters(Object count) {
    return 'Found $count paired Bluetooth printer';
  }

  @override
  String get printerNotConnected => 'Printer not connected';

  @override
  String get noPrintersFound => 'No printers found.';

  @override
  String get selectNumberOfReceipts => 'Select number of receipts';

  @override
  String get printOneReceipt => 'Print 1 receipt';

  @override
  String get printTwoReceipts => 'Print 2 receipts';

  @override
  String get parcelReceipt => 'PARCEL RECEIPT';

  @override
  String get consignmentReceipt => 'CONSIGNMENT RECEIPT';

  @override
  String packageNo(Object number) {
    return 'Package No: $number';
  }

  @override
  String packageNameLabel(Object name) {
    return 'Package Name: $name';
  }

  @override
  String packageValueLabel(Object value) {
    return 'Package Value: TZS $value';
  }

  @override
  String paymentStatusLabel(Object status) {
    return 'Payment Status: $status';
  }

  @override
  String paidAmountLabel(Object amount) {
    return 'Paid Amount: TZS $amount';
  }

  @override
  String get route => 'Route';

  @override
  String fromLabel(Object from) {
    return 'From: $from';
  }

  @override
  String toLabel(Object to) {
    return 'To: $to';
  }

  @override
  String get sender => 'Sender';

  @override
  String nameLabel(Object name) {
    return 'Name: $name';
  }

  @override
  String phoneLabel(Object phone) {
    return 'Phone: $phone';
  }

  @override
  String get receiver => 'Receiver';

  @override
  String get items => 'Items';

  @override
  String get issuedBy => 'Issued By';

  @override
  String get totalAmount => 'Total Amount';

  @override
  String get parcelInfo => 'PARCEL INFO';

  @override
  String get consignmentInfo => 'CONSIGNMENT INFO';

  @override
  String pkgNo(Object number) {
    return 'PKG No: $number';
  }

  @override
  String pkgName(Object name) {
    return 'PKG Name: $name';
  }

  @override
  String routeTo(Object from, Object to) {
    return '$from to $to';
  }

  @override
  String nameOnly(Object name) {
    return 'Name:$name';
  }

  @override
  String phoneOnly(Object phone) {
    return 'Phone:$phone';
  }

  @override
  String get poweredBy => 'Powered by Tiketi Mkononi';

  @override
  String get email => 'Email: tiketimkononi@telabs.co.tz';

  @override
  String get phoneNumber => 'Phone: +255 651 138 380';

  @override
  String requestFailed(Object statusCode) {
    return 'Request failed: $statusCode';
  }

  @override
  String get imageTooLarge => 'Image is Too Large';

  @override
  String error(Object error) {
    return 'Error: $error';
  }

  @override
  String get processingPayment => 'Processing payment!';

  @override
  String get paymentRequestSent => 'Ombi la malipo limetumwa';

  @override
  String get paymentFailed => 'Malipo yameshindwa';

  @override
  String get phoneNumberCannotBeEmpty => 'Phone number cannot be empty';

  @override
  String get choosePackage => 'Chagua kifurushi';

  @override
  String get paymentMethod => 'Njia ya Malipo';

  @override
  String get paymentPhoneNumber => 'Namba ya simu ya malipo';

  @override
  String get pay => 'Lipa';

  @override
  String receipts(Object count, Object price) {
    return 'Receipts $count - TSH $price';
  }

  @override
  String get connectionErrorMessage =>
      'Could not connect to the server. Please check your internet connection.';

  @override
  String get searchPackageOrSender => 'Search package or sender name...';

  @override
  String failedToLoadConsignments(Object statusCode) {
    return 'Failed to load consignments ($statusCode)';
  }

  @override
  String get networkError => 'Network error. Please check your connection.';

  @override
  String unexpectedError(Object error) {
    return 'Unexpected error occurred: $error';
  }

  @override
  String get unknown => 'Unknown';

  @override
  String get totalRevenue => 'Total Revenue';

  @override
  String get selectConsignmentToViewDetails =>
      'Select a consignment to view details';

  @override
  String get unnamedPackage => 'Unnamed Package';

  @override
  String get thankYou => 'Thank you';

  @override
  String get couldNotLaunchPhone => 'Could not launch phone app';

  @override
  String itemsCount(Object count) {
    return '$count items';
  }

  @override
  String get unnamedItem => 'Unnamed Item';

  @override
  String get packageInformation => 'Package Information';

  @override
  String get routeInformation => 'Route Information';

  @override
  String get senderDetails => 'Sender Details';

  @override
  String get receiverDetails => 'Receiver Details';

  @override
  String get parcelDetails => 'Parcel Details';

  @override
  String get consignmentDetails => 'Consignment Details';

  @override
  String get noConsignmentsYet => 'No Consignments Yet';

  @override
  String get consignmentsYouCreateWillAppearHere =>
      'Consignments you create will appear here';

  @override
  String get tryAgain => 'Try Again';

  @override
  String get add => 'Add';

  @override
  String get add2 => 'Add';

  @override
  String get search => 'Search';

  @override
  String get all => 'All';

  @override
  String get parcels => 'Parcels';

  @override
  String get consignments => 'Consignments';

  @override
  String get unpaid => 'Unpaid';

  @override
  String get exportUnpaid => 'Export Unpaid';

  @override
  String get exportPaid => 'Export Paid';

  @override
  String get exportAll => 'Export All';

  @override
  String get noPackagesFound => 'No packages found';

  @override
  String get packageNumber => 'Package Number';

  @override
  String get senderPhone => 'Sender Phone';

  @override
  String get receiverPhone => 'Receiver Phone';

  @override
  String get to2 => 'To';

  @override
  String get amountToBePaid => 'Amount to be Paid';

  @override
  String get isParcel => 'Is Parcel';

  @override
  String get issuerPhone => 'Issuer Phone';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String errorExportingToExcel(Object error) {
    return 'Error exporting to Excel: $error';
  }

  @override
  String get unpaidPackages => 'Unpaid_Packages';

  @override
  String get paidPackages => 'Paid_Packages';

  @override
  String get allPackages => 'All_Packages';

  @override
  String get selectConsignment => 'Select a consignment to view details';

  @override
  String get officeInformation => 'Office Information';

  @override
  String get addANewOfficeLocation =>
      'Add a new office location for your transport company.';

  @override
  String get officeName => 'Office Name';

  @override
  String get officeLocation => 'Office Location';

  @override
  String get pleaseEnterOfficeLocation => 'Please enter office location';

  @override
  String get addOffice => 'Add Office';

  @override
  String get myOffices => 'My Offices';

  @override
  String get pleaseEnterBusRegistrationNumber =>
      'Please enter bus registration number';

  @override
  String get pleaseEnterBusName => 'Please enter bus name';

  @override
  String get product => 'Product';

  @override
  String get products => 'Products';

  @override
  String get productName => 'Product name';

  @override
  String get pleaseEnterProductName => 'Please enter product name';

  @override
  String get noOrdersYet => 'No Orders Yet';

  @override
  String get yourOrdersWillAppearHere => 'Your orders will appear here';

  @override
  String get orderReceivedSuccessfully => 'Order received successfully';

  @override
  String get totalSales => 'Total Sales';

  @override
  String get save => 'Save';

  @override
  String get noProductsFound => 'No Products Found';

  @override
  String get productsYouAddWillAppearHere =>
      'Products you add will appear here';
}
