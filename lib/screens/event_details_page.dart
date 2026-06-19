import 'dart:convert';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/models/event.dart';
import 'package:intl/intl.dart';
import 'package:tiketi_mkononi/screens/auth/login_screen.dart';
import 'package:tiketi_mkononi/screens/checkout_page.dart';
import 'package:tiketi_mkononi/screens/confirm_page.dart';
import 'package:tiketi_mkononi/screens/edit_event_page.dart';
import 'package:http/http.dart' as http;
import 'package:tiketi_mkononi/screens/event_pledges_page.dart';
import 'package:tiketi_mkononi/screens/event_providers.dart';
import 'package:tiketi_mkononi/screens/event_tickets_page.dart';
import 'package:go_router/go_router.dart';
import 'package:tiketi_mkononi/screens/generate_cards_page.dart';
import 'package:tiketi_mkononi/screens/qr_scanner_page.dart';
import 'package:tiketi_mkononi/screens/send_pledge_requests_page.dart';
import 'package:tiketi_mkononi/screens/send_reminder_messages_page.dart';
import 'package:tiketi_mkononi/screens/set_scanner_page.dart';
import 'package:tiketi_mkononi/screens/theater_checkout_page.dart';
import 'package:tiketi_mkononi/screens/theater_confirm_page.dart';
import 'package:tiketi_mkononi/screens/tickets_page.dart';
import 'package:tiketi_mkononi/screens/verify_code_page.dart';
import 'package:tiketi_mkononi/services/storage_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';


class EventDetailsPage extends StatefulWidget {
  final Event event;
  final int userId;
  final String role;
  final bool useDNS;
  final Function refreshMethod;

  const EventDetailsPage({
    super.key,
    required this.event,
    required this.userId,
    required this.role,
    required this.useDNS,
    required this.refreshMethod,
  });

  @override
  State<EventDetailsPage> createState() => _EventDetailsPageState(); 
}

class _EventDetailsPageState extends State<EventDetailsPage> {
  int userId = 0;
  String role = '';
  Event? event2;
  double? _imageHeight;
  double? _imageWidth;
  final double _defaultExpandedHeight = 360;
  String organiser_name = "";
  String organiser_phone_number = "";
  int eventTicketsCount = 0;
  Map<String, dynamic> ticketTypesTicketsCount = {};
  late final StorageService _storageService;
  bool isDeepLink = false;

  @override
  void initState() {
    super.initState();
    if(widget.userId > 0) {
      userId = widget.userId;
      role = widget.role;
    }else {
      _initializeServices();
    }

    _savePrefs();
    
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

  Future<void> _initializeServices() async {
    final prefs = await SharedPreferences.getInstance();
    _storageService = StorageService(prefs);
    _loadUserProfile();
  }

  void _loadUserProfile() {
    final profile = _storageService.getUserProfile();
    if (profile != null) {
      setState(() {
        userId = profile.id;
      });
    }
  }

  Future<void> _savePrefs() async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble('qrOffsetDx', (widget.event.qrOffsetDx).toDouble());
    await p.setDouble('qrOffsetDy', (widget.event.qrOffsetDy).toDouble());
    await p.setDouble('textOffsetDx', (widget.event.textOffsetDx).toDouble());
    await p.setDouble('textOffsetDy', (widget.event.textOffsetDy).toDouble());
    await p.setDouble('qrSize', (widget.event.qrSize).toDouble());
  }

