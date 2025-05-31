import 'dart:convert';
import 'dart:io';
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
import 'package:tiketi_mkononi/screens/qr_scanner_page.dart';
import 'package:tiketi_mkononi/screens/set_scanner_page.dart';
import 'package:tiketi_mkononi/screens/tickets_page.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:url_launcher/url_launcher.dart';

class EventDetailsPage extends StatefulWidget {
  final Event event;
  final int userId;
  final Function refreshMethod;
  final bool useDNS;

  const EventDetailsPage({
    super.key,
    required this.event,
    required this.userId,
    required this.refreshMethod,
    required this.useDNS,
  });

  @override
  State<EventDetailsPage> createState() => _EventDetailsPageState();
}

class _EventDetailsPageState extends State<EventDetailsPage> {
  Event? event2;
  double? _imageHeight;
  double? _imageWidth;
  final double _defaultExpandedHeight = 360;
  final WebSocketService _webSocketService = WebSocketService();
  bool _isWebSocketConnected = false;
  String organiser_name = "";
  String organiser_phone_number = "";

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

  void fetchEvent({bool useDNS = true}) async {
    if (!mounted) return;
    widget.refreshMethod();

    try {
      final Uri uri = useDNS ? Uri.parse('${backend_url}api/get_event/${widget.event.id}/${widget.userId}') // Original URL 
      : Uri.parse('${backend_url_with_fallback_ip}api/get_event/${widget.event.id}/${widget.userId}'); // Use IP
        
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        Map<String, dynamic> jsonResponse = jsonDecode(response.body);

        setState(() {
          event2 = Event.fromJson(jsonResponse);
          organiser_name = jsonResponse['user']['first_name'] + " " + jsonResponse['user']['last_name'];
          organiser_phone_number = jsonResponse['user']['phone_number'];
        });
      } else {
        debugPrint('Failed to load event');
      }
    }on SocketException catch (e) {
        debugPrint('Network error occurred:');
        debugPrint('- Exception type: ${e.runtimeType}');
        debugPrint('- Message: ${e.message}');
        
        if (e.osError != null) {
          debugPrint('  - Error number (errno): ${e.osError!.errorCode}');
          debugPrint('  - OS message: ${e.osError!.message}');

          // Retry with IP if DNS fails (errno = 7) and not already retrying
          if (e.osError!.errorCode == 7 && useDNS) {
            debugPrint('DNS failed! Retrying with IP: ${backend_url_with_fallback_ip}...');
            fetchEvent(useDNS: false); // Recursive retry
            return;
          }
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

  String formatNumber(int num) {
    if (num >= 1000 && num < 1000000) {
      double result = num / 1000;
      return '${result.toStringAsFixed(result.truncateToDouble() == result ? 0 : 1)}k';
    } else if (num >= 1000000) {
      double result = num / 1000000;
      return '${result.toStringAsFixed(result.truncateToDouble() == result ? 0 : 1)}M';
    } else {
      return num.toString();
    }
  }

  void _loadImageDimensions() {
    final imageProvider = CachedNetworkImageProvider(
        widget.useDNS ? '${backend_url}api/image/${widget.event.imageUrl}' : '${backend_url_with_fallback_ip}api/image/${widget.event.imageUrl}'
      );
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

  bool existsTicketUpdatedAfterEvent(Event event) {
    return event.tickets.any((ticket) {
      final ticketUpdatedAt = ticket['updatedAt'] is DateTime 
          ? ticket['updatedAt'] as DateTime
          : DateTime.parse(ticket['updatedAt'] as String);
      return ticketUpdatedAt.isAfter(event.updatedAt);
    });
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


  Widget _buildEventDetailsCard(Event event, BuildContext context) {
    return 
    Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            (event.daily_event == 'yes') ? Text('📅 Everyday') : Text('📅 ${_formatDate(event.date)}'),
            (event.time.contains(":")) ? Text('⏰ ${event.time}') : Text('⏰ Everytime'),
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
            const SizedBox(height: 6),
            // Ticket Information Column
            Column(
              crossAxisAlignment: CrossAxisAlignment.start, // Align all items to the start
              children: [
                ...event.ticketTypes.where((ticketType) => ticketType.ticketInformation.trim().isNotEmpty)
                .map((ticketType) => Padding(
                  padding: const EdgeInsets.only(bottom: 8), // Add spacing between items
                  child: TextButton(
                    onPressed: null,
                    style: TextButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '${ticketType.name}: ',
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: ticketType.ticketInformation,
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.black,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )).toList(), // Don't forget to convert the map to a list
              ],
            ),
            const SizedBox(height: 8),
            // Event Status Row
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
            
            // Uniform spacing between all elements
            const SizedBox(height: 4),  // Reduced from default 8 to 4
            // Organizer Name
            if(organiser_name != "")
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Organized By: ',
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.black,
                      fontWeight: FontWeight.bold
                    ),
                  ),
                  TextSpan(
                    text: organiser_name,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.black,
                      fontWeight: FontWeight.normal
                    ),
                  ),
                ]
              )
            ),
            
