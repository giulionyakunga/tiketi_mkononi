import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/models/event.dart';
import 'package:tiketi_mkononi/models/ticket.dart';
import 'package:tiketi_mkononi/services/SimpleCodec.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math'; // Make sure you have this import
import 'package:permission_handler/permission_handler.dart';
import 'package:contacts_service_plus/contacts_service_plus.dart';
// import 'dart:html' as html; // only for web



final websocketServiceProvider = Provider<WebSocketService>((ref) {
  return WebSocketService();
});



class WebSocketService {
  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  Timer? _timeoutTimer;

  bool _isDisposed = false;
  bool _isConnected = false;
  bool _isConnecting = false;
  int _reconnectAttempts = 0;
  DateTime? _lastReceivedTime;

  final int maxReconnectAttempts = 1000;
  final Duration reconnectInterval = const Duration(seconds: 2);
  final Duration heartbeatInterval = const Duration(seconds: 15);
  final Duration connectionTimeout = const Duration(seconds: 10);
  final Duration pingTimeout = const Duration(seconds: 30);

  int? _ticketId;
  int? _scanStatus;
  bool _useDNS = true;

  late final StreamSubscription _connectivitySubscription;

  final _connectionStatusController = StreamController<bool>.broadcast(sync: true);
  final _ticketController = StreamController<Ticket>.broadcast(sync: true);

  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;
  Stream<Ticket> get ticketStream => _ticketController.stream;

  WebSocketService() {
    _listenToConnectivity();
  }

  /// 🔌 Listen to network changes
  void _listenToConnectivity() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) async {
      if (_isDisposed) return;

      final hasInternet = result != ConnectivityResult.none;
      debugPrint('🌐 Connectivity changed: $result (hasInternet: $hasInternet, _isDisposed: $_isDisposed, _isConnected: $_isConnected, _isConnecting: $_isConnecting)');
      
      debugPrint('🌐 Internet restored → attempting reconnection');
      _handleConnectionLost('Connectivity lost');
    

    
      // if (!hasInternet) {
      //   debugPrint('🌐 No Internet, hasInternet: $hasInternet');
      //   _handleConnectionLost('Connectivity lost');
      // } else {
      //   // Wait a moment for network to stabilize
      //   await Future.delayed(const Duration(seconds: 1));

      //   debugPrint('Internet restored → attempting reconnection 0');
        
      //   if (!_isConnected && !_isConnecting && _ticketId != null) {
      //     debugPrint('🌐 Internet restored → attempting reconnection');
      //     _cancelReconnection();
      //     _scheduleReconnection(_ticketId!, _scanStatus!, immediate: true);
      //   }
      // }
    });
  }

  /// 🔗 Connect with timeout
  Future<void> connect(
    int ticketId,
    int scanStatus, 
    { bool useDNS = true }
  ) async {

    debugPrint(' >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> _isDisposed : $_isDisposed');

    if (_isDisposed || scanStatus == 1) return;

    debugPrint(' >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> 22 _isDisposed : $_isDisposed');
    
    _ticketId = ticketId;
    _scanStatus = scanStatus;
    _useDNS = useDNS;
    _isConnecting = true;

    // Cancel any pending reconnection
    _cancelReconnection();

    try {
      final uri = Uri.parse(
        useDNS ? backend_ws_url : backend_ws_url_with_fallback_ip,
      );

      debugPrint('🔗 Connecting to: $uri');

      // Set connection timeout
      _timeoutTimer?.cancel();
      _timeoutTimer = Timer(connectionTimeout, () {
        if (_isConnecting) {
          debugPrint('⏰ Connection timeout');
          _handleConnectionLost('Connection timeout');
        }
      });

      // Close existing socket if any
      if(_isConnected){
        await _closeSocket();
      }

      // Create new connection
      _channel = WebSocketChannel.connect(uri);
      
      // Wait for connection with timeout
      await _channel!.ready.timeout(connectionTimeout);
      
      _timeoutTimer?.cancel();
      _isConnecting = false;
      
      _isConnected = true;
      _reconnectAttempts = 0;
      _lastReceivedTime = DateTime.now();
      
      debugPrint('✅ WebSocket connected successfully');
      _connectionStatusController.add(true);
      _cancelReconnection();

      _startHeartbeat();

      // Send subscription message
      _channel!.sink.add(jsonEncode({
        "ticket_id": ticketId,
        "scan_status": scanStatus,
        "type": "subscribe",
        "data": "ticket",
      }));

      // Listen for messages
      _channel!.stream.listen(
        (message) => _handleIncomingMessage(message),
        onError: (error) {
          debugPrint('❌ WebSocket error: $error');
          _handleConnectionLost('WebSocket error: $error');
        },
        onDone: () {
          debugPrint('🔌 WebSocket connection closed');
          _handleConnectionLost('Connection closed by server');
        },
        cancelOnError: true,
      );

    } on WebSocketChannelException catch (e) {
      debugPrint('Network error occurred:');
      debugPrint('- Exception type: ${e.runtimeType}');
      debugPrint('- Message: ${e.message}');

      final inner = e.inner;

      if (inner is SocketException) {
        final osError = inner.osError;

        if (osError != null) {
          debugPrint('  - Error number (errno): ${osError.errorCode}');
          debugPrint('  - OS message: ${osError.message}');
          debugPrint('  - errorCode: ${osError.errorCode}');
          debugPrint('  - useDNS: $useDNS');

          // DNS failure (Windows: 11001, Linux/macOS: 7)
          if ((osError.errorCode == 11001 || osError.errorCode == 7) && useDNS) {
            debugPrint('DNS failed! Retrying with IP: $backend_url_with_fallback_ip...');
            await connect(ticketId, scanStatus, useDNS: false); // Recursive retry

            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('use_dns', false);
            return;
          }
        }
      }
    } on SocketException catch (e) {
      debugPrint('Network error occurred:');
      debugPrint('- Exception type: ${e.runtimeType}');
      debugPrint('- Message: ${e.message}');
      
      if (e.osError != null) {
        debugPrint('  - Error number (errno): ${e.osError!.errorCode}');
        debugPrint('  - OS message: ${e.osError!.message}');
        debugPrint('  - errorCode: ${e.osError!.errorCode}');
        debugPrint('  - useDNS: ${useDNS}');

        // Retry with IP if DNS fails (errno = 7) and not already retrying
        if ((e.osError!.errorCode == 11001 || e.osError!.errorCode == 7) && useDNS) {
          debugPrint('DNS failed! Retrying with IP: ${backend_url_with_fallback_ip}...');
          await connect(ticketId, scanStatus, useDNS: false); // Recursive retry

          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('use_dns', false);
          return;
        }
      }
    } catch (e) {
      _timeoutTimer?.cancel();
      _isConnecting = false;
      debugPrint('❌ Connect error: $e');
      _handleConnectionLost('Connect error: $e');
    }
  }

  /// ❤️ Heartbeat with timeout detection
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(heartbeatInterval, (_) {
      if (!_isConnected) return;

      // Check if we haven't received anything in too long
      if (_lastReceivedTime != null && 
        DateTime.now().difference(_lastReceivedTime!) > pingTimeout) {
        debugPrint('⏰ No response for ${pingTimeout.inSeconds}s, assuming dead connection');
        return;
      }

      try {
        debugPrint('❤️ Sending ping');
        _channel?.sink.add(jsonEncode({"type": "ping"}));
      } catch (_) {
        _handleConnectionLost('Heartbeat failed');
      }
    });
  }

  /// 📩 Incoming messages
  void _handleIncomingMessage(dynamic message) {
    _lastReceivedTime = DateTime.now();
    
    try {
      final data = jsonDecode(message);
      debugPrint('📥 Received: ${data['type']}');
      
      if (data['type'] == 'pong') {
        debugPrint('❤️ Received pong');
        return;
      }
      
      if (data['type'] == 'ticket') {
        _ticketController.add(Ticket.fromJson(data['ticket']));
      }
    } catch (e) {
      debugPrint('⚠️ Parse error: $e');
    }
  }

  /// ❌ Connection lost handler
  void _handleConnectionLost(String reason) {
    if (_isDisposed) return;
    
    debugPrint('❌ WebSocket disconnected: $reason');
    
    // Don't spam the controller
    if (_isConnected) {
      _isConnected = false;
      _connectionStatusController.add(false);
    }
    
    _isConnecting = false;
    _closeSocket();

    debugPrint(' Ticket Status: _ticketId : $_ticketId, _scanStatus: $_scanStatus');
    
    // Schedule reconnection if we have active ticket
    if (_ticketId != null && _scanStatus != null) {
      debugPrint('Here hcl2');
      _scheduleReconnection(_ticketId!, _scanStatus!);
      debugPrint('Here hcl3');
    }else {
      debugPrint('Here hcl4');
    }
  }