  Future<void> getTicketsCount({bool useDNS = true}) async {

    final Uri uri = useDNS ? Uri.parse('${backend_url}api/event_tickets_count/${widget.event.id}') // Original URL 
    : Uri.parse('${backend_url_with_fallback_ip}event_tickets_count/${widget.event.id}'); // Use IP

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
    } on SocketException catch (e) {
      debugPrint('Network error occurred:');
      debugPrint('- Exception type: ${e.runtimeType}');
      debugPrint('- Message: ${e.message}');
      
      if (e.osError != null) {
        debugPrint('  - Error number (errno): ${e.osError!.errorCode}');
        debugPrint('  - OS message: ${e.osError!.message}');
        debugPrint('  - errorCode: ${e.osError!.errorCode}');
        debugPrint('  - useDNS: ${useDNS}');

        // Retry with IP if DNS fails (errno = 7) and not already retrying
        if ((e.osError!.errorCode == 11001 || e.osError!.errorCode == 7) && useDNS) {
          debugPrint('DNS failed! Retrying with IP: ${backend_url_with_fallback_ip}...');
          await getTicketsCount(useDNS: false); // Recursive retry

          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('use_dns', false);

          return;
        }
      }

      _handleSocketException(e);
    } catch (e) {
      debugPrint('Error getting tickets count: $e');
    }
  }

  void _handleSocketException(SocketException e) {
    if (e.osError?.errorCode == 7 || e.osError?.errorCode == 101 || e.osError?.errorCode == 111) {
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
    } else {
      _showSnackBar('Connection Error: ${e.message}');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  int getTicketTypesTicketsCount (Map<String, dynamic> ticketTypesTicketsCount, String name) {

    if (ticketTypesTicketsCount.isNotEmpty) {
      return ticketTypesTicketsCount[name];
    }
    return 0;
  }

  void fetchEvent({bool useDNS = true}) async {
    if (!mounted) return;
    widget.refreshMethod();

    try {
      final Uri uri = widget.useDNS ? Uri.parse('${backend_url}api/get_event/${widget.event.id}/${userId}') // Original URL 
      : Uri.parse('${backend_url_with_fallback_ip}get_event/${widget.event.id}/${userId}'); // Use IP
        
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
    } on SocketException catch (e) {
      debugPrint('Network error occurred:');
      debugPrint('- Exception type: ${e.runtimeType}');
      debugPrint('- Message: ${e.message}');
      
      if (e.osError != null) {
        debugPrint('  - Error number (errno): ${e.osError!.errorCode}');
        debugPrint('  - OS message: ${e.osError!.message}');
        debugPrint('  - errorCode: ${e.osError!.errorCode}');
        debugPrint('  - useDNS: ${useDNS}');

        // Retry with IP if DNS fails (errno = 7) and not already retrying
        if ((e.osError!.errorCode == 11001 || e.osError!.errorCode == 7) && useDNS) {
          debugPrint('DNS failed! Retrying with IP: ${backend_url_with_fallback_ip}...');
          fetchEvent(useDNS: false); // Recursive retry

          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('use_dns', false);
          return;
        }
      }

      _handleSocketException(e);
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
        widget.useDNS ? '${backend_url}api/image/${widget.event.imageUrl}' : '${backend_url_with_fallback_ip}image/${widget.event.imageUrl}'
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

  void _handleQRCodeScannerUnavailablility (Event event) {
     showDialog(
      context: context,
      builder: (context) => AlertDialog( 
        title: const Text('QR Code Scanning Unavailable'),
        content: const Text('This feature is only supported in the Tiketi Mkononi mobile app. Please download and open the application on your smartphone to scan QR codes'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VerifyCodePage(userId: userId, eventId: event.id),
                ),
              );
            },
            child: const Text('Proceed', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
  }


  Future<void> _sendPromoMessages({bool useDNS = true}) async {
    final Uri uri = useDNS 
        ? Uri.parse('${backend_url}api/send_promo_messages/$userId/${widget.event.id}') // Original URL with userId and eventId
        : Uri.parse('${backend_url_with_fallback_ip}send_promo_messages/$userId/${widget.event.id}'); // Use IP

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        debugPrint('response.body: ${response.body}');

        final responseData = jsonDecode(response.body);
        debugPrint('response.body: ${response.body}');
        
        // Display the response data in a dialog
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    (responseData['number_of_sms_sent'] > 0) ? Icons.check_circle : Icons.warning,
                    color: (responseData['number_of_sms_sent'] > 0) ? Colors.green : Colors.red
                  ),
                  SizedBox(width: 12),
                  Text( 
                    ((responseData['number_of_sms_sent'] ?? 0) > 0) ? 'Promo Messages Sent' : 'Promo Messages Not Sent',
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.black,
                      fontWeight: FontWeight.bold
                    ),
                  ),

                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(
                    icon: Icons.confirmation_number,
                    label: 'Tickets Count',
                    value: responseData['tickets_count']?.toString() ?? 'N/A',
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    icon: Icons.message,
                    label: 'SMS Sent',
                    value: responseData['number_of_sms_sent']?.toString() ?? 'N/A',
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline, 
                          size: 16, 
                          color: (responseData['number_of_sms_sent'] > 0) ? Colors.green : Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            responseData['description'] ?? 'N/A',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
        
      } else {
        // Handle non-200 responses
        _showErrorDialog('Failed to send promo messages. Status code: ${response.statusCode}');
      }
    } on SocketException catch (e) {
      debugPrint('Network error occurred:');
      debugPrint('- Exception type: ${e.runtimeType}');
      debugPrint('- Message: ${e.message}');
      
      if (e.osError != null) {
        debugPrint('  - Error number (errno): ${e.osError!.errorCode}');
        debugPrint('  - OS message: ${e.osError!.message}');
        debugPrint('  - errorCode: ${e.osError!.errorCode}');
        debugPrint('  - useDNS: $useDNS');

        // Retry with IP if DNS fails (errno = 7 or 11001) and not already retrying
        if ((e.osError!.errorCode == 11001 || e.osError!.errorCode == 7) && useDNS) {
          debugPrint('DNS failed! Retrying with IP: ${backend_url_with_fallback_ip}...');
          await _sendPromoMessages(useDNS: false); // Recursive retry

          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('use_dns', false);
          return;
        }
      }

      _handleSocketException(e);
    } catch (e) {
      debugPrint('Error sending promo messages: $e');
      _showErrorDialog('An error occurred while sending promo messages: $e');
    }
  }

  // Helper method to build info rows in the dialog
  Widget _buildInfoRow({required IconData icon, required String label, required String value}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade700),
        const SizedBox(width: 12),
        Text(
          '$label:',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // Helper method to show error dialog
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 12),
              Text('Error'),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // Optional: Create a method that shows confirmation before sending
  Future<void> _confirmAndSendPromoMessages() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.campaign, color: Colors.orange),
              SizedBox(width: 12),
              Text(
                'Send Promo Messages?',
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.black,
                  fontWeight: FontWeight.bold
                ),
              ),
            ],
          ),
          content: const Text(
            'Are you sure you want to send promo messages to this events\' attendees?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.send),
              label: const Text('Send'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _sendPromoMessages();
    }
  }

  Widget _buildCategoryChip(String category) {
    final categoryStyle = _getCategoryStyle(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: categoryStyle.color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        category.toUpperCase(),
        style: const TextStyle(
          fontSize: 9,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  _CategoryStyle _getCategoryStyle(String category) {
    switch (category.toUpperCase()) {
      case "CONCERTS":
        return _CategoryStyle(Colors.orange[800]!);
      case "SPORTS":
        return _CategoryStyle(Colors.red);
      case "COMEDY":
        return _CategoryStyle(Colors.brown[600]!);
      case "FUN":
        return _CategoryStyle(Colors.amber[500]!);
      case "BARS & GRILLS":
        return _CategoryStyle(Colors.pink);
      case "TRAINING":
        return _CategoryStyle(Colors.green);
      case "THEATER":
        return _CategoryStyle(Colors.black);
      case "WEDDING":
        return _CategoryStyle(Colors.red);
      case "CELEBRATION":
        return _CategoryStyle(Colors.yellow);
      default:
        return _CategoryStyle(Colors.grey);
    }
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
            Text(
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


                              if ((event.daily_event == 'no') && (event.status == "active") && (ticketType.numberOfTickets - (getTicketTypesTicketsCount(ticketTypesTicketsCount, ticketType.name)) <= 0))
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.middle,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFD700),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Sold Out (${NumberFormat('#,##0').format(getTicketTypesTicketsCount(ticketTypesTicketsCount, ticketType.name))})',  
                                      style: TextStyle(
                                        fontSize: 8,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),

                              if ((event.daily_event == 'yes') || ((event.daily_event == 'no') && (event.status == "active") && !(ticketType.numberOfTickets - (getTicketTypesTicketsCount(ticketTypesTicketsCount, ticketType.name)) <= 0)))
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
                                      'Tickets: ${NumberFormat('#,##0').format(getTicketTypesTicketsCount(ticketTypesTicketsCount, ticketType.name))}/${NumberFormat('#,##0').format(ticketType.numberOfTickets)}',
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
                              : Colors.orange[800],
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

  void goToCheckoutPage(Event event) {
    if(event.category.toUpperCase() == "THEATER") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TheaterCheckoutPage(
            event: event,
            theaterName: organiser_name,
            refreshMethod: fetchEvent,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CheckoutPage(
            event: event,
            refreshMethod: fetchEvent,
          ),
        ),
      );
    }
  }

  void goToConfirmPage(Event event) {
    if(event.category.toUpperCase() == "THEATER") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TheaterConfirmPage(
            event: event,
            theaterName: 'Confirm',
            refreshMethod: fetchEvent,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ConfirmPage(
            event: event,
            refreshMethod: fetchEvent,
          ),
        ),
      );
    }
  }

  Widget _buildActionButtons(Event event, BuildContext context) {
    if (userId != event.userId) {
      return Column(
        children: [
          if (event.type == 'paid' && event.status == "active")
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if(!(userId > 0)) {
                  debugPrint("userId : $userId");
                  _loadUserProfile();
                  debugPrint("userId 2 : $userId");
                  if(!(userId > 0)) {
                    final container = ProviderScope.containerOf(context);
                    container.read(selectedEventProvider.notifier).state = event;

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LoginScreen(),
                      ),
                    );
                  } else {
                    goToCheckoutPage(event);
                  }
                }else { 
                  goToCheckoutPage(event);
                }
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
              () async {
                if(!(userId > 0)) {
                  debugPrint("userId : $userId");
                  _loadUserProfile();
                  debugPrint("userId 2 : $userId");
                  if(!(userId > 0)) {
                    final container = ProviderScope.containerOf(context);
                    container.read(selectedEventProvider.notifier).state = event;

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LoginScreen(),
                      ),
                    );
                  } else {
                    goToConfirmPage(event);
                  }
                }else {
                  goToConfirmPage(event);
                }
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
          const SizedBox(height: 20),

          if(!(userId > 0) && kIsWeb && isDeepLink)
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
                  userId: userId,
                  ticketTypesTicketsCount: ticketTypesTicketsCount,
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
                    imageUrl: widget.useDNS ? '${backend_url}api/image/${event.imageUrl}' : '${backend_url_with_fallback_ip}image/${event.imageUrl}',
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
                                      ((widget.event.category.toUpperCase() == "WEDDING") || (widget.event.category.toUpperCase() == "CELEBRATION")) ? "View Cards" : "View Tickets",
                                      style: TextStyle(
                                        fontSize: 11, 
                                        color: Colors.green
                                      ),
                                    ) : 
                                    Text(
                                      ((widget.event.category.toUpperCase() == "WEDDING") || (widget.event.category.toUpperCase() == "CELEBRATION")) ? "View Card" : "View Ticket",
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
                                if((userId == event.userId) && (event.status == "active"))
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: TextButton(
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: () {
                                      if(event.category.toUpperCase() == "THEATER") {
                                        if(event.type == 'paid') { 
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => TheaterCheckoutPage(
                                                event: event,
                                                theaterName: organiser_name,
                                                refreshMethod: fetchEvent,
                                              ),
                                            ),
                                          );
                                        } else {
                                          goToConfirmPage(event);
                                        }
                                      } else {
                                        if(event.type == 'paid') {
                                          goToCheckoutPage(event);
                                        } else {
                                          goToConfirmPage(event);
                                        }
                                      }
                                    },
                                    child: const Icon(
                                      Icons.sell,
                                      size: 18,
                                      color: Colors.red
                                    ),
                                  ),
                                ),
                                if (userId == event.userId)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: TextButton(
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: (userId == event.userId)
                                      ? () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => SetScannerPage(userId: userId, eventId: event.id),
                                            ),
                                          );
                                        }
                                      : null,
                                    child: const Icon(
                                      Icons.assignment_ind,
                                      size: 18,
                                      color: Colors.green
                                    ),
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
                                if ((userId == event.userId) || ((userId != 0) && (userId == event.ticketScannerId)))
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: TextButton(
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: () {
                                      (kIsWeb) ? 
                                      _handleQRCodeScannerUnavailablility(event)
                                      :
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => QRScannerPage(userId: userId, eventId: event.id),
                                        ),
                                      );
                                    },
                                    child: const Icon(
                                      Icons.qr_code_scanner,
                                      size: 18,
                                      color: Colors.green
                                    ),
                                  ),
                                ),
                                if ((userId == event.userId) && (event.status == "active") && ((event.category.toUpperCase() == "WEDDING") || (event.category.toUpperCase() == "CELEBRATION")))
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
                                          builder: (context) => GenerateCardsPage(event: event),
                                        ),
                                      );
                                    },
                                    child: const Icon(
                                      Icons.assignment,
                                      size: 18,
                                      color: Colors.pink
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
                                    onPressed: (userId == event.userId)
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
                                if ((userId == event.userId) && (event.status == "active") && (role == 'admin') && (event.category.toUpperCase() == "WEDDING"))
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
                                          builder: (context) => SendReminderMessagesPage(event: event),
                                        ),
                                      );
                                    },
                                    child: const Icon(
                                      Icons.notifications_active,
                                      size: 18,
                                      color: Colors.blue
                                    ),
                                  ),
                                ),
                                if ((userId == event.userId) && (event.status == "active")  && (role == 'admin') && (event.category.toUpperCase() == "WEDDING"))
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
                                          builder: (context) => SendPledgeRequestsPage(event: event),
                                        ),
                                      );
                                    },
                                    child: const Icon(
                                      Icons.volunteer_activism,
                                      size: 18,
                                      color: Colors.red
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
      ),
    );
  }

  final _compactBtnStyle = TextButton.styleFrom(
    padding: EdgeInsets.zero,
    minimumSize: Size.zero,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );


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
                  imageUrl: widget.useDNS ? '${backend_url}api/image/${event.imageUrl}' : '${backend_url_with_fallback_ip}image/${event.imageUrl}',
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
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildCategoryChip(event.category),
                    
                        const SizedBox(width: 10),

                        // View Ticket / Card
                        if (event.hasTicket) ...[
                          TextButton(
                            style: _compactBtnStyle,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TicketsPage(eventId: event.id),
                                ),
                              );
                            },
                            child: Text(
                              (event.tickets.length > 1)
                                  ? ((event.category.toUpperCase() == "WEDDING" || event.category.toUpperCase() == "CELEBRATION")
                                      ? "View Cards"
                                      : "View Tickets")
                                  : ((event.category.toUpperCase() == "WEDDING" || event.category.toUpperCase() == "CELEBRATION")
                                      ? "View Card"
                                      : "View Ticket"),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.green,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],

                        // Sell button
                        if ((userId == event.userId) && (event.status == "active")) ...[
                          TextButton(
                            style: _compactBtnStyle,
                            onPressed: () {
                              if (event.type == 'paid') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => TheaterCheckoutPage(
                                      event: event,
                                      theaterName: organiser_name,
                                      refreshMethod: fetchEvent,
                                    ),
                                  ),
                                );
                              } else {
                                goToConfirmPage(event);
                              }
                            },
                            child: const Icon(
                              Icons.sell,
                              size: 18,
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],

                        // Assign scanner
                        if (userId == event.userId) ...[
                          TextButton(
                            style: _compactBtnStyle,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      SetScannerPage(userId: userId, eventId: event.id),
                                ),
                              );
                            },
                            child: const Icon(
                              Icons.assignment_ind,
                              size: 18,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],

                        // Share
                        TextButton(
                          style: _compactBtnStyle,
                          onPressed: () async {
                            final link =
                                "https://tiketimkononi.telabs.co.tz/event/${event.id}";

                            if (kIsWeb) {
                              await Clipboard.setData(
                                ClipboardData(text: "Check out this event! 🎟️\n$link"),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Link copied to clipboard!')),
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
                        const SizedBox(width: 10),

                        // QR Scanner
                        if ((userId == event.userId) || ((userId != 0) && (userId == event.ticketScannerId))) ...[
                          TextButton(
                            style: _compactBtnStyle,
                            onPressed: () {
                              kIsWeb
                                  ? _handleQRCodeScannerUnavailablility(event)
                                  : Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            QRScannerPage(userId: userId, eventId: event.id),
                                      ),
                                    );
                            },
                            child: const Icon(
                              Icons.qr_code_scanner,
                              size: 18,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        // Generate cards (wedding)
                        if ((userId == event.userId) && (event.status == "active") && ((event.category.toUpperCase() == "WEDDING") || (event.category.toUpperCase() == "CELEBRATION"))) ...[
                          TextButton(
                            style: _compactBtnStyle,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => GenerateCardsPage(event: event),
                                ),
                              );
                            },
                            child: const Icon(
                              Icons.assignment,
                              size: 18,
                              color: Colors.pink,
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],

                        // Ticket count
                        TextButton(
                          style: _compactBtnStyle,
                          onPressed: (userId == event.userId)
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EventTicketsPage(event: event),
                                ),
                              );
                            }
                          : null,
                          child: Text(
                            event.type == 'free'
                                ? '🎟️ $eventTicketsCount Confirmed'
                                : '🎟️ $eventTicketsCount Sold',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.orange[800],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        // Admin reminder
                        if ((userId == event.userId) && (event.status == "active") && (role == 'admin') && (event.category.toUpperCase() == "WEDDING")) ...[
                          const SizedBox(width: 10),
                          TextButton(
                            style: _compactBtnStyle,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SendReminderMessagesPage(event: event),
                                ),
                              );
                            },
                            child: const Icon(
                              Icons.notifications_active,
                              size: 18,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 10),
                          TextButton(
                            style: _compactBtnStyle,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SendPledgeRequestsPage(event: event),
                                ),
                              );
                            },
                            child: const Icon(
                              Icons.volunteer_activism,
                              size: 18,
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(width: 10),
                          TextButton(
                            style: _compactBtnStyle,
                            onPressed: () {
                              _confirmAndSendPromoMessages();
                            },
                            child: const Icon(
                              Icons.campaign,
                              size: 18,
                              color:Colors.orange,
                            ),
                          ),
                        ],
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

class _CategoryStyle {
  final Color color;

  _CategoryStyle(this.color);
}