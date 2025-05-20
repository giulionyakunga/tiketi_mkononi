import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/models/ticket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
// import 'package:web_socket_channel/status.dart' as status;


// Provider setup
final websocketServiceProvider = Provider<WebSocketService>((ref) {
  return WebSocketService();
});

class WebSocketService {
  final String url = backend_ws_url;
  WebSocketChannel? _channel;
  bool _isConnected = false;
  bool _isDisposed = false;

  // Stream controllers
  final _connectionStatusController = StreamController<bool>.broadcast();
  final _ticketController = StreamController<Ticket>.broadcast();

  // Exposed streams
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;
  Stream<Ticket> get ticketStream => _ticketController.stream;

  void connect(int userId, int ticketId, int scanStatus) {
    if (_isConnected || _isDisposed) return;
    if (scanStatus == 1) return;

    print("[WebSocket] Attempting to connect to $url...");
    
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _isConnected = true;
      
      // Initial connection status update
      print("[WebSocket] Connection established, updating status");
      _connectionStatusController.add(true);

      // Send subscription message
      final subscriptionMessage = jsonEncode({
        "user_id": userId,
        "ticket_id": ticketId,
        "scan_status": scanStatus,
        "type": "subscribe",
        "data": "tickets"
      });
      
      print("[WebSocket] Sending subscription: $subscriptionMessage");
      _channel!.sink.add(subscriptionMessage);

      // Listen for messages
      _channel!.stream.listen(
        (message) {
          print("[WebSocket] Received message: $message");
          _handleIncomingMessage(message);
        },
        onError: (error) {
          print("[WebSocket] Error occurred: $error");
          _markDisconnected();
        },
        onDone: () {
          print("[WebSocket] Connection closed by server");
          _markDisconnected();
        },
      );
    } catch (e) {
      print("[WebSocket] Connection failed: $e");
      _markDisconnected();
    }
  }

  void _handleIncomingMessage(String message) {
    try {
      final Map<String, dynamic> data = jsonDecode(message);
      print("[WebSocket] Parsed data: $data");
      
      if (data['type'] == 'ticket') {
        final ticket = Ticket.fromJson(data['ticket']);
        print("[WebSocket] Received ticket update: ${ticket.id}");
        _ticketController.add(ticket);
      }
    } catch (e) {
      print("[WebSocket] Error parsing message: $e");
    }
  }

  void _markDisconnected() {
    if (!_isConnected || _isDisposed) return;
    
    print("[WebSocket] Marking as disconnected");
    _isConnected = false;
    _connectionStatusController.add(false);
  }

  void disconnect() {
    if (_isDisposed) return;
    
    print("[WebSocket] Disconnecting...");
    _isDisposed = true;
    _markDisconnected();
    
    try {
      _channel?.sink.close(1000); // Normal closure
      print("[WebSocket] Closed channel successfully");
    } catch (e) {
      print("[WebSocket] Error closing channel: $e");
    } finally {
      _connectionStatusController.close();
      _ticketController.close();
      print("[WebSocket] Stream controllers closed");
    }
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
  bool _initialConnectionAttempted = false;

  @override
  void initState() {
    super.initState();
    print("[TicketQRPage] Initializing...");
    _webSocketService = ref.read(websocketServiceProvider);
    
    // Delay connection slightly to ensure widget is mounted
    Future.delayed(Duration.zero, () {
      if (!mounted) return;
      _initialConnectionAttempted = true;
      _webSocketService.connect(
        widget.userId,
        widget.ticketId,
        widget.scanStatus,
      );
    });
  }

  @override
  void dispose() {
    print("[TicketQRPage] Disposing...");
    if (_initialConnectionAttempted) {
      _webSocketService.disconnect();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print("[TicketQRPage] Building widget...");
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ticket QR Code'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Text(
                        "\"kama una tiketi mkononi tayari upo ndani ya burudani\"",
                        style: TextStyle(
                          fontSize: 14,
                          fontStyle: FontStyle.italic, // Makes text italic
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 10),
                      
                      // QR Code
                      QrImageView(
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
                        size: 200.0,
                      ),
                      const SizedBox(height: 20),
                      
                      // Event Info
                      Text(
                        widget.eventName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(widget.date, style: const TextStyle(fontSize: 18)),
                      Text(widget.time, style: const TextStyle(fontSize: 18)),
                      const SizedBox(height: 8),
                      Text(widget.venue, style: const TextStyle(fontSize: 18)),
                      const SizedBox(height: 20),
                      const Text(
                        'Present this QR code at the venue',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      
                      // Connection Status
                      StreamBuilder<bool>(
                        stream: _webSocketService.connectionStatusStream,
                        initialData: false,
                        builder: (context, snapshot) {
                          print("[ConnectionStatus] Update: ${snapshot.data}");
                          final isConnected = snapshot.data ?? false;
                          return AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: ListTile(
                              key: ValueKey<bool>(isConnected),
                              title: const Text('Connection Status'),
                              subtitle: Text(isConnected ? 'Connected' : 'Disconnected'),
                              trailing: Icon(
                                isConnected ? Icons.check_circle : Icons.error,
                                color: isConnected ? Colors.green : Colors.red,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      
                      // Ticket Status
                      StreamBuilder<Ticket>(
                        stream: _webSocketService.ticketStream,
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(child: Text('Awaiting ticket updates...'));
                          }

                          final ticket = snapshot.data!;
                          if (ticket.scanStatus == 1 && widget.ticketId == ticket.id) {
                            return const Column(
                              children: [
                                Icon(
                                  size: 80,
                                  Icons.check_circle,
                                  color: Colors.green,
                                ),
                                Text("Ticket scanned successfully!"),
                              ],
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
