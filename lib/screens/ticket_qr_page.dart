import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/models/ticket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:flutter/services.dart';
// import 'dart:html' as html; // only for web

final websocketServiceProvider = Provider<WebSocketService>((ref) {
  return WebSocketService();
});

class WebSocketService {
  WebSocketChannel? _channel;

  Timer? _reconnectTimer;
  bool _isDisposed = false;
  int _reconnectAttempts = 0;
  final int maxReconnectAttempts = 5;
  final Duration reconnectInterval = const Duration(seconds: 3);
  final Duration connectionTimeout = const Duration(seconds: 10);

  final _connectionStatusController = StreamController<bool>.broadcast();
  final _ticketController = StreamController<Ticket>.broadcast();

  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;
  Stream<Ticket> get ticketStream => _ticketController.stream;

  Future<void> connect(userId, ticketId, scanStatus, {bool useDNS = true}) async {
    if (scanStatus == 1) return;

    try {
      final Uri uri = useDNS ? Uri.parse(backend_ws_url) // Original URL
      : Uri.parse(backend_ws_url_with_fallback_ip); // Use IP

      _connectionStatusController.add(false);
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready;
      _connectionStatusController.add(true);

      _channel!.sink.add(jsonEncode({
        "user_id": userId,
        "ticket_id": ticketId,
        "scan_status": scanStatus,
        "type": "subscribe",
        "data": "tickets"
      }));

      _channel!.stream.listen(
        (message) => _handleIncomingMessage(message),
        onError: (error) => _handleConnectionError(userId, ticketId, scanStatus),
        onDone: () => _handleConnectionError(userId, ticketId, scanStatus),
      );
    } on WebSocketChannelException catch (e) {
      if (e.inner is SocketException) {
        final socketException = e.inner as SocketException;
        debugPrint('Network error occurred:');
        debugPrint('- Exception type: ${e.runtimeType}');
        debugPrint('- Message: ${e.message}');
        
        if (socketException.osError != null) {
          debugPrint('  - Error number (errno): ${socketException.osError!.errorCode}');
          debugPrint('  - OS message: ${socketException.osError!.message}');

          // Retry with IP if DNS fails (errno = 7) and not already retrying
          if (socketException.osError!.errorCode == 7 && useDNS) {
            debugPrint('DNS failed! Retrying with IP: ${backend_ws_url_with_fallback_ip}...');
            connect(userId, ticketId, scanStatus, useDNS: false); // Recursive retry
            return;
          }
        }
      } else {
        print('WebSocketChannelException: ${e.message}');
      }
    } on SocketException catch (e) {
      debugPrint('Network error occurred:');
      debugPrint('- Exception type: ${e.runtimeType}');
      debugPrint('- Message: ${e.message}');
      
      if (e.osError != null) {
        debugPrint('  - Error number (errno): ${e.osError!.errorCode}');
        debugPrint('  - OS message: ${e.osError!.message}');

        // Retry with IP if DNS fails (errno = 7) and not already retrying
        if (e.osError!.errorCode == 7 && useDNS) {
          debugPrint('DNS failed! Retrying with IP: ${backend_ws_url_with_fallback_ip}...');
          connect(userId, ticketId, scanStatus, useDNS: false); // Recursive retry
          return;
        }
      }
    } on TimeoutException {
      _scheduleReconnection(userId, ticketId, scanStatus);
    } catch (e) {
      _connectionStatusController.add(false);
      _scheduleReconnection(userId, ticketId, scanStatus);
    }
  }

  void _handleConnectionError(userId, ticketId, scanStatus) {
    _connectionStatusController.add(false);
    _scheduleReconnection(userId, ticketId, scanStatus);
  }

  void _scheduleReconnection(userId, ticketId, scanStatus) {
    if (_isDisposed || _reconnectAttempts >= maxReconnectAttempts) return;

    _reconnectAttempts++;
    _connectionStatusController.add(false);
    
    _reconnectTimer = Timer(reconnectInterval * _reconnectAttempts, () {
      connect(userId, ticketId, scanStatus);
    });
  }

  void _handleIncomingMessage(String message) {
    try {
      final data = jsonDecode(message);
      if (data['type'] == 'ticket') {
        _ticketController.add(Ticket.fromJson(data['ticket']));
      }
    } catch (e) {
      print("Error parsing message: $e");
    }
  }

