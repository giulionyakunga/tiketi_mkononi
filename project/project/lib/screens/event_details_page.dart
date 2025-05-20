// This is the page that 

import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/models/event.dart';
import 'package:intl/intl.dart';
import 'package:tiketi_mkononi/screens/checkout_page.dart';
import 'package:tiketi_mkononi/screens/edit_event_page.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';


class EventDetailsPage extends StatefulWidget {
  final Event event;
  final int userId;
  final Function refreshMethod;

  const EventDetailsPage({super.key, required this.event, required this.userId, required this.refreshMethod});

  @override
  State<EventDetailsPage> createState() => _EventDetailsPageState();
}

class _EventDetailsPageState extends State<EventDetailsPage> {
  Event? event2;
  double? _imageHeight;
  double? _imageWidth;
  double? _earnings;
  final double _defaultExpandedHeight = 360; // Fallback height
  final WebSocketService _webSocketService = WebSocketService();
  bool _isWebSocketConnected = false;

  @override
  void initState() {
    super.initState();
    fetchEvent();
    _loadImageDimensions();
    _connectWebSocket();
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

      final url = Uri.parse('${backend_url}api/get_event/${widget.event.id}/${widget.userId}');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        // Parse the JSON string to a Map
        Map<String, dynamic> jsonResponse = jsonDecode(response.body);

        // Create the Event object using the factory method
        Event newEvent = Event.fromJson(jsonResponse);

        // Now you can use the event object
        debugPrint("newEvent.name ${newEvent.name}"); // Output: Sifang Seminar8

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
    final imageProvider = CachedNetworkImageProvider('${backend_url}api/image/${widget.event.imageUrl}');
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

  // Add this helper method to calculate earnings
  double _calculateEarnings(Event event) {
    return event.ticketTypes.fold(0, (sum, ticket) {
      return sum + (ticket.price * ticket.soldTickets);
    });
  }

  @override
  Widget build(BuildContext context) {
    var newEvent = widget.event;
    if(event2 != null){
      newEvent = event2 as Event;
      _earnings = _calculateEarnings(event2!);
    }else {
      _earnings = _calculateEarnings(newEvent);
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight:  _calculateExpandedHeight(context),
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'event-image-${newEvent.id}',
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: '${backend_url}api/image/${newEvent.imageUrl}',
                      fit: BoxFit.cover,
                      // fit: BoxFit.contain,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[300],
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => const Icon(Icons.error, size: 50, color: Colors.red),
                    ),
                    // Container(
                    //   decoration: BoxDecoration(
                    //     gradient: LinearGradient(
                    //       begin: Alignment.topCenter,
                    //       end: Alignment.bottomCenter,
                    //       colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                    //     ),
                    //   ),
                    // ),
                  ],
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
                    newEvent.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // Event Category & Sold Tickets
                  Row(
                    children: [
                      if (newEvent.category.toUpperCase() == "CONCERTS")
                      Chip(
                        labelPadding: const EdgeInsets.symmetric(horizontal: 4), // ← Reduces side padding
                        padding: const EdgeInsets.all(0), // ← Reduces overall chip padding
                        label: Text(
                          newEvent.category.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10, // Smaller text
                            color: Colors.white,
                          ),
                        ),
                        backgroundColor: Colors.blue,
                        labelStyle: const TextStyle(color: Colors.white),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, // ← Makes chip tighter
                      ),

                      if (newEvent.category.toUpperCase() == "SPORTS")
                      Chip(
                        labelPadding: const EdgeInsets.symmetric(horizontal: 4), // ← Reduces side padding
                        padding: const EdgeInsets.all(0), // ← Reduces overall chip padding
                        label: Text(
                          newEvent.category.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10, // Smaller text
                            color: Colors.white,
                          ),
                        ),
                        backgroundColor: Colors.red,
                        labelStyle: const TextStyle(color: Colors.white),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, // ← Makes chip tighter
                      ),

                      if (newEvent.category.toUpperCase() == "COMEDY")
                      Chip(
                        labelPadding: const EdgeInsets.symmetric(horizontal: 4), // ← Reduces side padding
                        padding: const EdgeInsets.all(0), // ← Reduces overall chip padding
                        label: Text(
                          newEvent.category.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10, // Smaller text
                            color: Colors.white,
                          ),
                        ),
                        backgroundColor: Colors.brown[600]!,
                        labelStyle: const TextStyle(color: Colors.white),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, // ← Makes chip tighter
                      ),

