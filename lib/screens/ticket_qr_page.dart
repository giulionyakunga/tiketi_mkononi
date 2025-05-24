import 'dart:convert';
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
  final String url = backend_ws_url;
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

  Future<void> connect(userId, ticketId, scanStatus) async {
    if (scanStatus == 1) return;

    try {
      _connectionStatusController.add(false);
      _channel = WebSocketChannel.connect(Uri.parse(url));
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
    required this.createdAt,
  });

  @override
  ConsumerState<TicketQRPage> createState() => _TicketQRPageState();
}

class _TicketQRPageState extends ConsumerState<TicketQRPage> {
  late final WebSocketService _webSocketService;

  @override
  void initState() {
    super.initState();
    if(widget.scanStatus != 1) {
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

  bool _isLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.width > 768;
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
            fontSize: isLargeScreen ? 28 : 24,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
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
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 8),
        Text(
            (widget.price > 0.0) ? 'TSH${NumberFormat('#,##0').format(widget.price.toInt())}' : 'Free',
            style: TextStyle(fontSize: isLargeScreen ? 20 : 18),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: isLargeScreen ? 24 : 20),
            const SizedBox(width: 8),
            Text(
              widget.date,
              style: TextStyle(fontSize: isLargeScreen ? 20 : 18),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.access_time, size: isLargeScreen ? 24 : 20),
            const SizedBox(width: 8),
            Text(
              widget.time,
              style: TextStyle(fontSize: isLargeScreen ? 20 : 18),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_on, size: isLargeScreen ? 24 : 20),
            Flexible(
              child: Text(
                widget.venue,
                style: TextStyle(fontSize: isLargeScreen ? 20 : 18),
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis, // Optional: handles overflow with ellipsis
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Present this QR code at the venue',
          style: TextStyle(
            fontSize: isLargeScreen ? 18 : 16,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusSection() {
    if (widget.scanStatus == 1) {
      return Column(
        children: [
          const SizedBox(height: 14),
          Icon(
            Icons.check_circle,
            size: 80,
            color: Colors.orange[800],
          ),
          const SizedBox(height: 8),
          const Text(
            "Ticket Already Used",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        const SizedBox(height: 14),
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
        const SizedBox(height: 14),
        StreamBuilder<Ticket>(
          stream: _webSocketService.ticketStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: Text(
                  'Waiting for scanner...',
                  style: TextStyle(fontSize: 16),
                ),
              );
            }

            final ticket = snapshot.data!;
            if (ticket.scanStatus == 1 && widget.ticketId == ticket.id) {
              return Column(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 80,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Ticket Scanned Successfully!",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              );
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
                            const SizedBox(height: 20),
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