  void disconnect() {
    _channel?.sink.close(1000); // Normal closure
    _connectionStatusController.add(false);
    _isDisposed = true;
    _reconnectTimer?.cancel();
  }
}

class TicketQRPage extends ConsumerStatefulWidget {
  final int ticketId;
  final int userId;
  final String userName;
  final int eventId;
  final String eventName;
  final String date;
  final String time;
  final String venue;
  final String ticketType;
  final double price;
  final String seatNumber;
  final int scanStatus;
  final DateTime updatedAt;
  final DateTime createdAt;

  const TicketQRPage({
    super.key,
    required this.ticketId,
    required this.userId,
    required this.userName,
    required this.eventId,
    required this.eventName,
    required this.date,
    required this.time,
    required this.venue,
    required this.ticketType,
    required this.price,
    required this.seatNumber,
    required this.scanStatus,
    required this.updatedAt,
    required this.createdAt,
  });

  @override
  ConsumerState<TicketQRPage> createState() => _TicketQRPageState();
}

class _TicketQRPageState extends ConsumerState<TicketQRPage> {
  late final WebSocketService _webSocketService;
  late DateTime scannedAt;
  late int scanStatus2;
  bool _isTicketScanned = false;
  Printer? selectedPrinter;

  @override
  void initState() {
    super.initState();
    scanStatus2 = widget.scanStatus;
    scannedAt = widget.updatedAt;

    if (widget.scanStatus != 1) {
      _webSocketService = ref.read(websocketServiceProvider);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _webSocketService.connect(
          widget.userId,
          widget.ticketId,
          widget.scanStatus,
        );
      });
    }

    _loadSelectedPrinter();
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



  @override
  void dispose() {
    _webSocketService.disconnect();
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

  String _formatDate2(DateTime dateTime) {
    final DateFormat outputFormat = DateFormat('EEEE, MMMM d, yyyy - hh:mm a');
    return outputFormat.format(dateTime);
  }

  Widget _buildQRCodeSection(bool isLargeScreen) {
    return QrImageView(
      data: jsonEncode({
        "ticket_id": widget.ticketId,
        "user_id": widget.userId,
        "user_name": widget.userName,
        "event_id": widget.eventId,
        "event_name": widget.eventName,
        "date": widget.date,
        "time": widget.time,
        "venue": widget.venue,
        "ticket_type": widget.ticketType,
        "price": widget.price,
        "scan_status": widget.scanStatus,
        "createdAt": widget.createdAt.toIso8601String(),
      }),
      version: QrVersions.auto,
      size: isLargeScreen ? 300.0 : 200.0,
    );
  }

  Widget _buildEventInfoSection(bool isLargeScreen) {
    return Column(
      children: [
        Text(
          widget.eventName,
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
            widget.ticketType,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 4),
        Text(
            (widget.price > 0.0) ? 'TSH${NumberFormat('#,##0').format(widget.price.toInt())}' : 'Free',
            style: TextStyle(fontSize: isLargeScreen ? 20 : 14),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: isLargeScreen ? 24 : 16),
            const SizedBox(width: 8),
            Text(
              _formatDate(widget.date),
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
              widget.time,
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
                widget.venue,
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
    if (widget.scanStatus == 1 || _isTicketScanned) {
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
            return ListTile(
              title: const Text('Connection Status'),
              subtitle: Text(isConnected ? 'Connected' : 'Disconnected'),
              trailing: Icon(
                isConnected ? Icons.check_circle : Icons.error,
                color: isConnected ? Colors.green : Colors.red,
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
            if (ticket.scanStatus == 1 && widget.ticketId == ticket.id) {
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
                  widget.eventName,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 10),
                pw.Text("Ticket ID: ${widget.ticketId}", textAlign: pw.TextAlign.center, style: pw.TextStyle(font: customFont, fontSize: 11)),
                pw.Text("Name: ${widget.userName}", textAlign: pw.TextAlign.center, style: pw.TextStyle(font: customFont, fontSize: 11)),
                pw.Text("Date: ${widget.date}", textAlign: pw.TextAlign.center, style: pw.TextStyle(font: customFont, fontSize: 11)),
                pw.Text("Time: ${widget.time}", textAlign: pw.TextAlign.center, style: pw.TextStyle(font: customFont, fontSize: 11)),
                pw.Text("Venue: ${widget.venue}", textAlign: pw.TextAlign.center, style: pw.TextStyle(font: customFont, fontSize: 11)),
                pw.Text("Ticket Type: ${widget.ticketType}", textAlign: pw.TextAlign.center, style: pw.TextStyle(font: customFont, fontSize: 11)),
                pw.Text("Seat: ${widget.seatNumber}", textAlign: pw.TextAlign.center, style: pw.TextStyle(font: customFont, fontSize: 11)),
                pw.Text(
                  "Price: ${(widget.price > 0) ? 'TSH ${widget.price.toInt()}' : 'Free'}",
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: customFont, fontSize: 11)
                ),
                pw.SizedBox(height: 12),

                // QR code
                pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: jsonEncode({
                    "ticket_id": widget.ticketId,
                    "user_id": widget.userId,
                    "user_name": widget.userName,
                    "event_id": widget.eventId,
                    "event_name": widget.eventName,
                    "date": widget.date,
                    "time": widget.time,
                    "venue": widget.venue,
                    "ticket_type": widget.ticketType,
                    "price": widget.price,
                    "scan_status": widget.scanStatus,
                    "createdAt": widget.createdAt.toIso8601String(),
                  }),
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
    final filePath = '${outputDir.path}/ticket_${widget.ticketId}.pdf';
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
                  widget.eventName,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 10),
                pw.Text("Ticket ID: ${widget.ticketId}", textAlign: pw.TextAlign.center, style: pw.TextStyle(font: customFont, fontSize: 11)),
                pw.Text("Name: ${widget.userName}", textAlign: pw.TextAlign.center, style: pw.TextStyle(font: customFont, fontSize: 11)),
                pw.Text("Date: ${widget.date}", textAlign: pw.TextAlign.center, style: pw.TextStyle(font: customFont, fontSize: 11)),
                pw.Text("Time: ${widget.time}", textAlign: pw.TextAlign.center, style: pw.TextStyle(font: customFont, fontSize: 11)),
                pw.Text("Venue: ${widget.venue}", textAlign: pw.TextAlign.center, style: pw.TextStyle(font: customFont, fontSize: 11)),
                pw.Text("Ticket Type: ${widget.ticketType}", textAlign: pw.TextAlign.center, style: pw.TextStyle(font: customFont, fontSize: 11)),
                pw.Text("Seat: ${widget.seatNumber}", textAlign: pw.TextAlign.center, style: pw.TextStyle(font: customFont, fontSize: 11)),
                pw.Text(
                  "Price: ${(widget.price > 0) ? 'TSH ${widget.price.toInt()}' : 'Free'}",
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: customFont, fontSize: 11)
                ),
                pw.SizedBox(height: 12),

                // QR code
                pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: jsonEncode({
                    "ticket_id": widget.ticketId,
                    "user_id": widget.userId,
                    "user_name": widget.userName,
                    "event_id": widget.eventId,
                    "event_name": widget.eventName,
                    "date": widget.date,
                    "time": widget.time,
                    "venue": widget.venue,
                    "ticket_type": widget.ticketType,
                    "price": widget.price,
                    "scan_status": widget.scanStatus,
                    "createdAt": widget.createdAt.toIso8601String(),
                  }),
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
      final filePath = '${outputDir.path}/ticket_${widget.ticketId}.pdf';
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
      final filePath = '${outputDir.path}/ticket_${widget.ticketId}.pdf';
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      // Share via WhatsApp/Email/etc
      await Share.shareXFiles(
        // [XFile(filePath)],
        [XFile(filePath, mimeType: 'application/pdf')],
        text: 'Here is your ticket for ${widget.eventName}!',
      );

      await file.delete();
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
                                    (widget.seatNumber.contains('--') || widget.seatNumber.isEmpty) ? "Ticket ID: ${widget.ticketId}" : "Seat Number: ${widget.seatNumber}",
                                    style: TextStyle(
                                      fontSize: isLargeScreen ? 28 : 18,
                                      fontWeight: FontWeight.normal,
                                    ),
                                  ),
                                  _buildQRCodeSection(isLargeScreen),
                                  const SizedBox(height: 20),
                                  _buildStatusSection(),
                                  const SizedBox(height: 8),
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
                              (widget.seatNumber.contains('--') || widget.seatNumber.isEmpty) ? "Ticket ID: ${widget.ticketId}" : "Seat Number: ${widget.seatNumber}",
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