void _scheduleReconnection(
  int ticketId,
  int scanStatus,
  { bool immediate = false }
) {
  if (_isDisposed || 
      _reconnectAttempts >= maxReconnectAttempts ||
      _isConnecting ||
      _isConnected) {
    return;
  }

  _reconnectAttempts++;
  
  // Exponential backoff with jitter
  final baseDelay = immediate ? 1 : _reconnectAttempts * 2;
  final delay = Duration(seconds: baseDelay.clamp(1, 60));
  
  // Add some jitter to prevent thundering herd
  final jitter = Random().nextInt(2000) - 1000; // -1000 to +1000 ms
  final jitteredMilliseconds = delay.inMilliseconds + jitter;
  
  // Ensure minimum delay of 100ms
  final finalMilliseconds = jitteredMilliseconds.clamp(100, 60000);
  
  debugPrint('🔁 Reconnecting in ${finalMilliseconds ~/ 1000}s (attempt $_reconnectAttempts/$maxReconnectAttempts)');
  debugPrint('🔁 Reconnecting _isDisposed: ${_isDisposed}, _isConnected: ${_isConnected}, _isConnecting: ${_isConnecting}');

  _reconnectTimer?.cancel();
  _reconnectTimer = Timer(Duration(milliseconds: 1000), () {
    if (!_isDisposed && !_isConnected && !_isConnecting) {
      connect(ticketId, scanStatus, useDNS: _useDNS);
    }
  });
}

  /// ✋ Cancel pending reconnection
  void _cancelReconnection() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
  }

  /// 🔒 Close socket safely
  Future<void> _closeSocket() async {
    // debugPrint('Here c1');
    _heartbeatTimer?.cancel();
    // debugPrint('Here c2');
    _heartbeatTimer = null;
    // debugPrint('Here c3');
    
    _timeoutTimer?.cancel();
    // debugPrint('Here c4');
    _timeoutTimer = null;
    // debugPrint('Here c5');
    
    try {
      // debugPrint('Here c6');
      await _channel?.sink.close(1000);
      // await _channel?.sink.close(1000, 'Normal closure');
      // debugPrint('Here c7');
    } catch (e) {
      // debugPrint('⚠️ Error closing socket: $e');
    } finally {
      _channel = null;
    }
  }

  /// 🔄 Manual reconnect
  Future<void> reconnect() async {
    // debugPrint('🔄 Manual reconnect requested');
    _cancelReconnection();
    _reconnectAttempts = 0;
    
    if (_ticketId != null && _scanStatus != null) {
      await connect(_ticketId!, _scanStatus!, useDNS: _useDNS);
    }
  }

  /// ⛔ Manual disconnect (temporary)
  void disconnect() {
    debugPrint('⛔ Manual disconnecting'); 
    _isConnected = false;
    _isConnecting = false;
    _cancelReconnection();
    _closeSocket();
    _connectionStatusController.add(false);
  }

  /// 📊 Get connection status
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  int get reconnectAttempts => _reconnectAttempts;

  /// 🧹 Final cleanup
  void dispose() {
    debugPrint('🧹 Disposing WebSocketService');
    _isDisposed = true;
    disconnect();
    _connectivitySubscription.cancel();
    _ticketController.close();
    _connectionStatusController.close();
  }
}

class TicketQRPage extends ConsumerStatefulWidget {
  final Ticket ticket;
  final Event? event; // ← nullable

  const TicketQRPage({
    super.key,
    required this.ticket,
    this.event,
  });

  @override
  ConsumerState<TicketQRPage> createState() => _TicketQRPageState();
}

class _TicketQRPageState extends ConsumerState<TicketQRPage>  with WidgetsBindingObserver {
  late final WebSocketService _webSocketService;
  late DateTime scannedAt;
  late int scanStatus2;
  bool _isTicketScanned = false;
  bool _isCardGenerated = false;
  String cardFilePath = '';
  Printer? selectedPrinter;
  late OverlayConfig config;
  bool _isAppActive = false;
  bool _isContactSaved = false;
  String contactName = '';
  Uint8List? _webImageBytes;
  bool _isLoading = false;
  bool isWhatsappSent = false;
  Iterable<Contact> contactsList = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    config = const OverlayConfig(
      qrOffset: Offset(40, 40),
      textOffset: Offset(40, 260),
      qrSize: 160,
    );
    _loadPrefs();

    scanStatus2 = widget.ticket.scanStatus;
    scannedAt = widget.ticket.updatedAt;
    isWhatsappSent = widget.ticket.whatsappSent;

