import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/models/event.dart';
import 'package:intl/intl.dart';
import 'package:tiketi_mkononi/screens/checkout_page.dart';
import 'package:tiketi_mkononi/screens/confirm_page.dart';
import 'package:tiketi_mkononi/screens/edit_event_page.dart';
import 'package:http/http.dart' as http;
import 'package:tiketi_mkononi/screens/event_tickets_page.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class EventDetailsPage extends StatefulWidget {
  final Event event;
  final int userId;
  final Function refreshMethod;

  const EventDetailsPage({
    super.key,
    required this.event,
    required this.userId,
    required this.refreshMethod,
  });

  @override
  State<EventDetailsPage> createState() => _EventDetailsPageState();
}

class _EventDetailsPageState extends State<EventDetailsPage> {
  Event? event2;
  double? _imageHeight;
  double? _imageWidth;
  double? _earnings;
  final double _defaultExpandedHeight = 360;
  final WebSocketService _webSocketService = WebSocketService();
  bool _isWebSocketConnected = false;

  @override
  void initState() {
    super.initState();
    fetchEvent();
    _loadImageDimensions();
    _connectWebSocket();
  }

  @override
  void dispose() {
    _webSocketService.disconnect();
    super.dispose();
  }

  void _connectWebSocket() {
    if (_isWebSocketConnected) return;

    try {
      final String url = backend_ws_url;
      _webSocketService.connect(
        widget.userId,
        url,
        onUpdate: _handleWebSocketUpdate,
      );
      _isWebSocketConnected = true;
    } catch (e) {
      debugPrint('WebSocket connection error: $e');
    }
  }

  void _handleWebSocketUpdate() async {
    if (!mounted) return;
    try {
      fetchEvent();
    } catch (e) {
      debugPrint('Silent update error: $e');
    }
  }

