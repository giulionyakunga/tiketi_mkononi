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
// import 'dart:html' as html; // only for web

import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:qr/qr.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:flutter/material.dart';



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

class _TicketQRPageState extends ConsumerState<TicketQRPage> {
  late final WebSocketService _webSocketService;
  late DateTime scannedAt;
  late int scanStatus2;
  bool _isTicketScanned = false;
  bool _isGenerating = false;
  Printer? selectedPrinter;

  @override
  void initState() {
    super.initState();
    scanStatus2 = widget.ticket.scanStatus;
    scannedAt = widget.ticket.updatedAt;

    if (widget.ticket.scanStatus != 1) {
      _webSocketService = ref.read(websocketServiceProvider);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _webSocketService.connect(
          widget.ticket.userId,
          widget.ticket.id,
          widget.ticket.scanStatus,
        );
      });
    }

    _generateImageWithQr();
    _loadSelectedPrinter();
  }

  Future<void> _generateImageWithQr() async {
    setState(() {
      _isGenerating = true;
    });

    try {
      if(widget.event != null) {
        await ImageQrService.generateImageWithQr(
          ticket:  widget.ticket,
          event:  widget.event!
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing image: $e')),
      );
    } finally {
      setState(() {
        _isGenerating = false;
      });
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




class SimpleImageCacheManager {
  static const Duration _cacheDuration = Duration(days: 7);
  static const int _maxCacheSize = 100 * 1024 * 1024; // 100MB max cache

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
 static Future<File> generateImageWithQr({
  required Ticket ticket,
  required Event event,
}) async {
  String imageSource = '${backend_url}api/image/${event.imageUrl}';
  String qrData = SimpleCodec.encode(jsonEncode({
    "tid": ticket.id,
    "eid": ticket.eventId,
    "dt": ticket.date,
  }));
  int qrSize = 200;
  int positionX = 50;
  int positionY = 50;
  int borderSize = 10;

  try {
    // Load base image
    final image = await ImageLoader.loadImage(imageSource);
    if (image == null) {
      throw Exception('Failed to load image');
    }

    final painter = QrPainter(
  data: qrData,
  version: QrVersions.auto,
  gapless: true,
);

final ui.Image uiImage = await painter.toImage(qrSize.toDouble());

final ByteData byteData =
    await uiImage.toByteData(format: ui.ImageByteFormat.png)
        as ByteData;

final Uint8List pngBytes = byteData.buffer.asUint8List();

final img.Image resizedQr = img.decodePng(pngBytes)!;

    /// 4️⃣ Create white background (slightly larger)
    final bgSize = qrSize + (borderSize * 2);
    final whiteBackground = img.Image(
      width: bgSize,
      height: bgSize,
    );

    img.fill(whiteBackground, color: img.ColorRgb8(255, 255, 255));

    /// 5️⃣ Draw QR centered on white background
    img.compositeImage(
      whiteBackground,
      resizedQr,
      dstX: borderSize,
      dstY: borderSize,
    );

    /// ✅ Final QR image with white background
    final qrImage = whiteBackground;

    /// 6️⃣ Composite QR onto main image
    img.compositeImage(
      image,
      qrImage,
      dstX: positionX,
      dstY: positionY,
    );

    /// 7️⃣ Save result
    final tempDir = await getTemporaryDirectory();
    final outputFile = File(
      '${tempDir.path}/image_with_qr_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );

    await outputFile.writeAsBytes(img.encodeJpg(image, quality: 90));
    debugPrint("image save at: ${outputFile.path}");
    return outputFile;
  } catch (e) {
    rethrow;
  }
}


  static img.Image _addBorderToImage(img.Image image, int borderSize) {
    final bordered = img.Image(
      width: image.width + (borderSize * 2),
      height: image.height + (borderSize * 2),
    );
    
    // Fill with white border
    img.fill(bordered, color: img.ColorRgba8(255, 255, 255, 255),);
    
    // Copy original image in the center
    // img.copyInto(bordered, image, dstX: borderSize, dstY: borderSize);
    
    return bordered;
  }
}

class ImageLoader {
  static Future<img.Image?> loadImage(String source) async {
    try {
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
    } catch (e) {
      print('❌ Error loading image: $e');
      return null;
    }
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

  static Future<img.Image?> _loadNetworkImage(String url) async {
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
    } catch (e) {
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

  static Future<void> preloadImage(String source) async {
    try {
      print('🔍 Preloading image: $source');
      await loadImage(source);
      print('✅ Image preloaded successfully');
    } catch (e) {
      print('❌ Image preload failed: $e');
    }
  }
}