            // Uniform spacing between all elements
            const SizedBox(height: 4),  // Consistent spacing
            
            // Organizer Contact
            if(organiser_phone_number != "")
            TextButton(
              onPressed: () => _launchPhoneCall(organiser_phone_number),
              style: TextButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.zero,  // Removed vertical padding
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Organizer Contact: ',
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.black,
                        fontWeight: FontWeight.bold
                      ),
                    ),
                    TextSpan(
                      text: organiser_phone_number,
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.blue,
                        fontWeight: FontWeight.normal
                      ),
                    ),
                  ]
                )
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget _buildEventDetailsCard(Event event, BuildContext context) {
  //   return Card(
  //     elevation: 2,
  //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  //     child: Padding(
  //       padding: const EdgeInsets.all(16),
  //       child: Column(
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           Text('📅 ${_formatDate(event.date)}'),
  //           Text('⏰ ${event.time}'),
  //           Text('📍 ${event.venue}'),
  //           const SizedBox(height: 16),
  //           const Text(
  //             'Event Details',
  //             style: TextStyle(
  //               fontSize: 16,
  //               fontWeight: FontWeight.bold,
  //             ),
  //           ),
  //           const SizedBox(height: 8),
  //           Text(event.description),
  //           const SizedBox(height: 8),
  //           Row(
  //             children: [
  //               const Text(
  //                 'Event Status: ',
  //                 style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
  //               ),
  //               const SizedBox(width: 8),
  //               Text(
  //                 '${event.status[0].toUpperCase()}${event.status.substring(1)}',
  //                 style: TextStyle(
  //                   fontSize: 14,
  //                   fontWeight: FontWeight.normal,
  //                   color: (event.status == 'active') ? Colors.green : Colors.red,
  //                 ),
  //               ),
  //             ],
  //           ),
  //           if(organiser_name != "")
  //           RichText(
  //             text: TextSpan(
  //               children: [
  //                 TextSpan(
  //                   text: 'Organized By: ',
  //                   style: const TextStyle(
  //                     fontSize: 18,
  //                     color: Colors.black,
  //                     fontWeight: FontWeight.bold
  //                   ),
  //                 ),
  //                 TextSpan(
  //                   text: organiser_name,
  //                   style: TextStyle(
  //                     fontSize: 18,
  //                     color: Colors.black,
  //                     fontWeight: FontWeight.normal
  //                   ),
  //                 ),
  //               ]
  //             )
  //           ),
  //           const SizedBox(height: 1),
  //           if(organiser_phone_number != "")
  //           TextButton(
  //             onPressed: () => _launchPhoneCall(organiser_phone_number),
  //             style: TextButton.styleFrom(
  //               alignment: Alignment.centerLeft, // Force left alignment
  //               padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 1),
  //             ),
  //             child: 
  //               RichText(
  //                 text: TextSpan(
  //                   children: [
  //                     TextSpan(
  //                       text: 'Organizer Contact: ',
  //                       style: const TextStyle(
  //                         fontSize: 18,
  //                         color: Colors.black,
  //                         fontWeight: FontWeight.bold
  //                       ),
  //                     ),
  //                     TextSpan(
  //                       text: '$organiser_phone_number',
  //                       style: TextStyle(
  //                         fontSize: 18,
  //                         color: Colors.blue,
  //                         fontWeight: FontWeight.normal
  //                       ),
  //                     ),
  //                   ]
  //                 )
  //               ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

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
                                      '${NumberFormat('#,##0').format(ticketType.soldTickets)}/${NumberFormat('#,##0').format(ticketType.numberOfTickets)}',
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
                            ? 'TSH${NumberFormat('#,##0').format(ticketType.price.toInt())}'
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
                onPressed: () {
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
                onPressed: 
                // (existsTicketUpdatedAfterEvent(event)) ? null :
                () {
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
                child: 
                CachedNetworkImage(
                  imageUrl: '${backend_url}api/image/${event.imageUrl}',
                  // imageUrl: widget.useDNS ? '${backend_url}api/image/${event.imageUrl}' : '${backend_url_with_fallback_ip}api/image/${event.imageUrl}',
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[300],
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) {
                    return const Icon(Icons.error);
                  },
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
                                if(event.hasTicket)
                                TextButton(
                                  child: Text(
                                    "View Ticket",
                                    style: TextStyle(
                                      fontSize: 11, 
                                      color: Colors.green
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => TicketsPage(eventId: event.id),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 2),
                                if (widget.userId == event.userId)
                                Text(
                                  'ID: ${event.id}',
                                  style: TextStyle(
                                    fontSize: 11, 
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(width: 1),

                                if (widget.userId == event.userId)
                                TextButton(
                                  onPressed: (widget.userId == event.userId)
                                    ? () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => SetScannerPage(userId: widget.userId, eventId: event.id),
                                          ),
                                        );
                                      }
                                    : null,
                                  child: const Icon(
                                    Icons.assignment_ind,
                                    size: 16,
                                    color: Colors.green
                                  ),
                                ),
                                const SizedBox(width: 1),

                                if ((widget.userId == event.userId) || (widget.userId == event.ticketScannerId))
                                TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => QRScannerPage(userId: widget.userId, eventId: event.id),
                                      ),
                                    );
                                  },
                                  child: const Icon(
                                    Icons.qr_code_scanner,
                                    size: 16,
                                    color: Colors.green
                                  ),
                                ),
                                const SizedBox(width: 2),
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
                                        ? '🎟️ ${formatNumber(event.soldTickets)} Confirmed'
                                        : '🎟️ ${formatNumber(event.soldTickets)} Sold',
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
                child: 
                CachedNetworkImage(
                  imageUrl: widget.useDNS ? '${backend_url}api/image/${event.imageUrl}' : '${backend_url_with_fallback_ip}api/image/${event.imageUrl}',
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[300],
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) {
                    return const Icon(Icons.error);
                  }
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
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: _buildCategoryChip(event.category),
                        ),
                        if(event.hasTicket)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: TextButton(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: (event.tickets.length > 1) ?
                            Text(
                              "View Tickets",
                              style: TextStyle(
                                fontSize: 11, 
                                color: Colors.green
                              ),
                            ) : 
                            Text(
                              "View Ticket",
                              style: TextStyle(
                                fontSize: 11, 
                                color: Colors.green
                              ),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TicketsPage(eventId: event.id),
                                ),
                              );
                            },
                          ),
                        ),
                        if (widget.userId == event.userId)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'ID: ${event.id}',
                            style: TextStyle(
                              fontSize: 11, 
                              color: Colors.black
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (widget.userId == event.userId)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: TextButton(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: (widget.userId == event.userId)
                              ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => SetScannerPage(userId: widget.userId, eventId: event.id),
                                    ),
                                  );
                                }
                              : null,
                            child: const Icon(
                              Icons.assignment_ind,
                              size: 16,
                              color: Colors.green
                            ),
                          ),
                        ),
                        const SizedBox(height: 50),
                        if ((widget.userId == event.userId) || (widget.userId == event.ticketScannerId))
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: TextButton(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => QRScannerPage(userId: widget.userId, eventId: event.id),
                                ),
                              );
                            },
                            child: const Icon(
                              Icons.qr_code_scanner,
                              size: 16,
                              color: Colors.green
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: TextButton(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
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
                                  ? '🎟️ ${formatNumber(event.soldTickets)} Confirmed'
                                  : '🎟️ ${formatNumber(event.soldTickets)} Sold',
                              style: TextStyle(
                                  fontSize: 11, 
                                  color: Colors.orange[800],
                                  overflow: TextOverflow.ellipsis
                                ),
                            ),
                          ),
                        ),
                      ],
                    ),
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