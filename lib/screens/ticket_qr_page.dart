import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/models/ticket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

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
                                  _buildQRCodeSection(isLargeScreen),
                                  const SizedBox(height: 20),
                                  _buildStatusSection(),
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
                            _buildQRCodeSection(isLargeScreen),
                            const SizedBox(height: 1),
                            _buildEventInfoSection(isLargeScreen),
                            _buildStatusSection(),
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