                      if (newEvent.category.toUpperCase() == "FUN")
                      Chip(
                        labelPadding: const EdgeInsets.symmetric(horizontal: 4), // ← Reduces side padding
                        padding: const EdgeInsets.all(0), // ← Reduces overall chip padding
                        label: Text(
                          newEvent.category.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10, // Smaller text
                            color: Colors.white,
                          ),
                        ),
                        backgroundColor: Colors.amber[500],
                        labelStyle: const TextStyle(color: Colors.white),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, // ← Makes chip tighter
                      ),

                      if (newEvent.category.toUpperCase() == "BARS & GRILLS")
                      Chip(
                        labelPadding: const EdgeInsets.symmetric(horizontal: 4), // ← Reduces side padding
                        padding: const EdgeInsets.all(0), // ← Reduces overall chip padding
                        label: Text(
                          newEvent.category.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10, // Smaller text
                            color: Colors.white,
                          ),
                        ),
                        backgroundColor: Colors.pink,
                        labelStyle: const TextStyle(color: Colors.white),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, // ← Makes chip tighter
                      ),

                      if (newEvent.category.toUpperCase() == "TRAINING")
                      Chip(
                        labelPadding: const EdgeInsets.symmetric(horizontal: 4), // ← Reduces side padding
                        padding: const EdgeInsets.all(0), // ← Reduces overall chip padding
                        label: Text(
                          newEvent.category.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10, // Smaller text
                            color: Colors.white,
                          ),
                        ),
                        backgroundColor: Colors.green,
                        labelStyle: const TextStyle(color: Colors.white),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, // ← Makes chip tighter
                      ),

                      if (newEvent.category.toUpperCase() == "THEATER")
                      Chip(
                        labelPadding: const EdgeInsets.symmetric(horizontal: 4), // ← Reduces side padding
                        padding: const EdgeInsets.all(0), // ← Reduces overall chip padding
                        label: Text(
                          newEvent.category.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10, // Smaller text
                            color: Colors.white,
                          ),
                        ),
                        backgroundColor: Colors.black,
                        labelStyle: const TextStyle(color: Colors.white),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, // ← Makes chip tighter
                      ),
                      const Spacer(),
                      // Replace the Chip with this Card for more emphasis
                      if (widget.userId == newEvent.userId)
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          color: Colors.green[50],
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.monetization_on, size: 16, color: Colors.green),
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
                      Row(
                        children: [
                          Text(
                            '🎟️ ${newEvent.soldTickets} Sold',
                            style: const TextStyle(fontSize: 11, color: Colors.blue),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Event Details
                  SizedBox(
                    width: double.infinity, // Takes full width
                    child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('📅 ${_formatDate(newEvent.date)}'),
                              Text('⏰ ${newEvent.time}'),
                              Text('📍 ${newEvent.venue}',),
                              const SizedBox(height: 16),
                              const Text(
                                'Event Details',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(newEvent.description),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                  ),

                  const SizedBox(height: 16),

                  // Ticket Prices
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            (newEvent.status == "active") ? 'Available Tickets' : "Tickets",
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const Divider(),
                          ...newEvent.ticketTypes.map((ticketType) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: 
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: RichText(
                                    text: TextSpan(
                                      children: [
                                        TextSpan( 
                                          text: '${ticketType.name} ',
                                          style: const TextStyle(fontSize: 18, color: Colors.black),
                                        ),
                                        if (newEvent.status == "active" &&
                                            (ticketType.numberOfTickets - ticketType.soldTickets) <= 0)
                                          WidgetSpan(
                                            alignment: PlaceholderAlignment.middle,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFFD700), // Gold color
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                'Sold Out (${ticketType.soldTickets})',
                                                style: const TextStyle(
                                                  fontSize: 8,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        if (newEvent.status == "active" &&
                                            !((ticketType.numberOfTickets - ticketType.soldTickets) <= 0))
                                          WidgetSpan(
                                            alignment: PlaceholderAlignment.middle,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: Colors.blue,
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
                                  'TSH${ticketType.price.toInt()}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: (ticketType.numberOfTickets - ticketType.soldTickets) <= 0 ? Colors.grey : Colors.orange,
                                  ),
                                ),
                              ],
                            ),






                            // Row(
                            //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            //   children: [
                            //     Row(
                            //       children: [
                            //         Text(ticketType.name, style: const TextStyle(fontSize: 14)),
                            //         if (newEvent.status == "active" && (ticketType.numberOfTickets - ticketType.soldTickets) <= 0)
                            //           Padding(
                            //             padding: const EdgeInsets.only(left: 8.0),
                            //             child: Container(
                            //               padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            //               decoration: BoxDecoration(
                            //                 color: Colors.red,
                            //                 borderRadius: BorderRadius.circular(8),
                            //               ),
                            //               child: Text(
                            //                 'Sold Out (${ticketType.soldTickets})',
                            //                 style: const TextStyle(
                            //                   fontSize: 10,
                            //                   color: Colors.white,
                            //                   fontWeight: FontWeight.bold,
                            //                 ),
                            //               ),
                            //             ),
                            //           ),


                            //         if (newEvent.status == "active" && !((ticketType.numberOfTickets - ticketType.soldTickets) <= 0) )
                            //           Padding(
                            //             padding: const EdgeInsets.only(left: 8.0),
                            //             child: Container(
                            //               padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            //               decoration: BoxDecoration(
                            //                 color: Colors.blue,
                            //                 borderRadius: BorderRadius.circular(8),
                            //               ),
                            //               child: Text(
                            //                 '${ticketType.soldTickets}/${ticketType.numberOfTickets}',
                            //                 style: const TextStyle(
                            //                   fontSize: 10,
                            //                   color: Colors.white,
                            //                   fontWeight: FontWeight.bold,
                            //                 ),
                            //               ),
                            //             ),
                            //           ),
                            //       ],
                            //     ),
                            //     Text(
                            //       'TSH${ticketType.price.toInt()}',
                            //       style: TextStyle(
                            //         fontSize: 14,
                            //         fontWeight: FontWeight.bold,
                            //         color: (ticketType.numberOfTickets - ticketType.soldTickets) <= 0 ? Colors.grey : Colors.orange,
                            //       ),
                            //     ),
                            //   ],
                            // ),
                          )),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  (widget.userId != newEvent.userId) ?
                  // Buy Ticket Button
                  SizedBox(
                    width: double.infinity,
                    child: (newEvent.status == "active") ?
                    ElevatedButton(
                      onPressed: newEvent.has_ticket ? null : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => CheckoutPage(event: newEvent, refreshMethod: fetchEvent)),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: newEvent.has_ticket ? Colors.blue : Colors.white,
                        disabledBackgroundColor: newEvent.has_ticket ? Colors.blue : Colors.white,
                      ),
                      child: Text(
                        newEvent.has_ticket ? 'Booked' : 'Buy Tickets',
                        style: TextStyle(
                          fontSize: 18,
                          color: newEvent.has_ticket ? Colors.white : Theme.of(context).primaryColor,
                        )
                      ),
                    )
                    : null,
                  ) :
                  // Edit Event Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => EditEventPage(event: newEvent, userId: widget.userId, refreshMethod: fetchEvent,)),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.white,
                        disabledBackgroundColor: Colors.white,
                      ),
                      child: Text(
                        'Edit Event',
                        style: TextStyle(
                          fontSize: 18,
                          color: Theme.of(context).primaryColor,
                        )
                      ),
                    ),
                  )


                ],
              ),
            ),
          ),
        ],
      ),
    );
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

    // Send subscription message
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
        // Implement reconnection logic here if needed
      },
      onDone: () {
        debugPrint('WebSocket connection closed');
        // Implement reconnection logic here if needed
      },
    );
  }

  void disconnect() {
    _channel.sink.close(1000); // Normal closure
    // _channel.sink.close();
  }

  void sendMessage(Map<String, dynamic> message) {
    _channel.sink.add(jsonEncode(message));
  }
}