  void fetchEvent() async {
    if (!mounted) return;
    widget.refreshMethod();

    try {
      final url = Uri.parse(
          '${backend_url}api/get_event/${widget.event.id}/${widget.userId}');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        Map<String, dynamic> jsonResponse = jsonDecode(response.body);

        setState(() {
          event2 = Event.fromJson(jsonResponse);
        });
      } else {
        debugPrint('Failed to load event');
      }
    } catch (e) {
      debugPrint('Silent update error: $e');
    }
  }

  String _formatDate(String date) {
    final DateFormat inputFormat = DateFormat('dd-MM-yyyy');
    final DateTime dateTime = inputFormat.parse(date);
    final DateFormat outputFormat = DateFormat('EEEE, MMMM d, yyyy');
    return outputFormat.format(dateTime);
  }

  void _loadImageDimensions() {
    final imageProvider = CachedNetworkImageProvider(
        '${backend_url}api/image/${widget.event.imageUrl}');
    imageProvider.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener((info, _) {
        if (mounted) {
          setState(() {
            _imageHeight = info.image.height.toDouble();
            _imageWidth = info.image.width.toDouble();
          });
        }
      }, onError: (_, __) {
        if (mounted) {
          setState(() {
            _imageHeight = null;
            _imageWidth = null;
          });
        }
      }),
    );
  }

  double _calculateExpandedHeight(BuildContext context) {
    if (_imageWidth == null || _imageHeight == null) {
      return _defaultExpandedHeight;
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final aspectRatio = _imageWidth! / _imageHeight!;
    return screenWidth / aspectRatio;
  }

  double _calculateEarnings(Event event) {
    return event.ticketTypes.fold(
        0, (sum, ticket) => sum + (ticket.price * ticket.soldTickets));
  }

  Widget _buildCategoryChip(String category) {
    final Map<String, Color> categoryColors = {
      'CONCERTS': Colors.orange[800]!,
      'SPORTS': Colors.red,
      'COMEDY': Colors.brown[600]!,
      'FUN': Colors.amber[500]!,
      'BARS & GRILLS': Colors.pink,
      'TRAINING': Colors.green,
      'THEATER': Colors.black,
    };

    return Chip(
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(0),
      label: Text(
        category.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          color: Colors.white,
        ),
      ),
      backgroundColor: categoryColors[category.toUpperCase()] ?? Colors.grey,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildEventDetailsCard(Event event, BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📅 ${_formatDate(event.date)}'),
            Text('⏰ ${event.time}'),
            Text('📍 ${event.venue}'),
            const SizedBox(height: 16),
            const Text(
              'Event Details',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(event.description),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  'Event Status: ',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Text(
                  '${event.status[0].toUpperCase()}${event.status.substring(1)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.normal,
                    color: (event.status == 'active') ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketsCard(Event event) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              (event.status == "active") ? 'Available Tickets' : "Tickets",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            ...event.ticketTypes.map((ticketType) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '${ticketType.name} ',
                                style: const TextStyle(
                                    fontSize: 18, color: Colors.black),
                              ),
                              if (event.status == "active" &&
                                  (ticketType.numberOfTickets -
                                          ticketType.soldTickets) <=
                                      0)
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.middle,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFD700),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'Sold Out',
                                      style: TextStyle(
                                        fontSize: 8,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              if (event.status == "active" &&
                                  !((ticketType.numberOfTickets -
                                          ticketType.soldTickets) <=
                                      0))
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.middle,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.orange[800],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${ticketType.soldTickets}/${ticketType.numberOfTickets}',
                                      style: const TextStyle(
                                        fontSize: 8,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        (event.type == 'paid')
                            ? 'TSH${ticketType.price.toInt()}'
                            : 'Free',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: (ticketType.numberOfTickets -
                                      ticketType.soldTickets) <=
                                  0
                              ? Colors.grey
                              : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(Event event, BuildContext context) {
    if (widget.userId != event.userId) {
      return Column(
        children: [
          if (event.type == 'paid' && event.status == "active")
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: event.hasTicket
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CheckoutPage(
                              event: event,
                              refreshMethod: fetchEvent,
                            ),
                          ),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor:
                      event.hasTicket ? Colors.orange[800] : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  event.hasTicket ? 'Booked' : 'Buy Tickets',
                  style: TextStyle(
                    fontSize: 16,
                    color: event.hasTicket
                        ? Colors.white
                        : Theme.of(context).primaryColor,
                  ),
                ),
              ),
            ),
          if (event.type == 'free' && event.status == "active")
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: event.hasTicket
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ConfirmPage(
                              event: event,
                              refreshMethod: fetchEvent,
                            ),
                          ),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor:
                      event.hasTicket ? Colors.orange[800] : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  event.hasTicket ? 'Confirmed' : 'Confirm',
                  style: TextStyle(
                    fontSize: 16,
                    color: event.hasTicket
                        ? Colors.white
                        : Theme.of(context).primaryColor,
                  ),
                ),
              ),
            ),
        ],
      );
    } else {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EditEventPage(
                  event: event,
                  userId: widget.userId,
                  refreshMethod: fetchEvent,
                ),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Colors.white,
          ),
          child: Text(
            'Edit Event',
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ),
      );
    }
  }

  Widget _buildDesktopLayout(Event event, BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxContentWidth = 1200.0;
    final contentPadding = screenWidth > maxContentWidth
        ? (screenWidth - maxContentWidth) / 2
        : 32.0;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: _calculateExpandedHeight(context),
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'event-image-${event.id}',
                child: CachedNetworkImage(
                  imageUrl: '${backend_url}api/image/${event.imageUrl}',
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[300],
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) =>
                      const Icon(Icons.error, size: 50, color: Colors.red),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(
                horizontal: contentPadding, vertical: 16),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.name,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _buildCategoryChip(event.category),
                                const Spacer(),
                                if ((widget.userId == event.userId) &&
                                    (event.type == "paid"))
                                  Card(
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    color: Colors.green[50],
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 3),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.monetization_on,
                                              size: 16, color: Colors.green),
                                          const SizedBox(width: 4),
                                          Text(
                                            'TSH $_earnings',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                TextButton(
                                  onPressed: (widget.userId == event.userId)
                                      ? () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  EventTicketsPage(
                                                event: event,
                                              ),
                                            ),
                                          );
                                        }
                                      : null,
                                  child: Text(
                                    event.type == 'free'
                                        ? '🎟️ ${event.soldTickets} Confirmed'
                                        : '🎟️ ${event.soldTickets} Sold',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.orange[800]),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildEventDetailsCard(event, context),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 1,
                        child: Column(
                          children: [
                            _buildTicketsCard(event),
                            const SizedBox(height: 16),
                            _buildActionButtons(event, context),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(Event event, BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: _calculateExpandedHeight(context),
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'event-image-${event.id}',
                child: CachedNetworkImage(
                  imageUrl: '${backend_url}api/image/${event.imageUrl}',
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[300],
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) =>
                      const Icon(Icons.error, size: 50, color: Colors.red),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildCategoryChip(event.category),
                      const Spacer(),
                      if ((widget.userId == event.userId) &&
                          (event.type == "paid"))
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          color: Colors.green[50],
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.monetization_on,
                                    size: 16, color: Colors.green),
                                const SizedBox(width: 4),
                                Text(
                                  'TSH $_earnings',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: (widget.userId == event.userId)
                            ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EventTicketsPage(
                                      event: event,
                                    ),
                                  ),
                                );
                              }
                            : null,
                        child: Text(
                          event.type == 'free'
                              ? '🎟️ ${event.soldTickets} Confirmed'
                              : '🎟️ ${event.soldTickets} Sold',
                          style: TextStyle(
                              fontSize: 11, color: Colors.orange[800]),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildEventDetailsCard(event, context),
                  const SizedBox(height: 16),
                  _buildTicketsCard(event),
                  const SizedBox(height: 24),
                  _buildActionButtons(event, context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var newEvent = widget.event;
    if (event2 != null) {
      newEvent = event2 as Event;
      _earnings = _calculateEarnings(event2!);
    } else {
      _earnings = _calculateEarnings(newEvent);
    }

    final isDesktop = MediaQuery.of(context).size.width >= 768;

    return isDesktop
        ? _buildDesktopLayout(newEvent, context)
        : _buildMobileLayout(newEvent, context);
  }
}

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  late WebSocketChannel _channel;
  Function()? _onUpdateCallback;

  factory WebSocketService() {
    return _instance;
  }

  WebSocketService._internal();

  void connect(int userId, String url, {required Function() onUpdate}) {
    _onUpdateCallback = onUpdate;
    _channel = WebSocketChannel.connect(Uri.parse(url));

    final subscriptionMessage = jsonEncode({
      "user_id": userId,
      "type": "subscribe",
      "data": "events_update"
    });

    debugPrint("[WebSocket] Sending subscription: $subscriptionMessage");
    _channel.sink.add(subscriptionMessage);

    _channel.stream.listen(
      (message) {
        final data = jsonDecode(message);
        debugPrint('Message: $message');

        if (data['type'] == 'events_updated') {
          debugPrint('Message 2: $message');
          _onUpdateCallback?.call();
        }
      },
      onError: (error) {
        debugPrint('WebSocket error: $error');
      },
      onDone: () {
        debugPrint('WebSocket connection closed');
      },
    );
  }

  void disconnect() {
    _channel.sink.close(1000);
  }

  void sendMessage(Map<String, dynamic> message) {
    _channel.sink.add(jsonEncode(message));
  }
}