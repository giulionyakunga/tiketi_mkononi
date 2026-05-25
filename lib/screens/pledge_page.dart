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
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

class PledgePage extends StatefulWidget {
  final Event event;

  const PledgePage({
    super.key,
    required this.event,
  });

  @override
  State<PledgePage> createState() => _PledgePageState(); 
}

class _PledgePageState extends State<PledgePage> {
  Event? event2;
  double? _imageHeight;
  double? _imageWidth;
  final double _defaultExpandedHeight = 360;
  String organiser_name = "";
  String organiser_phone_number = "";
  int eventTicketsCount = 0;
  Map<String, dynamic> ticketTypesTicketsCount = {};
  bool isDeepLink = false;
  bool isPledged = false;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _amountController = TextEditingController();


  @override
  void initState() {
    super.initState();
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
    _nameController.dispose();
    _phoneNumberController.dispose();
    _amountController.dispose();

    super.dispose();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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

  void _scrollToFirstError() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Scrollable.ensureVisible(
        _formKey.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> pledge({bool useDNS = true}) async {
    if (!_formKey.currentState!.validate()) {
      _scrollToFirstError();
      return;
    }

    final requestBody = {
      'name': _nameController.text.trim(),
      'phone_number': _phoneNumberController.text.trim(),
      'amount': _amountController.text.trim(),
    };

    final Uri uri = useDNS ? Uri.parse('${backend_url}api/pledge/${widget.event.id}') // Original URL 
    : Uri.parse('${backend_url_with_fallback_ip}pledge/${widget.event.id}'); // Use IP

    try {

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        if (response.body == "Pledge created successfully!") {
          setState(() {
            isPledged = true;
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
        debugPrint('  - errorCode: ${e.osError!.errorCode}');
        debugPrint('  - useDNS: ${useDNS}');

        // Retry with IP if DNS fails (errno = 7) and not already retrying
        if ((e.osError!.errorCode == 11001 || e.osError!.errorCode == 7) && useDNS) {
          debugPrint('DNS failed! Retrying with IP: ${backend_url_with_fallback_ip}...');
          await pledge(useDNS: false); // Recursive retry

          return;
        }
      }

      _handleSocketException(e);
    } catch (e) {
      debugPrint('Error fetching check tickets scan status: $e');
    }
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
      : Uri.parse('${backend_url_with_fallback_ip}get_event/${widget.event.id}/0'); // Use IP
        
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
        debugPrint('  - errorCode: ${e.osError!.errorCode}');
        debugPrint('  - useDNS: ${useDNS}');

        // Retry with IP if DNS fails (errno = 7) and not already retrying
        if ((e.osError!.errorCode == 11001 || e.osError!.errorCode == 7) && useDNS) {
          debugPrint('DNS failed! Retrying with IP: ${backend_url_with_fallback_ip}...');
          fetchEvent(useDNS: false); // Recursive retry

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

  InputDecoration _buildInputDecoration(String label, {String? prefixText, IconData? prefixIcon}) {
    return InputDecoration(
      labelText: label,
      prefixText: prefixText,
      prefixIcon: (prefixIcon != null) ? Icon(
        prefixIcon,
        color: Colors.grey[600],
      ) : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[400]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[400]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.orange[800]!, width: 2),
      ),
      filled: true,
      fillColor: Colors.grey[200],
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
    );
  }

  Widget _buildPledgeForm(Event event, BuildContext context) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _nameController,
                    maxLength: 100,
                    decoration: _buildInputDecoration('Jina Kamili', prefixIcon: Icons.person),
                    style: const TextStyle(fontSize: 16),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Tafadhali jaza jina lako kamili';
                      if (value.length > 100) return 'Jina kamili lazima liwe herufi 100 au chini';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneNumberController,
                    maxLength: 15,
                    decoration: _buildInputDecoration('Nambari ya Simu', prefixIcon: Icons.phone),
                    style: const TextStyle(fontSize: 16),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Tafadhali jaza nambari yako ya simu';
                      if (value.length > 15) return 'Nambari ya simu lazima liwe herufi 15 au chini';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _amountController,
                    decoration: _buildInputDecoration('Kiasi unachoahidi (Pledge)', prefixText: 'TSH '),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 14),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Tafadhali ingiza Kiasi unachoahidi';
                      if (value.length > 10) return 'Kiasi unachoahidi lazima liwe herufi 10 au chini';
                      return null;
                    },
                  ),
                  ElevatedButton(
                    onPressed: 
                    () async {
                      await pledge();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: isPledged ? Colors.orange[800] : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      isPledged ? 'Ahadi yako imepokelewa' : 'Toa ahadi yako',
                      style: TextStyle(
                        fontSize: 16,
                        color: isPledged
                            ? Colors.white
                            : Colors.orange[800],
                      ),
                    ),
                  ),
                ]
              )
            )
          ),
          const SizedBox(height: 20),

          ElevatedButton.icon(
            icon: const Icon(Icons.logout),
            label: Text('Tazama Matukio Mengine', style: TextStyle(
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
                                      final link = "https://tiketimkononi.telabs.co.tz/pledge/$eventId";

                                      if (kIsWeb) {
                                        await Clipboard.setData(ClipboardData(text: "Mpendwa, karibu kuweka ahadi yako kwa ajili ya ${event.name} 🎟️\n$link"));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Link copied to clipboard!')),
                                        );
                                      } else {
                                        Share.share("Mpendwa, karibu kuweka ahadi yako kwa ajili ya ${event.name} 🎟️\n$link");
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
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          _buildPledgeForm(event, context),
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
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: TextButton(
                            onPressed: () async {
                              final eventId = event.id;
                              final link = "https://tiketimkononi.telabs.co.tz/pledge/$eventId";

                              if (kIsWeb) {
                                await Clipboard.setData(ClipboardData(text: "Mpendwa, karibu kuweka ahadi yako kwa ajili ya ${event.name} 🎟️\n$link"));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Link copied to clipboard!')),
                                );
                              } else {
                                Share.share("Mpendwa, karibu kuweka ahadi yako kwa ajili ya ${event.name} 🎟️\n$link");
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
                  _buildPledgeForm(event, context),
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