    if (widget.ticket.scanStatus != 1) {
      _webSocketService = ref.read(websocketServiceProvider);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _webSocketService.connect(
          widget.ticket.id,
          widget.ticket.scanStatus,
        );
      });
    }

    _loadSelectedPrinter();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() {
      _isAppActive = state == AppLifecycleState.resumed;
    });
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      config = OverlayConfig(
        qrOffset: Offset(
          (p.getDouble('qrOffsetDx') ?? 0.1).clamp(0.1, 1.0),
          (p.getDouble('qrOffsetDy') ?? 0.1).clamp(0.1, 1.0),
        ),
        textOffset: Offset(
          (p.getDouble('textOffsetDx') ?? 0.1).clamp(0.1, 1.0),
          (p.getDouble('textOffsetDy') ?? 0.1).clamp(0.1, 1.0),
        ),
        qrSize: (p.getDouble('qrSize') ?? 0.1).clamp(0.1, 1.0),
      );
    });

    if(widget.event!.category.toUpperCase() == "WEDDING") {
      _generateImageWithQr();
    }

    await loadContacts();

  }

  Future<bool> requestContactsPermission() async {
    var status = await Permission.contacts.status;
    if (!status.isGranted) {
      status = await Permission.contacts.request();
    }
    return status.isGranted;
  }
  
  Future<void> loadContacts() async {
    bool granted = await requestContactsPermission();
    if (!granted) {
      debugPrint("Permission denied");
      _showSnackBar("Permission denied");
      return;
    }

    // Get all existing contacts
    Iterable<Contact> contacts = await ContactsService.getContacts(withThumbnails: false);

    setState(() {
      contactsList = contacts;
    });
  }

  Future<void> addContactUnique(String givenName, String phoneNumber) async {
    bool granted = await requestContactsPermission();
    if (!granted) {
      debugPrint("Permission denied");
      _showSnackBar("Permission denied");
      return;
    }

    if(contactsList.isEmpty) {
      await loadContacts();
    }
    
    // Check if phone number already exists
    Contact? matchingContact;

    for (final c in contactsList) {
      if (c.phones != null && c.phones!.any((p) => p.value == phoneNumber)) {
        matchingContact = c;
        break;
      }
    }

    if (matchingContact != null) {
      print('Phone belongs to: ${matchingContact.displayName}');

      setState(() {
        contactName = matchingContact!.displayName!;
        _isContactSaved = true;
      });

      debugPrint("Contact '${matchingContact.displayName}' already exists!");
      _showSnackBar("Contact '${matchingContact.displayName}' already exists!");
      return;
    }

    Contact newContact = Contact(
      givenName: givenName,
      phones: [Item(label: "mobile", value: phoneNumber)],
    );

    await ContactsService.addContact(newContact);

    setState(() {
      contactName = givenName;
      _isContactSaved = true;
    });
    
    debugPrint("Contact saved as : $givenName");
    _showSnackBar("Contact saved as : $givenName");
  }

  String generateContactName(String eventName, String ticketId, { int maxWords = 3 }) {
    final ignoreWords = {
      'ya', 'na', 'and', 'of', 'the', '&', 'a', 'an'
    };

    // Normalize
    final words = eventName
        .replaceAll(RegExp(r'[^\w\s]'), '') // remove symbols
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map((word) => word.toLowerCase())
        .where((word) => !ignoreWords.contains(word))
        .toList();

    final buffer = StringBuffer();

    for (var i = 0; i < words.length && buffer.length < maxWords; i++) {
      buffer.write(words[i][0]);
    }
    String contactName = buffer.toString().toUpperCase() + '$ticketId';
    return contactName;
  }

  Future<void> _updateTicketSmsSentStatus(int ticketId, int eventId, {bool useDNS = true}) async {
    debugPrint(' >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> _updateTicketSmsSentStatus');

    final Uri uri = useDNS ? Uri.parse('${backend_url}api/update_ticket_sms_sent_status/$eventId/$ticketId')
    : Uri.parse('${backend_url_with_fallback_ip}update_ticket_confirm_status/$eventId/$ticketId');

    try {
      final response = await http.get(uri);
      debugPrint(' rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr ${response.body}');
    } on SocketException catch (e) {
      debugPrint('Network error occurred:');
      debugPrint('- Exception type: ${e.runtimeType}');
      debugPrint('- Message: ${e.message}');
      
      if (e.osError != null) {
        debugPrint('  - Error number (errno): ${e.osError!.errorCode}');
        debugPrint('  - OS message: ${e.osError!.message}');
        debugPrint('  - errorCode: ${e.osError!.errorCode}');
        debugPrint('  - useDNS: ${useDNS}');

        // Retry with IP if DNS fails (errno = 7) and not already retrying
        if ((e.osError!.errorCode == 11001 || e.osError!.errorCode == 7) && useDNS) {
          debugPrint('DNS failed! Retrying with IP: ${backend_url_with_fallback_ip}...');
          await _updateTicketSmsSentStatus(ticketId, eventId, useDNS: false); // Recursive retry

          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('use_dns', false);
          return;
        }
      }
    } catch (e) {
      debugPrint('Error fetching tickets: $e');
    }
  }

  Future<void> _updateTicketWhatsappSentStatus(int ticketId, int eventId, {bool useDNS = true}) async {
    debugPrint(' >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> _updateTicketWhatsappSentStatus');

    final Uri uri = useDNS ? Uri.parse('${backend_url}api/update_ticket_whatsapp_sent_status/$eventId/$ticketId')
    : Uri.parse('${backend_url_with_fallback_ip}update_ticket_whatsapp_sent_status/$eventId/$ticketId');

    try {
      final response = await http.get(uri);
      debugPrint(' rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr ${response.body}');
      setState(() {
        isWhatsappSent = true;
      });
    } on SocketException catch (e) {
      debugPrint('Network error occurred:');
      debugPrint('- Exception type: ${e.runtimeType}');
      debugPrint('- Message: ${e.message}');
      
      if (e.osError != null) {
        debugPrint('  - Error number (errno): ${e.osError!.errorCode}');
        debugPrint('  - OS message: ${e.osError!.message}');
        debugPrint('  - errorCode: ${e.osError!.errorCode}');
        debugPrint('  - useDNS: ${useDNS}');

        // Retry with IP if DNS fails (errno = 7) and not already retrying
        if ((e.osError!.errorCode == 11001 || e.osError!.errorCode == 7) && useDNS) {
          debugPrint('DNS failed! Retrying with IP: ${backend_url_with_fallback_ip}...');
          await _updateTicketSmsSentStatus(ticketId, eventId, useDNS: false); // Recursive retry

          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('use_dns', false);
          return;
        }
      }
    } catch (e) {
      debugPrint('Error fetching tickets: $e');
    }
  }

  Future<void> _generateImageWithQr() async {
    try {
      if (widget.event == null) return;

      final path = await ImageQrService.generateImageWithQr(
        ticket: widget.ticket,
        event: widget.event!,
        config: config,
      );

      if (kIsWeb) {
        setState(() {
          _webImageBytes = ImageQrService._webImageBytes;
        });
      }

      if (!mounted) return;

      setState(() {
        cardFilePath = path;
        _isCardGenerated = true;
      });
    } on PathNotFoundException catch (e) {
      debugPrint(' >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> Cache cleanup skipped (file already missing)');
      debugPrint('Path: ${e.path}');
      debugPrint('OS error: ${e.osError}');
    } catch (e) {
      debugPrint(' >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> 11 cardFilePath : $cardFilePath');
      debugPrint(' >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> 11 Error sharing image: $e');

      if (!mounted) return;

      setState(() {
        _isCardGenerated = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing image: $e')),
      );
    }
  }

  Future<void> _loadSelectedPrinter() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? url = prefs.getString('selected_printer_url');
    String? name = prefs.getString('selected_printer_name');

    if (url != null && name != null) {
      setState(() {
        selectedPrinter = Printer(url: url, name: name);
      });
    }
  }

  Future<void> _saveSelectedPrinter(Printer printer) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_printer_url', printer.url);
    await prefs.setString('selected_printer_name', printer.name);
    setState(() {
      selectedPrinter = printer;
    });
  }

  Future<void> _refreshPrinters() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove("selected_printer_url");
    await prefs.remove("selected_printer_name");

    setState(() {
      selectedPrinter = null;
    });

    await _selectPrinterDialog(); // fallback
  }
  
  Future<void> _selectPrinterDialog() async {
    final printers = await Printing.listPrinters();

    if (printers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No printers found.')),
      );
      return;
    }

    Printer? selected;

    await showDialog(
      context: context,
      builder: (context) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isSmallScreen = constraints.maxWidth < 400;
            final dialogWidth = isSmallScreen ? constraints.maxWidth * 0.9 : 400.0;

            return AlertDialog(
              contentPadding: EdgeInsets.all(20),
              title: Text("Select a printer"),
              content: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: dialogWidth),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: printers
                        .map(
                          (printer) => ListTile(
                            title: Text(printer.name),
                            subtitle: Text(printer.url),
                            onTap: () {
                              selected = printer;
                              Navigator.of(context).pop();
                            },
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (selected != null) {
      // Save selected printer
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('selectedPrinterUrl', selected!.url);
      _saveSelectedPrinter(selected!);
      selectedPrinter = selected;    
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _webSocketService.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void disconnectWebSocketService() {
    _webSocketService.disconnect();
  }

  bool _isLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.width > 768;
  }

  String formatTo24HourManual(DateTime dateTime) {
    final localTime = dateTime.toLocal();
    final weekday = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'][localTime.weekday-1];
    final month = ['January','February','March','April','May','June','July','August','September','October','November','December'][localTime.month-1];
    
    return '$weekday, $month ${localTime.day}, ${localTime.year} - '
          '${localTime.hour.toString().padLeft(2,'0')}:'
          '${localTime.minute.toString().padLeft(2,'0')}';
  }

  String _formatDate(String date) {
    final DateFormat inputFormat = DateFormat('dd-MM-yyyy');
    final DateTime dateTime = inputFormat.parse(date);
    final DateFormat outputFormat = DateFormat('EEEE, MMMM d, yyyy');
    return outputFormat.format(dateTime);
  }

  Widget _buildQRCodeSection(bool isLargeScreen) {
    String data = SimpleCodec.encode(jsonEncode({
      "tid": widget.ticket.id,
      "eid": widget.ticket.eventId,
      "dt": widget.ticket.date,
    }));
    return QrImageView(
      data: data,
      version: QrVersions.auto,
      size: isLargeScreen ? 300.0 : 200.0,
    );
  }

  Widget _buildEventInfoSection(bool isLargeScreen) {
    return Column(
      children: [
        Text(
          widget.ticket.eventName,
          style: TextStyle(
            fontSize: isLargeScreen ? 28 : 18,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.orange[800],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            widget.ticket.ticketType,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 4),
        Text(
            widget.ticket.userName,
            style: TextStyle(
              fontSize: isLargeScreen ? 20 : 14,
              fontWeight: FontWeight.bold,
            ),
        ),
        const SizedBox(height: 4),
        Text(
            !_isContactSaved ? widget.ticket.userPhoneNumber : contactName,
            style: TextStyle(
              fontSize: isLargeScreen ? 20 : 14,
              fontWeight: FontWeight.normal,
            ),
        ),
        const SizedBox(height: 8),
        if (widget.event != null)
        Center(
          child: Wrap(
          spacing: 16,
            children: [
              TextButton(
                onPressed: () => _shareCardCode(),
                style: TextButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: EdgeInsets.zero,  // Removed vertical padding
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Icon(
                  Icons.sms,
                  size: 40,
                  color: Colors.blue
                ),
              ),
              TextButton(
                onPressed: () => addContactUnique(generateContactName(widget.ticket.eventName, widget.ticket.userPhoneNumber), widget.ticket.userPhoneNumber),
                style: TextButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: EdgeInsets.zero,  // Removed vertical padding
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Icon(
                  Icons.save_alt,
                  size: 40,
                  color: Colors.red
                ),
              ),


              TextButton(
                onPressed: () => _launchPhoneCall(widget.ticket.userPhoneNumber),
                style: TextButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: EdgeInsets.zero,  // Removed vertical padding
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Icon(
                  Icons.phone,
                  size: 40,
                  color: Colors.green
                ),
              ),
            ]
          )
        ),
        const SizedBox(height: 8),
        Text(
            (widget.ticket.price > 0.0) ? 'TSH${NumberFormat('#,##0').format(widget.ticket.price.toInt())}' : 'Free',
            style: TextStyle(fontSize: isLargeScreen ? 20 : 14),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: isLargeScreen ? 24 : 16),
            const SizedBox(width: 8),
            Text(
              _formatDate(widget.ticket.date),
              style: TextStyle(fontSize: isLargeScreen ? 20 : 14),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.access_time, size: isLargeScreen ? 24 : 16),
            const SizedBox(width: 8),
            Text(
              widget.ticket.time,
              style: TextStyle(fontSize: isLargeScreen ? 20 : 14),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                widget.ticket.venue,
                style: TextStyle(fontSize: isLargeScreen ? 20 : 14),
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _isTicketScanned || scanStatus2 == 1
            ? Text(
                'Used On : ${formatTo24HourManual(scannedAt)}',
                style: TextStyle(fontSize: isLargeScreen ? 20 : 14),
              )
            : Text(
                'Present this QR code at the venue',
                style: TextStyle(
                  fontSize: isLargeScreen ? 16 : 14,
                  color: Colors.grey,
                ),
              )
      ],
    );
  }

  Widget _buildStatusSection() {
    if (widget.ticket.scanStatus == 1 || _isTicketScanned) {
      return Column(
        children: [
          const SizedBox(height: 10),
          Icon(
            Icons.check_circle,
            size: 80,
            color: _isTicketScanned ? Colors.green : Colors.orange[800],
          ),
          const SizedBox(height: 4),
          Text(
            _isTicketScanned ? "Ticket Scanned Successfully!" : "Ticket Already Used",
            style: TextStyle(
              fontSize: _isTicketScanned ? 15 : 18,
              fontWeight: FontWeight.bold,
              color: _isTicketScanned ? Colors.green : Colors.black,
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        const SizedBox(height: 8),
        StreamBuilder<bool>(
          stream: _webSocketService.connectionStatusStream,
          builder: (context, snapshot) {
            bool isConnected = snapshot.data ?? false;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isConnected 
                          ? Colors.green.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isConnected 
                            ? Colors.green.withOpacity(0.3)
                            : Colors.red.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Pulsing dot
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isConnected ? Colors.green : Colors.red,
                          ),
                        ),
                        // Status text
                        Text(
                          isConnected ? '✓ Connected' : '✗ Disconnected',
                          style: TextStyle(
                            color: isConnected ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        StreamBuilder<Ticket>(
          stream: _webSocketService.ticketStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: Text(
                  'Waiting for scanner...',
                  style: TextStyle(fontSize: 14),
                ),
              );
            }

            final ticket = snapshot.data!;
            if (ticket.scanStatus == 1 && widget.ticket.id == ticket.id) {
              // Use a post-frame callback to update state after build
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!_isTicketScanned) {
                  setState(() {
                    scanStatus2 = ticket.scanStatus;
                    scannedAt = ticket.updatedAt;
                    _isTicketScanned = true;
                  });
                  disconnectWebSocketService();
                }
              });
            }
            return const Text(
              'Ready to scan',
              style: TextStyle(fontSize: 16),
            );
          },
        ),
      ],
    );
  }

  Future<void> _printTicket() async {
    final pdf = pw.Document();
    
    // Load logo
    final logoData = await rootBundle.load('assets/telabs_logo.png');
    final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());

    // Load custom font
    final fontData = await rootBundle.load('assets/fonts/\poppins/Poppins-Regular.ttf');
    final customFont = pw.Font.ttf(fontData);

    // Receipt width: 80mm = ~226 points, height is auto
    const pageWidth = 140.0;
    const pageHeight = 700.0;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(pageWidth, pageHeight), // ~80mm width, tall height
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.SizedBox(height: 10),
                // Logo
                pw.Image(logoImage, width: 80, height: 80),
                pw.SizedBox(height: 4),
                pw.Text('Tanzania Electronics Labs Co, Ltd', style: pw.TextStyle(font: customFont, fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.Text('Tiketi Mkononi', style: pw.TextStyle(font: customFont, fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.Text('Phone: +255 672 120 941/+255 684 444 997', style: pw.TextStyle(font: customFont, fontSize: 9)),
                pw.Text('Email: tiketimkononi@telabs.co.tz', style: pw.TextStyle(font: customFont, fontSize: 9)),
                pw.Text('Location: Uganda Street, Kijitonyama, Dar es Salaam', style: pw.TextStyle(font: customFont, fontSize: 9)),
                pw.Divider(),

                // Ticket contents
                pw.Text(
                  widget.ticket.eventName,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 10),
                pw.Text("Ticket ID: ${widget.ticket.id}", textAlign: pw.TextAlign.center, style: pw.TextStyle(font: customFont, fontSize: 11)),
                pw.Text("Name: ${widget.ticket.userName}", textAlign: pw.TextAlign.center, style: pw.TextStyle(font: customFont, fontSize: 11)),
                pw.Text("Date: ${widget.ticket.date}", textAlign: pw.TextAlign.center, style: pw.TextStyle(font: customFont, fontSize: 11)),
                pw.Text("Time: ${widget.ticket.time}", textAlign: pw.TextAlign.center, style: pw.TextStyle(font: customFont, fontSize: 11)),
                pw.Text("Venue: ${widget.ticket.venue}", textAlign: pw.TextAlign.center, style: pw.TextStyle(font: customFont, fontSize: 11)),
                pw.Text("Ticket Type: ${widget.ticket.ticketType}", textAlign: pw.TextAlign.center, style: pw.TextStyle(font: customFont, fontSize: 11)),
                pw.Text("Seat: ${widget.ticket.seatNumber}", textAlign: pw.TextAlign.center, style: pw.TextStyle(font: customFont, fontSize: 11)),
                pw.Text(
                  "Price: ${(widget.ticket.price > 0) ? 'TSH ${widget.ticket.price.toInt()}' : 'Free'}",
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: customFont, fontSize: 11)
                ),
                pw.SizedBox(height: 12),

                // QR code
                pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: SimpleCodec.encode(jsonEncode({
                    "tid": widget.ticket.id,
                    "eid": widget.ticket.eventId,
                    "dt": widget.ticket.date,
                  })),
                  width: 120,
                  height: 120,
                ),
                pw.SizedBox(height: 10),
                pw.Text("Ahsante!", style: pw.TextStyle(fontSize: 14)),

                pw.SizedBox(height: 16),
                pw.Text(
                  'Product of TELabs',
                  style: pw.TextStyle(font: customFont, fontSize: 12, fontWeight: pw.FontWeight.bold)
                ),
                pw.SizedBox(height: 10),
                pw.Text(""),
              ],
            ),
          );
        },
      ),
    );

    // Save to local file
    final outputDir = await getApplicationDocumentsDirectory();
    final filePath = '${outputDir.path}/ticket_${widget.ticket.id}.pdf';
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Oops! Ticket saved at ${filePath}")),
    );

    // Open print dialog
    // await Printing.layoutPdf(onLayout: (format) => pdf.save());

    if (selectedPrinter != null) {
      await Printing.directPrintPdf(
        printer: selectedPrinter!,
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } else {
      await _selectPrinterDialog(); // fallback
    }

    await file.delete();
  }

  Future<void> _shareTicket() async {
    final pdf = pw.Document();
    
    // Load logo
    final logoData = await rootBundle.load('assets/telabs_logo.png');
    final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());

    // Load custom font
    final fontData = await rootBundle.load('assets/fonts/\poppins/Poppins-Regular.ttf');
    final customFont = pw.Font.ttf(fontData);

    // Receipt width: 80mm = ~226 points, height is auto
    const pageWidth = 260.0;
    const pageHeight = 650.0;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(pageWidth, pageHeight), // ~80mm width, tall height
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.SizedBox(height: 10),
                // Logo
                pw.Image(logoImage, width: 80, height: 80),
                pw.SizedBox(height: 4),
                pw.Text('Tanzania Electronics Labs Co, Ltd', style: pw.TextStyle(font: customFont, fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.Text('Tiketi Mkononi', style: pw.TextStyle(font: customFont, fontSize: 13, fontWeight: pw.FontWeight.bold)),
                pw.Text('Phone: +255 672 120 941/+255 684 444 997', style: pw.TextStyle(font: customFont, fontSize: 9)),
                pw.Text('Email: tiketimkononi@telabs.co.tz', style: pw.TextStyle(font: customFont, fontSize: 9)),
                pw.Text('Location: Uganda Street, Kijitonyama, Dar es Salaam', style: pw.TextStyle(font: customFont, fontSize: 9)),
                pw.Divider(),

                // Ticket contents
                pw.Text(
                  widget.ticket.eventName,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 10),
                pw.Text("Ticket ID: ${widget.ticket.id}", textAlign: pw.TextAlign.center, style: pw.TextStyle(font: customFont, fontSize: 11)),
                pw.Text("Name: ${widget.ticket.userName}", textAlign: pw.TextAlign.center, style: pw.TextStyle(font: customFont, fontSize: 11)),
                pw.Text("Date: ${widget.ticket.date}", textAlign: pw.TextAlign.center, style: pw.TextStyle(font: customFont, fontSize: 11)),
                pw.Text("Time: ${widget.ticket.time}", textAlign: pw.TextAlign.center, style: pw.TextStyle(font: customFont, fontSize: 11)),
                pw.Text("Venue: ${widget.ticket.venue}", textAlign: pw.TextAlign.center, style: pw.TextStyle(font: customFont, fontSize: 11)),
                pw.Text("Ticket Type: ${widget.ticket.ticketType}", textAlign: pw.TextAlign.center, style: pw.TextStyle(font: customFont, fontSize: 11)),
                pw.Text("Seat: ${widget.ticket.seatNumber}", textAlign: pw.TextAlign.center, style: pw.TextStyle(font: customFont, fontSize: 11)),
                pw.Text(
                  "Price: ${(widget.ticket.price > 0) ? 'TSH ${widget.ticket.price.toInt()}' : 'Free'}",
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: customFont, fontSize: 11)
                ),
                pw.SizedBox(height: 12),

                // QR code
                pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: SimpleCodec.encode(jsonEncode({
                    "tid": widget.ticket.id,
                    "eid": widget.ticket.eventId,
                    "dt": widget.ticket.date,
                  })),
                  width: 120,
                  height: 120,
                ),
                pw.SizedBox(height: 10),
                pw.Text("Ahsante!", style: pw.TextStyle(fontSize: 14)),

                pw.SizedBox(height: 16),
                pw.Text(
                  'Product of TELabs',
                  style: pw.TextStyle(font: customFont, fontSize: 12, fontWeight: pw.FontWeight.bold)
                ),
                pw.SizedBox(height: 10),
              ],
            ),
          );
        },
      ),
    );

    if (Platform.isWindows) {
       // Save to local file
      final outputDir = await getApplicationDocumentsDirectory();
      final filePath = '${outputDir.path}/ticket_${widget.ticket.id}.pdf';
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Ticket saved at ${filePath}")),
      );

    } else if (kIsWeb) {
      // Web: download file in browser
      // final fileBytes = await pdf.save();
      // final blob = html.Blob([fileBytes]);
      // final url = html.Url.createObjectUrlFromBlob(blob);
      // html.AnchorElement(href: url)
      //   ..setAttribute('download', 'ticket_${widget.ticketId}.pdf')
      //   ..click();
      // html.Url.revokeObjectUrl(url);

      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text("Dowloading Ticket...")),
      // );
    }else {
      // Save to local file
      final outputDir = await getApplicationDocumentsDirectory();
      final filePath = '${outputDir.path}/ticket_${widget.ticket.id}.pdf';
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      // Share via WhatsApp/Email/etc
      await Share.shareXFiles(
        // [XFile(filePath)],
        [XFile(filePath, mimeType: 'application/pdf')],
        text: 'Here is your ticket for ${widget.ticket.eventName}!',
      );

      await file.delete();
    }
  }

  String getTimeOfDay(String time24) {
    // Parse "HH:mm"
    final parts = time24.split(':');
    if (parts.length != 2) return "Invalid time format";

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    // Validate
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 || 
        minute < 0 ||
        minute > 59) {
      return "Invalid time format";
    }

    // Determine time of day
    if (hour >= 5 && hour < 12) {
      return "Asubuhi"; // Morning
    } else if (hour >= 12 && hour < 17) {
      return "Mchana"; // Afternoon
    } else if (hour >= 17 && hour < 21) {
      return "Jioni"; // Evening
    } else {
      return "Usiku"; // Night (21:00–04:59)
    }
  }

  Future<void> _shareCard() async {
    _updateTicketWhatsappSentStatus(widget.ticket.id, widget.event!.id);

    String text = ""; 
    String extraInfoText = (widget.ticket.extraInfo.trim().isNotEmpty) ? ' ${widget.ticket.extraInfo}' : '';

    if (widget.ticket.venue.toLowerCase().contains('nyumbani')) {
      text = "Habari ${widget.ticket.userName},\nUmealikwa kwenye sherehe ya ${widget.ticket.eventName}, Itakayofanyika tarehe ${widget.ticket.date}, ${widget.ticket.venue}, kuanzia saa ${widget.ticket.time} ${getTimeOfDay(widget.ticket.time)}. Hii ni kadi yako. Fika nayo siku ya tukio. Namba ya kadi yako ni: ${widget.ticket.ticketCode} (${widget.ticket.ticketType})${extraInfoText}.\nBofya kiungo hiki kuthibitisha uwepo wako -> https://tiketimkononi.telabs.co.tz/confirm/attendance/${widget.ticket.eventId}/${widget.ticket.ticketCode}\nKiungo cha mahali -> ${widget.ticket.locationLink}\nKwa msaada piga namba ${widget.event!.organizerPhoneNumber}.\n#TiketiMkononi, #SimuYakoTiketiYako";
    } else {
      text = "Habari ${widget.ticket.userName},\nUmealikwa kwenye sherehe ya ${widget.ticket.eventName}, Itakayofanyika tarehe ${widget.ticket.date}, katika ukumbi wa ${widget.ticket.venue}, kuanzia saa ${widget.ticket.time} ${getTimeOfDay(widget.ticket.time)}. Hii ni kadi yako. Fika nayo siku ya tukio. Namba ya kadi yako ni: ${widget.ticket.ticketCode} (${widget.ticket.ticketType})${extraInfoText}.\nBofya kiungo hiki kuthibitisha uwepo wako -> https://tiketimkononi.telabs.co.tz/confirm/attendance/${widget.ticket.eventId}/${widget.ticket.ticketCode}\nKiungo cha mahali -> ${widget.ticket.locationLink}\nKwa msaada piga namba ${widget.event!.organizerPhoneNumber}.\n#TiketiMkononi, #SimuYakoTiketiYako";
    }

    // await Clipboard.setData(ClipboardData(text: text));
    await Clipboard.setData(ClipboardData(text: contactName));
    
    if (Platform.isWindows || kIsWeb) {
      // Share via WhatsApp/Email/etc
      await Share.shareXFiles(
        [XFile(cardFilePath)],
        // [XFile(filePath, mimeType: 'application/pdf')],
        text: text,
      );
    } else {
      // Share via WhatsApp/Email/etc
      await Share.shareXFiles(
        [XFile(cardFilePath)],
        // [XFile(filePath, mimeType: 'application/pdf')],
        text: text,
      );
    }
  }

  Future<void> _sendCard({bool useDNS = true}) async {
    try {
              
      setState(() => _isLoading = true);

      String text = "";
      String extraInfoText = (widget.ticket.extraInfo.trim().isNotEmpty) ? ' ${widget.ticket.extraInfo}' : '';

      if (widget.ticket.venue.toLowerCase().contains('nyumbani') ) {
        text = "Habari ${widget.ticket.userName},\nUmealikwa kwenye sherehe ya ${widget.ticket.eventName}, Itakayofanyika tarehe ${widget.ticket.date}, ${widget.ticket.venue}, kuanzia saa ${widget.ticket.time} ${getTimeOfDay(widget.ticket.time)}. Hii ni kadi yako. Fika nayo siku ya tukio. Namba ya kadi yako ni: ${widget.ticket.ticketCode} (${widget.ticket.ticketType})${extraInfoText}.\nBofya kiungo hiki kuthibitisha uwepo wako -> https://tiketimkononi.telabs.co.tz/confirm/attendance/${widget.ticket.eventId}/${widget.ticket.ticketCode}\nKiungo cha mahali -> ${widget.ticket.locationLink}\nKwa msaada piga namba ${widget.event!.organizerPhoneNumber}.\n#TiketiMkononi, #SimuYakoTiketiYako";
      } else {
        text = "Habari ${widget.ticket.userName},\nUmealikwa kwenye sherehe ya ${widget.ticket.eventName}, Itakayofanyika tarehe ${widget.ticket.date}, katika ukumbi wa ${widget.ticket.venue}, kuanzia saa ${widget.ticket.time} ${getTimeOfDay(widget.ticket.time)}. Hii ni kadi yako. Fika nayo siku ya tukio. Namba ya kadi yako ni: ${widget.ticket.ticketCode} (${widget.ticket.ticketType})${extraInfoText}.\nBofya kiungo hiki kuthibitisha uwepo wako -> https://tiketimkononi.telabs.co.tz/confirm/attendance/${widget.ticket.eventId}/${widget.ticket.ticketCode}\nKiungo cha mahali -> ${widget.ticket.locationLink}\nKwa msaada piga namba ${widget.event!.organizerPhoneNumber}.\n#TiketiMkononi, #SimuYakoTiketiYako";
      }


      final Uri uri = useDNS ? Uri.parse('${backend_url}api/send_card') // Original URL 
      : Uri.parse('${backend_url_with_fallback_ip}send_card'); // Use IP

      final request = http.MultipartRequest('POST', uri)
        ..fields['ticket_id'] = '${widget.ticket.id}'
        ..fields['text'] = text;

      if (kIsWeb) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'image',
            _webImageBytes!,
            filename: 'card.png',
          ),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath(
            'image',
            cardFilePath,
          ),
        );
      }

      final response = await request.send();
     
      // Convert the streamed response to a string
      final responseBody = await response.stream.bytesToString();

      final responseData = jsonDecode(responseBody);

      debugPrint("responseData : $responseData");
      debugPrint("responseData message : ${responseData['message']}");
      debugPrint("responseData success : ${responseData['success']}");

      if (response.statusCode == 200) {
        if (responseData['message'] == "Card sent successfully!") {
          setState(() {
            isWhatsappSent = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(responseBody)),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Upload failed: ${response.statusCode}, $responseBody')),
          );
        }
      } else if (response.statusCode == 302) {
        _handleHTTPRedirect();
      } else {
        if(response.statusCode == 413){
          _showSnackBar('Request failed: Image is Too Large');
        } else {
          _showSnackBar('Request failed: ${response.statusCode}');
        }
      }
      
    } on SocketException catch (e) {
      debugPrint('Network error occurred:');
      debugPrint('- Exception type: ${e.runtimeType}');
      debugPrint('- Message: ${e.message}');
      
      if (e.osError != null) {
        debugPrint('  - Error number (errno): ${e.osError!.errorCode}');
        debugPrint('  - OS message: ${e.osError!.message}');
        debugPrint('  - errorCode: ${e.osError!.errorCode}');
        debugPrint('  - useDNS: ${useDNS}');

        // Retry with IP if DNS fails (errno = 7) and not already retrying
        if ((e.osError!.errorCode == 11001 || e.osError!.errorCode == 7) && useDNS) {
          debugPrint('DNS failed! Retrying with IP: ${backend_url_with_fallback_ip}...');
          await _sendCard(useDNS: false); // Recursive retry

          return;
        }
      }

      _handleSocketException(e);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }

  }

  void _handleSocketException(SocketException e) {
    if (e.osError?.errorCode == 7 || e.osError?.errorCode == 101 || e.osError?.errorCode == 111) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Connection Error'),
          content: const Text('Could not connect to the server. Please check your internet connection.'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
    } else {
      _showSnackBar('Connection Error: ${e.message}');
    }
  }

  void _handleHTTPRedirect() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connection Error'),
        content: const Text('Could not connect to the server. Please check your internet connection.'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Future<void> _shareCardCode() async {
    _updateTicketSmsSentStatus(widget.ticket.id, widget.event!.id);
    
    await Clipboard.setData(ClipboardData(text: widget.ticket.userPhoneNumber));

    String text = "";
    String extraInfoText = (widget.ticket.extraInfo.trim().isNotEmpty) ? ' ${widget.ticket.extraInfo}' : '';

    if(widget.event!.category.toUpperCase() == "WEDDING"){
      if (widget.ticket.venue.toLowerCase().contains('nyumbani') ) {
        text = "Habari ${widget.ticket.userName},\nUmealikwa kwenye sherehe ya ${widget.ticket.eventName}, Itakayofanyika tarehe ${widget.ticket.date}, ${widget.ticket.venue}, kuanzia saa ${widget.ticket.time} ${getTimeOfDay(widget.ticket.time)}. Namba ya kadi yako ni: ${widget.ticket.ticketCode} (${widget.ticket.ticketType})${extraInfoText}. Hii ni kadi yako, fika nayo siku ya tukio..\nBofya kiungo hiki kuthibitisha uwepo wako -> https://tiketimkononi.telabs.co.tz/confirm/attendance/${widget.ticket.eventId}/${widget.ticket.ticketCode}\nKiungo cha mahali -> ${widget.ticket.locationLink}\nKwa msaada piga namba ${widget.event!.organizerPhoneNumber}.\n#TiketiMkononi";
      } else {
        text = "Habari ${widget.ticket.userName},\nUmealikwa kwenye sherehe ya ${widget.ticket.eventName}, Itakayofanyika tarehe ${widget.ticket.date}, katika ukumbi wa ${widget.ticket.venue}, kuanzia saa ${widget.ticket.time} ${getTimeOfDay(widget.ticket.time)}. Namba ya kadi yako ni: ${widget.ticket.ticketCode} (${widget.ticket.ticketType})${extraInfoText}. Hii ni kadi yako, fika nayo siku ya tukio..\nBofya kiungo hiki kuthibitisha uwepo wako -> https://tiketimkononi.telabs.co.tz/confirm/attendance/${widget.ticket.eventId}/${widget.ticket.ticketCode}\nKiungo cha mahali -> ${widget.ticket.locationLink}\nKwa msaada piga namba ${widget.event!.organizerPhoneNumber}.\n#TiketiMkononi";
      }
    } else {
      text = "Habari ${widget.ticket.userName},\n"
      "${widget.ticket.ticketCode} (${widget.ticket.ticketType}) ni namba ya tiketi yako ya "
      "${widget.ticket.eventName}, itakayofanyika tarehe ${widget.ticket.date} "
      "${widget.ticket.venue}, kuanzia saa ${widget.ticket.time} "
      "${getTimeOfDay(widget.ticket.time)}.\n"
      "Tafadhali bofya kiungo kifuatacho kuthibitisha uwepo wako:\n"
      "https://tiketimkononi.telabs.co.tz/confirm/attendance/${widget.ticket.eventId}/${widget.ticket.ticketCode}\n"
      "Kiungo cha mahali: ${widget.ticket.locationLink}\n"
      "Kwa msaada au maelezo zaidi, piga simu ${widget.event!.organizerPhoneNumber}.\n"
      "#TiketiMkononi #SimuYakoTiketiYako";
    }


    await SharePlus.instance.share(
      ShareParams(
        text: text,
      ),
    );
  }

  Future<void> _launchPhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch phone app')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = _isLargeScreen(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ticket QR Code'),
        backgroundColor: const Color.fromARGB(255, 240, 244, 247),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isLargeScreen ? 32 : 24,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isLargeScreen ? 800 : double.infinity,
              ),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: EdgeInsets.all(isLargeScreen ? 32 : 24),
                  child: isLargeScreen
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    (widget.ticket.seatNumber.contains('--') || widget.ticket.seatNumber.isEmpty) ? "Ticket ID: ${widget.ticket.id}" : "Seat Number: ${widget.ticket.seatNumber}",
                                    style: TextStyle(
                                      fontSize: isLargeScreen ? 28 : 18,
                                      fontWeight: FontWeight.normal,
                                    ),
                                  ),
                                  _buildQRCodeSection(isLargeScreen),
                                  const SizedBox(height: 20),
                                  _buildStatusSection(),
                                  const SizedBox(height: 8),
                                  if (widget.event != null)
                                  (widget.event!.category.toUpperCase() == "WEDDING") ?
                                  Column(
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: _isCardGenerated ? _shareCard : null,
                                        icon: const Icon(Icons.share),
                                        label: const Text("Share Card"),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      ElevatedButton.icon(
                                        onPressed: (_isCardGenerated && !_isLoading && !isWhatsappSent) ? _sendCard : null,
                                        icon: const Icon(Icons.send),
                                        label: const Text("Send Card"),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ) :
                                  ElevatedButton.icon(
                                    onPressed: _shareTicket,
                                    icon: const Icon(Icons.share),
                                    label: const Text("Share Ticket"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                  if (widget.event == null)
                                  ElevatedButton.icon(
                                    onPressed: _shareTicket,
                                    icon: const Icon(Icons.share),
                                    label: const Text("Share Ticket"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 8),
                                  ElevatedButton.icon(
                                    onPressed: _printTicket,
                                    icon: const Icon(Icons.print),
                                    label: const Text("Print Ticket"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange[800],
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if ((Platform.isWindows || kIsWeb) && selectedPrinter != null)
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      ElevatedButton(
                                        onPressed: () {
                                          _refreshPrinters();
                                        },
                                        child: const Text(
                                          'Refresh Printers',
                                          style: TextStyle(
                                            color: Colors.green
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              ),
                            ),
                            const SizedBox(width: 30),
                            Expanded(
                              child: _buildEventInfoSection(isLargeScreen),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            Text(
                              (widget.ticket.seatNumber.contains('--') || widget.ticket.seatNumber.isEmpty) ? "Ticket ID: ${widget.ticket.id}" : "Seat Number: ${widget.ticket.seatNumber}",
                              style: TextStyle(
                                fontSize: isLargeScreen ? 28 : 18,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                            _buildQRCodeSection(isLargeScreen),
                            const SizedBox(height: 1),
                            _buildEventInfoSection(isLargeScreen),
                            _buildStatusSection(),
                            const SizedBox(height: 8),
                            if (widget.event != null)
                            (widget.event!.category.toUpperCase() == "WEDDING") ?
                            Column(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _isCardGenerated ? _shareCard : null,
                                  icon: const Icon(Icons.share),
                                  label: const Text("Share Card"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  onPressed: (_isCardGenerated && !_isLoading && !isWhatsappSent) ? _sendCard : null,
                                  icon: const Icon(Icons.send),
                                  label: const Text("Send Card"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ],
                            )
                            :
                            ElevatedButton.icon(
                              onPressed: _shareTicket,
                              icon: const Icon(Icons.share),
                              label: const Text("Share Ticket"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            if (widget.event == null)
                            ElevatedButton.icon(
                              onPressed: _shareTicket,
                              icon: const Icon(Icons.share),
                              label: const Text("Share Ticket"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}



class OverlayConfig {
  final Offset qrOffset;
  final Offset textOffset;
  final double qrSize;

  const OverlayConfig({
    required this.qrOffset,
    required this.textOffset,
    required this.qrSize,
  });

  OverlayConfig copyWith({
    Offset? qrOffset,
    Offset? textOffset,
    double? qrSize,
  }) {
    return OverlayConfig(
      qrOffset: qrOffset ?? this.qrOffset,
      textOffset: textOffset ?? this.textOffset,
      qrSize: qrSize ?? this.qrSize,
    );
  }
}

class SimpleImageCacheManager {
  static const Duration _cacheDuration = Duration(days: 7);
  static const int _maxCacheSize = 1002424; // 100MB max cache

  static Future<String> _getCacheDirectory() async {
    final dir = await getTemporaryDirectory();
    final cacheDir = Directory('${dir.path}/image_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir.path;
  }

  static String _getCacheKey(String url) {
    final uri = Uri.parse(url);
    final fileName = uri.pathSegments.isNotEmpty 
        ? uri.pathSegments.last 
        : 'image_${DateTime.now().millisecondsSinceEpoch}';
    final safeUrl = url.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    return '${safeUrl.substring(0, safeUrl.length > 50 ? 50 : safeUrl.length)}_$fileName';
  }

  static Future<String> getCacheFilePath(String url) async {
    final cacheDir = await _getCacheDirectory();
    final key = _getCacheKey(url);
    return '$cacheDir/$key';
  }

  static Future<bool> isImageCached(String url) async {
    try {
      final filePath = await getCacheFilePath(url);
      final file = File(filePath);
      
      if (await file.exists()) {
        final lastModified = await file.lastModified();
        final now = DateTime.now();
        
        // Check if cache is expired
        if (now.difference(lastModified) > _cacheDuration) {
          await file.delete();
          return false;
        }
        
        // Verify file is not corrupted (has content)
        final stat = await file.stat();
        return stat.size > 0;
      }
      return false;
    } catch (e) {
      print('Cache check error: $e');
      return false;
    }
  }

  static Future<File> getCachedImage(String url) async {
    final filePath = await getCacheFilePath(url);
    return File(filePath);
  }

  static Future<File> cacheImage(String url, Uint8List bytes) async {
    try {
      final filePath = await getCacheFilePath(url);
      final file = File(filePath);
      
      // Create directory if it doesn't exist
      await file.parent.create(recursive: true);
      
      await file.writeAsBytes(bytes);
      
      // Clean up old cache if needed
      await _cleanupCache();
      
      return file;
    } catch (e) {
      print('Cache error: $e');
      rethrow;
    }
  }

  static Future<void> _cleanupCache() async {
    try {
      final cacheDir = await _getCacheDirectory();
      final directory = Directory(cacheDir);
      
      if (!await directory.exists()) return;
      
      final files = await directory.list().where((file) => file is File).cast<File>().toList();
      
      // Calculate total size
      int totalSize = 0;
      final fileSizes = <File, int>{};
      
      for (final file in files) {
        final stat = await file.stat();
        final size = stat.size;
        fileSizes[file] = size;
        totalSize += size;
      }
      
      // Delete oldest files if over limit
      if (totalSize > _maxCacheSize) {
        for (final file in files) {
          final size = fileSizes[file]!;
          await file.delete();
          totalSize -= size;
          
          if (totalSize <= _maxCacheSize * 0.8) { // Keep at 80% of max
            break;
          }
        }
      }
      
      // Also delete expired files
      final now = DateTime.now();
      for (final file in files) {
        final lastModified = await file.lastModified();
        if (now.difference(lastModified) > _cacheDuration) {
          await file.delete();
        }
      }
    } catch (e) {
      print('Cache cleanup error: $e');
    }
  }

  static Future<void> clearCache() async {
    try {
      final cacheDir = await _getCacheDirectory();
      final directory = Directory(cacheDir);
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    } catch (e) {
      print('Clear cache error: $e');
    }
  }

  static Future<int> getCacheSize() async {
    try {
      final cacheDir = await _getCacheDirectory();
      final directory = Directory(cacheDir);
      
      if (!await directory.exists()) return 0;
      
      int totalSize = 0;
      await for (final file in directory.list(recursive: true)) {
        if (file is File) {
          final stat = await file.stat();
          totalSize += stat.size;
        }
      }
      
      return totalSize;
    } catch (e) {
      print('Get cache size error: $e');
      return 0;
    }
  }
}

class ImageQrService {
  static Uint8List? _webImageBytes;

  static Future<String> generateImageWithQr({
    required Ticket ticket,
    required Event event,
    required  OverlayConfig config,
  }) async {
    String imageName = event.cardUrl;
    String qrData = SimpleCodec.encode(jsonEncode({
      "tid": ticket.id,
      "eid": ticket.eventId,
      "dt": ticket.date,
    }));

    try {
      // Load base image
      debugPrint('Loading image');

      final image = await ImageLoader.loadImage(imageName);
      if (image == null) {
        throw Exception('Failed to load image');
      }


      final int borderSize = 1; // quiet zone in pixels
      final int qrSize = (config.qrSize * image.width).toInt();
      final int qrOffsetDx = (config.qrOffset.dx * image.width).toInt();
      final int qrOffsetDy = (config.qrOffset.dy * image.height).toInt();
      final int textOffsetDx = (config.textOffset.dx * image.width).toInt();
      final int textOffsetDy = (config.textOffset.dy * image.height).toInt();

      final painter = QrPainter(
        data: qrData,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.L, // FEW modules
        gapless: true, // NO gaps
      );

      const double quietZoneRatio = 0.01; // 10% padding (QR spec safe)

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(
        recorder,
        Rect.fromLTWH(0, 0, qrSize.toDouble(), qrSize.toDouble()),
      );

      final padding = qrSize * quietZoneRatio;

      // Move QR inward
      canvas.translate(padding, padding);

      // Paint QR smaller so edges are not clipped
      painter.paint(
        canvas,
        Size(
          qrSize - padding * 2,
          qrSize - padding * 2,
        ),
      );

      final ui.Image image2 =
          await recorder.endRecording().toImage(qrSize, qrSize);

      final ByteData byteData =
          await image2.toByteData(format: ui.ImageByteFormat.png) as ByteData;

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      // Decode into 'image' package
      final img.Image qrImage = img.decodePng(pngBytes)!;

      // Create larger white background
      final int finalSize = qrSize + 2 * borderSize;
      final img.Image qrWithBorder = img.Image(
        width: finalSize,
        height: finalSize,
      );
      img.fill(qrWithBorder, color: img.ColorRgb8(255, 255, 255));

      // Center QR on white background
      img.compositeImage(
        qrWithBorder,
        qrImage,
        dstX: borderSize,
        dstY: borderSize,
      );

      /// 6️⃣ Composite QR onto main image
      img.compositeImage(
        image,
        qrWithBorder,
        dstX: qrOffsetDx,
        dstY: qrOffsetDy,
      );

      ByteData labelAsset;
      if(ticket.ticketType.trim().toUpperCase() == "DOUBLE") {
        labelAsset = await rootBundle.load('assets/double.jpeg');
      } else if(ticket.ticketType.trim().toUpperCase() == "SINGLE") {
        labelAsset = await rootBundle.load('assets/single.jpeg');
      } else if(ticket.ticketType.trim().toUpperCase() == "SPECIAL") {
        labelAsset = await rootBundle.load('assets/special.jpeg');
      } else if(ticket.ticketType.trim().toUpperCase() == "WAKWE") {
        labelAsset = await rootBundle.load('assets/wakwe.jpeg');
      } 
      else {
        labelAsset = await rootBundle.load('assets/other.jpeg');
      }

      final Uint8List bytes = labelAsset.buffer.asUint8List();
      final img.Image labelImage = img.decodeImage(bytes)!;

      int targetWidth = (qrSize * 0.6).toInt();
      final double aspectRatio = labelImage.height / labelImage.width;
      final int targetHeight = (targetWidth * aspectRatio).round();

      final img.Image resizedLabel = img.copyResize(
        labelImage,
        width: targetWidth,
        height: targetHeight,
        interpolation: img.Interpolation.cubic,
      );

      img.compositeImage(
        image,
        resizedLabel,
        dstX: (qrOffsetDx + qrWithBorder.width/2 - resizedLabel.width/2).round(),
        dstY: (qrOffsetDy - resizedLabel.height).round(),
      );

      img.BitmapFont font = img.arial24;

      final img.Color color = img.ColorRgb8(0, 0, 0); // Black

      // debugPrint('font.size : ${font.size}');

      int textWidth = 0;
      if (font.size == 14) {
        // arial14: ~9px per character
        textWidth = ticket.userName.length * 9;
      } else if (font.size == 24) {
        // arial24: ~15px per character  
        textWidth = ticket.userName.length * 15;
      } else if (font.size == 48) {
        // arial48: ~30px per character
        textWidth = ticket.userName.length * 30;
      }else {
        textWidth = (ticket.userName.length * font.size * 0.625).toInt();
      }
  
      final textHeight = font.lineHeight;
      
      // Calculate centered position
      final x2 = (image.width - textWidth) ~/ 2;
      final y2 = (image.height - textHeight) ~/ 2;

      img.drawString(
        image, 
        ticket.userName, 
        font: font, 
        x: textOffsetDx,
        y: textOffsetDy, 
        color: color
      );

      if(ticket.extraInfo.isNotEmpty) {
        // ================== Extra_Info STAMP ==================
        final stampFont = img.arial14;

        // Stamp text - REMOVED the extra spaces
        final int spacesToAdd = (12 - (ticket.extraInfo.length)).clamp(0, 12);
        final String stampText = '  ' * spacesToAdd + (ticket.extraInfo);

        // Calculate text dimensions
        int charWidth = stampFont.size == 14
            ? 9
            : stampFont.size == 24
                ? 15
                : 30;
        int textWidth2 = stampText.length * charWidth;
        int textHeight2 = stampFont.lineHeight;

        // Calculate ABSOLUTE MINIMUM radius - text will touch or slightly overlap circle
        int padding2 = 0; // ZERO padding

        // For width: radius needs to be at least half the text width
        // Use exact half without ceiling first, then apply minimal adjustment
        double exactWidthRadius = textWidth2 / 2;
        int circleMinRadius = exactWidthRadius.ceil(); // Keep ceil to ensure text fits width-wise

        // For height: Use an even smaller percentage of lineHeight (50%) for tightest fit
        // Most arial14 characters (like 'A', 'B', 'E') actually use about 50% of lineHeight
        int circleMinRadiusHeight = ((textHeight2 * 0.2) / 2).ceil(); // Reduced from 0.6 to 0.5

        // Use the larger of width-based or height-based radius
        int radius = circleMinRadius > circleMinRadiusHeight ? circleMinRadius : circleMinRadiusHeight;

        // Optional: Force an even smaller radius by taking the minimum instead of maximum
        // Uncomment the line below to force smallest possible radius (may cut off text)
        // radius = circleMinRadius < circleMinRadiusHeight ? circleMinRadius : circleMinRadiusHeight;

        // Stamp position on main image
        final int centerX = textOffsetDx + 22 * charWidth + 200; // X position of circle center
        final int centerY = textOffsetDy - 80; // Y position of circle center

        // Red "stamp" color with slight transparency
        final stampColor = img.ColorRgba8(0, 0, 0, 0);

        // Draw filled circle directly on main image
        for (int y = centerY - radius; y <= centerY + radius; y++) {
          for (int x = centerX - radius; x <= centerX + radius; x++) {
            // Check if within image bounds
            if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
              final dx = x - centerX;
              final dy = y - centerY;
              // Calculate squared distance and compare with squared radius
              if (dx * dx + dy * dy <= radius * radius) {
                image.setPixel(x, y, stampColor); 
              }
            }
          }
        }

        // PERFECT CENTERING for arial14 font
        final int textX = centerX - (textWidth2 ~/ 2);

        // Fine-tuned vertical centering for minimum radius
        // Adjusted to 0 for even tighter fit with 50% height calculation
        final int textY = centerY - (textHeight2 ~/ 2) + 0; // Changed from +1 to 0 for tighter fit

        // Draw text directly on main image
        img.drawString(
          image,
          stampText,
          font: stampFont,
          x: textX,
          y: textY,
          color: img.ColorRgba8(255, 255, 255, 255), // White text for contrast
        );

        // Debug: Draw dots to check centering
        image.setPixel(centerX, centerY, img.ColorRgba8(0, 255, 0, 255)); // Green dot at circle center
        image.setPixel(textX, textY, img.ColorRgba8(0, 0, 255, 255)); // Blue dot at text anchor

        // Draw a prominent circle outline at the edge
        int outlineThickness = 2; // Slightly thinner outline to see edge better

        for (int y = centerY - radius - outlineThickness; y <= centerY + radius + outlineThickness; y++) {
          for (int x = centerX - radius - outlineThickness; x <= centerX + radius + outlineThickness; x++) {
            if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
              final dx = x - centerX;
              final dy = y - centerY;
              final distance = sqrt(dx*dx + dy*dy);
              
              // Draw a thick outline at the exact circle edge
              if (distance >= radius - outlineThickness && distance <= radius + outlineThickness) {
                image.setPixel(x, y, img.ColorRgba8(50, 255, 0, 255)); // Bright yellow outline
              }
            }
          }
        }

        // ================== END Extra_Info STAMP ==================

      }

      /// 7️⃣ Save result
      final tempDir = await getTemporaryDirectory();
      final outputFile = File(
        '${tempDir.path}/image_with_qr.jpg',
      );

      final jpgBytes = img.encodeJpg(image, quality: 90);

      await outputFile.writeAsBytes(jpgBytes);
      debugPrint("image saved at: ${outputFile.path}");

      if (kIsWeb) {
        _webImageBytes = Uint8List.fromList(jpgBytes);
      }

      return outputFile.path;
    } catch (e) {
      rethrow;
    }
  }

}

class ImageLoader {
  static Future<img.Image?> loadImage(String imageName, {bool useDNS = true}) async { 
    try {
      String source = useDNS ? '${backend_url}api/image/${imageName}' 
      : '${backend_url_with_fallback_ip}image/${imageName}';

      print('🔍 Attempting to load image from: $source');
      
      // Check if source is a local file path
      if (_isLocalPath(source)) {
        print('📁 Detected local path');
        final image = await _loadLocalImage(source);
        if (image != null) {
          print('✅ Successfully loaded local image');
          return image;
        }
      }
      
      // Check if source is a network URL
      if (source.startsWith('http://') || source.startsWith('https://')) {
        print('🌐 Detected network URL');
        return await _loadNetworkImage(source);
      }
      
      // Try as local file first, then network (for ambiguous paths)
      print('🔍 Ambiguous path, trying as local then network...');
      final localImage = await _loadLocalImage(source);
      if (localImage != null) {
        print('✅ Loaded as local image');
        return localImage;
      }
      
      // Try as network URL
      return await _loadNetworkImage(source);
    } on SocketException catch (e) {
      debugPrint('  >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> 22 Network error occurred:');
      debugPrint('- Exception type: ${e.runtimeType}');
      debugPrint('- Message: ${e.message}');
      
      var image;
      if (e.osError != null) {
        debugPrint('  - Error number (errno): ${e.osError!.errorCode}');
        debugPrint('  - OS message: ${e.osError!.message}');
        debugPrint('  - errorCode: ${e.osError!.errorCode}');
        debugPrint('  - useDNS: ${useDNS}');

        // Retry with IP if DNS fails (errno = 7) and not already retrying
        if ((e.osError!.errorCode == 11001 || e.osError!.errorCode == 7) && useDNS) {
          debugPrint('DNS failed! Retrying with IP at loadImage: ${backend_url_with_fallback_ip}...');
          image = await loadImage(imageName, useDNS: false); // Recursive retry
        } 
        
        return image;
      }
    } catch (e) {
      print('❌ Error loading image: $e');
      return null;
    }
    return null;
  }

  static bool _isLocalPath(String pathString) {
    // Check for common local file patterns
    return pathString.startsWith('/') || 
           pathString.startsWith('./') || 
           pathString.startsWith('../') ||
           pathString.startsWith('file://') ||
           pathString.contains(RegExp(r'^[A-Za-z]:[\\/]')) || // Windows path
           pathString.endsWith('.jpg') || 
           pathString.endsWith('.jpeg') ||
           pathString.endsWith('.png') ||
           pathString.endsWith('.gif') ||
           pathString.endsWith('.bmp') ||
           pathString.endsWith('.webp') ||
           File(pathString).existsSync(); // Direct file existence check
  }

  static Future<img.Image?> _loadLocalImage(String filePath) async {
    try {
      // Clean up file path
      String cleanPath = filePath;
      if (filePath.startsWith('file://')) {
        cleanPath = filePath.substring(7);
      }
      
      // Handle relative paths
      if (cleanPath.startsWith('./') || cleanPath.startsWith('../')) {
        final currentDir = Directory.current.path;
        cleanPath = path.normalize(path.join(currentDir, cleanPath));
      }
      
      final file = File(cleanPath);
      print('📂 Checking local file: $cleanPath');
      print('📊 File exists: ${await file.exists()}');
      
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        print('📦 File size: ${bytes.length} bytes');
        
        final image = img.decodeImage(bytes);
        if (image == null) {
          print('⚠️ Failed to decode image - file may be corrupted');
        }
        return image;
      }
      print('⚠️ Local file not found');
      return null;
    } catch (e) {
      print('❌ Error loading local image: $e');
      return null;
    }
  }

  static Future<img.Image?> _loadNetworkImage(String url, {bool useDNS = true}) async {
    try {
      print('🌐 Checking cache for URL: $url');
      
      // Check cache first
      if (await SimpleImageCacheManager.isImageCached(url)) {
        print('📦 Cache hit! Loading from cache...');
        final cachedFile = await SimpleImageCacheManager.getCachedImage(url);
        final bytes = await cachedFile.readAsBytes();
        print('📊 Cache file size: ${bytes.length} bytes');
        
        final image = img.decodeImage(bytes);
        if (image != null) {
          print('✅ Successfully loaded from cache');
          return image;
        }
        print('⚠️ Cached file corrupted, re-downloading...');
      }

      // Download from network
      print('⬇️ Downloading from network...');
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept': 'image/*',
        },
      );
      
      print('📡 HTTP Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        print('📦 Downloaded ${bytes.length} bytes');
        
        // Decode image first to ensure it's valid
        final image = img.decodeImage(bytes);
        if (image == null) {
          print('❌ Downloaded image is not valid');
          throw Exception('Downloaded image is not a valid image file');
        }
        
        // Cache the image
        print('💾 Caching image...');
        await SimpleImageCacheManager.cacheImage(url, bytes);
        print('✅ Image cached successfully');
        
        return image;
      } else {
        print('❌ HTTP Error ${response.statusCode}');
        throw Exception('Failed to load image: HTTP ${response.statusCode}');
      }
    } on SocketException catch (e) {
      rethrow;
    } 
    catch (e) {
      print('❌ Error loading network image: $e');
      
      // Try to load from cache even if it might be expired
      try {
        final cachedFile = await SimpleImageCacheManager.getCachedImage(url);
        if (await cachedFile.exists()) {
          print('🔄 Falling back to cached file despite error');
          final bytes = await cachedFile.readAsBytes();
          return img.decodeImage(bytes);
        }
      } catch (cacheError) {
        print('⚠️ Cache fallback failed: $cacheError');
      }
      
      return null;
    }
  }

  static Future<File> loadAndCacheImage(String source) async {
    print('🔍 loadAndCacheImage called with: $source');
    
    img.Image? image;
    
    if (source.startsWith('http://') || source.startsWith('https://')) {
      // Network image
      print('🌐 Processing as network image');
      image = await _loadNetworkImage(source);
      if (image != null) {
        final cachedFile = await SimpleImageCacheManager.getCachedImage(source);
        print('✅ Network image loaded and cached at: ${cachedFile.path}');
        return cachedFile;
      }
    } else {
      // Local image
      print('📁 Processing as local image');
      image = await _loadLocalImage(source);
      if (image != null) {
        print('✅ Local image loaded from: $source');
        return File(source);
      }
    }
    
    print('❌ Failed to load image from: $source');
    throw Exception('Failed to load image from: $source');
  }
}