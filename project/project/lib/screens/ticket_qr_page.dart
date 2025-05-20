import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/models/ticket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
// import 'package:web_socket_channel/status.dart' as status;

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

  // Stream controllers
  final _connectionStatusController = StreamController<bool>.broadcast();
  final _ticketController = StreamController<Ticket>.broadcast();

  // Exposed streams
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;
  Stream<Ticket> get ticketStream => _ticketController.stream;

  Future<void> connect(userId, ticketId, scanStatus) async {
    if (scanStatus == 1) return;

    try {
      // First indicate we're attempting to connect
      _connectionStatusController.add(false);
      
      // Create the connection
      _channel = WebSocketChannel.connect(Uri.parse(url));
      
      // Wait for the connection to be ready
      await _channel!.ready;
      
      // Now we're truly connected
      _connectionStatusController.add(true);

      // Send initial message
      _channel!.sink.add(jsonEncode({
        "user_id": userId,
        "ticket_id": ticketId,
        "scan_status": scanStatus,
        "type": "subscribe",
        "data": "tickets"
      }));

      _channel!.stream.listen(
        (message) {
          print("Received: $message");
          _handleIncomingMessage(message);
        },
        onError: (error) {
          print("WebSocket Error: $error");
          _connectionStatusController.add(false);
          _scheduleReconnection(userId, ticketId, scanStatus);
        },
        onDone: () {
          print("WebSocket Disconnected");
          _connectionStatusController.add(false);
          _scheduleReconnection(userId, ticketId, scanStatus);
        },
      );
    } on TimeoutException catch (e) {
      print("Connection timeout: $e");
      _scheduleReconnection(userId, ticketId, scanStatus);
    } catch (e) {
      print("WebSocket Connection Failed: $e");
      _connectionStatusController.add(false);
      // Consider reconnection logic here
      _scheduleReconnection(userId, ticketId, scanStatus);
    }
  }

  void _scheduleReconnection(userId, ticketId, scanStatus) {
    if (_isDisposed || _reconnectAttempts >= maxReconnectAttempts) return;

    _reconnectAttempts++;
    _connectionStatusController.add(false);
    
    print("Attempting reconnect ($_reconnectAttempts/$maxReconnectAttempts)...");
    
    _reconnectTimer = Timer(reconnectInterval * _reconnectAttempts, () {
      connect(userId, ticketId, scanStatus);
    });
  }

  void _handleIncomingMessage(String message) {
    try {
      final Map<String, dynamic> data = jsonDecode(message);
      print("DAta : $data");
      if (data['type'] == 'ticket') {
        final ticket = Ticket.fromJson(data['ticket']);
        _ticketController.add(ticket);
      }
    } catch (e) {
      print("Error parsing message: $e");
    }
  }

  void disconnect() {
    // _channel?.sink.close(status.goingAway);
    _channel?.sink.close(1000); // 1000 = "Normal closure"
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
  late final WebSocketService _webSocketService; // Store the service

  @override
  void initState() {
    super.initState();
    _webSocketService = ref.read(websocketServiceProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _webSocketService.connect(
        widget.userId,
        widget.ticketId,
        widget.scanStatus,
      );
    });
  }


  @override
  void dispose() {
    _webSocketService.disconnect(); // No longer uses `ref`
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ticket QR Code'),
        backgroundColor: const Color.fromARGB(255, 240, 244, 247),
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
                        const SizedBox(height: 8),
                        QrImageView(
                          data: jsonEncode(
                            {
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
                              "createdAt": widget.createdAt.toIso8601String(), // Convert DateTime to String if needed
                            }
                          ),
                          version: QrVersions.auto,
                          size: 200.0,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.eventName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 300), // or any reasonable max
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              widget.ticketType,
                              style: const TextStyle(color: Colors.white),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2, // Truncate instead of expanding
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.date,
                          style: const TextStyle(fontSize: 18),
                        ),
                        Text(
                          widget.time,
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.venue,
                          style: const TextStyle(fontSize: 18),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Present this QR code at the venue',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),

                        const SizedBox(height: 10),
                        StreamBuilder<bool>(
                          stream: _webSocketService.connectionStatusStream,
                          builder: (context, snapshot) {
                            print("StreamBuilder snapshot: ${snapshot.data}"); // Debugging
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

                        const SizedBox(height: 12),

                        (widget.scanStatus == 1) ?
                        const Row(
                          children: [
                            Icon(
                              size: 80,
                              Icons.check_circle, 
                              color: Colors.blue
                            ), // Your icon
                            SizedBox(width: 10), // Add some spacing
                            Expanded(child: Text("Used Ticket!")), // Prevent overflow
                          ],
                        ) :
                        StreamBuilder<Ticket>(
                          stream: _webSocketService.ticketStream,
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const Center(child: Text('Please wait.'));
                            }

                            final ticket = snapshot.data!;
                            if(ticket.scanStatus == 1) {
                              if(widget.ticketId == ticket.id) {
                                return const Icon(
                                  size: 80,
                                  Icons.check_circle,
                                  color: Colors.green,
                                );
                              }else {
                                return const Text("Please wait..");
                              }
                            }else {
                              return const Text("Please wait...");
                            }
                          },
                        ),
                        const SizedBox(height: 4),
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