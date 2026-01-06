import 'dart:convert';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/models/event.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:tiketi_mkononi/screens/event_providers.dart';
import 'package:go_router/go_router.dart';
import 'package:tiketi_mkononi/screens/tickets_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

class ConfirmAttendancePage extends StatefulWidget {
  final Event event;
  final String ticketCode;

  const ConfirmAttendancePage({
    super.key,
    required this.event,
    required this.ticketCode,
  });

  @override
  State<ConfirmAttendancePage> createState() => _ConfirmAttendancePageState(); 
}

class _ConfirmAttendancePageState extends State<ConfirmAttendancePage> {
  Event? event2;
  double? _imageHeight;
  double? _imageWidth;
  final double _defaultExpandedHeight = 360;
  String organiser_name = "";
  String organiser_phone_number = "";
  int eventTicketsCount = 0;
  Map<String, dynamic> ticketTypesTicketsCount = {};
  bool isDeepLink = false;
  bool isConfirmed = false;

  @override
  void initState() {
    super.initState();
    getTicketsCount();
    fetchEvent();
    _loadImageDimensions();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    try {

      final state = GoRouterState.of(context);

      isDeepLink = ((state.extra == null) && (state.fullPath == '/event/:id'));

      debugPrint("Extra : ${state.extra}");
      debugPrint("Path : ${state.uri.path}");
      debugPrint("FullPath : ${state.fullPath}");

      // Optionally: do something once when opened from deep link
      if (isDeepLink) {
        debugPrint("This page was opened from a link.");
      } else {
        debugPrint("This page was opened via in-app navigation.");
      }
    } catch (_) {
      isDeepLink = false;
    }

    
  }

  @override
  void dispose() {
    final container = ProviderScope.containerOf(context);
    container.read(selectedEventProvider.notifier).state = null;

    super.dispose();
  }

  Future<void> getTicketsCount({bool useDNS = true}) async {

    final Uri uri = useDNS ? Uri.parse('${backend_url}api/event_tickets_count/${widget.event.id}') // Original URL 
    : Uri.parse('${backend_url_with_fallback_ip}api/event_tickets_count/${widget.event.id}'); // Use IP

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if((responseData['tickets_count']) != null){
          setState(() {
            eventTicketsCount = responseData['tickets_count'];
            ticketTypesTicketsCount = responseData['ticket_types'];
          });
        }
        
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
          await getTicketsCount(useDNS: false); // Recursive retry
          return;
        }
      }
    } catch (e) {
      debugPrint('Error fetching check tickets scan status: $e');
    }
  }

  Future<void> confirmAttendance({bool useDNS = true}) async {

    final Uri uri = useDNS ? Uri.parse('${backend_url}api/confirm_attendance/${widget.event.id}/${widget.ticketCode}') // Original URL 
    : Uri.parse('${backend_url_with_fallback_ip}api/confirm_attendance/${widget.event.id}/${widget.ticketCode}'); // Use IP

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        if (response.body == "Attendance confirmed successfully!") {
          setState(() {
            isConfirmed = true;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.body)),
          );
        } else {
          _showSnackBar('Request failed: ${response.body}');
        }
      } else if (response.statusCode == 302) {
        _handleHTTPRedirect();
      } else {
        if (response.statusCode == 413) {
          _showSnackBar('Request failed: Image is Too Large');
        } else {
          _showSnackBar('Request failed: ${response.statusCode}');
        }
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
          await confirmAttendance(useDNS: false); // Recursive retry
          return;
        }
      }
    } catch (e) {
      debugPrint('Error fetching check tickets scan status: $e');
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

  int getTicketTypesTicketsCount (Map<String, dynamic> ticketTypesTicketsCount, String name) {

    if (ticketTypesTicketsCount.isNotEmpty) {
      return ticketTypesTicketsCount[name];
    }
    return 0;
  }

  void fetchEvent({bool useDNS = true}) async {
    if (!mounted) return;

    try {
      final Uri uri = useDNS ? Uri.parse('${backend_url}api/get_event/${widget.event.id}/0') // Original URL 
      : Uri.parse('${backend_url_with_fallback_ip}api/get_event/${widget.event.id}/0'); // Use IP
        
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
    try {
      final DateFormat inputFormat = DateFormat('dd-MM-yyyy');
      final DateTime dateTime = inputFormat.parse(date);
      final DateFormat outputFormat = DateFormat('EEEE, MMMM d, yyyy');
      return outputFormat.format(dateTime);
    } catch (e) {
      return date;
    }
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
        '${backend_url}api/image/${widget.event.imageUrl}'
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

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      throw Exception('Could not launch $url');
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
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _launchUrl(event.locationLink),                  
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
                      text: 'Location ',
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.black,
                        fontWeight: FontWeight.bold
                      ),
                    ),
                    TextSpan(
                      text: 'link ->',
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

  Widget _buildActionButtons(Event event, BuildContext context) {
      return Column(
        children: [
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: 
              () async {
                confirmAttendance();
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: isConfirmed ? Colors.orange[800] : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                isConfirmed ? 'Confirmed' : 'Confirm',
                style: TextStyle(
                  fontSize: 16,
                  color: isConfirmed
                      ? Colors.white
                      : Colors.orange[800],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          ElevatedButton.icon(
            icon: const Icon(Icons.logout),
            label: Text('See Other Events', style: TextStyle(
              fontSize: 14,
            )
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.orange[800],
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            onPressed: () {
              context.push('/home');
            },
          ),
          const SizedBox(height: 8),
        ],
      );
    
  }

  Widget _buildDesktopLayout(Event event, BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 600;
    final isVeryLargeScreen = screenWidth > 1200;

    return Scaffold(
      appBar: AppBar(
        title: (event.category.toUpperCase() == "THEATER") ? const Text('Cinema Details') : const Text('Event Details'),
        backgroundColor: const Color.fromARGB(255, 240, 244, 247),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isVeryLargeScreen ? 800 : (isLargeScreen ? 600 : double.infinity),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isLargeScreen ? 24 : 16,
              vertical: 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Hero(
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
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: TextButton(
                                    onPressed: () async {
                                      final eventId = event.id;
                                      final link = "https://tiketimkononi.telabs.co.tz/event/$eventId";

                                      if (kIsWeb) {
                                        await Clipboard.setData(ClipboardData(text: "Check out this event! 🎟️\n$link"));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Link copied to clipboard!')),
                                        );
                                      } else {
                                        Share.share("Check out this event! 🎟️\n$link");
                                      }
                                    },
                                    child: const Icon(
                                      Icons.share,
                                      size: 18,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(left: 12),
                                  child: TextButton(
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: null,
                                    child: Text(
                                      event.type == 'free'
                                          ? '🎟️ $eventTicketsCount Confirmed'
                                          : '🎟️ $eventTicketsCount Sold',
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
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
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
                  imageUrl: '${backend_url}api/image/${event.imageUrl}',
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
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: TextButton(
                            onPressed: () async {
                              final eventId = event.id;
                              final link = "https://tiketimkononi.telabs.co.tz/event/$eventId";

                              if (kIsWeb) {
                                await Clipboard.setData(ClipboardData(text: "Check out this event! 🎟️\n$link"));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Link copied to clipboard!')),
                                );
                              } else {
                                Share.share("Check out this event! 🎟️\n$link");
                              }
                            },
                            child: const Icon(
                              Icons.share,
                              size: 18,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildEventDetailsCard(event, context),
                  const SizedBox(height: 16),
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
