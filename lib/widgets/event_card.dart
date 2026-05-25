import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/models/event.dart';
import 'package:tiketi_mkononi/screens/auth/login_screen.dart';
import 'package:tiketi_mkononi/screens/confirm_page.dart';
import 'package:tiketi_mkononi/screens/event_details_page.dart';
import 'package:tiketi_mkononi/screens/checkout_page.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:tiketi_mkononi/screens/event_providers.dart';
import 'package:tiketi_mkononi/screens/theater_checkout_page.dart';
import 'package:tiketi_mkononi/screens/theater_confirm_page.dart';

class EventCard extends StatelessWidget {
  final Event event;
  final int userId;
  final String role;
  final Function refreshMethod;
  final bool useDNS;

  const EventCard({super.key, required this.event, required this.userId, required this.role, required this.refreshMethod, required this.useDNS});

  String _formatDate(String date) {
    final DateFormat inputFormat = DateFormat('dd-MM-yyyy');
    final DateTime dateTime = inputFormat.parse(date);
    final DateFormat outputFormat = DateFormat('EEE, MMM d');
    return outputFormat.format(dateTime);
  }

  bool checkSoldOut() {
    return !event.ticketTypes.any((ticketType) =>
      (ticketType.numberOfTickets - ticketType.soldTickets) > 0);
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

  // Helper method to get card styling based on event status
  _EventCardStyle _getCardStyle(String status) {
    switch (status) {
      case 'active':
        return _EventCardStyle(
          backgroundColor: Colors.white,
          borderColor: Colors.green.withOpacity(0.3),
          accentColor: Colors.green,
          statusColor: Colors.green,
          statusText: 'Active',
          statusIcon: Icons.event_available,
          overlayColor: Colors.transparent,
        );
      case 'closed':
        return _EventCardStyle(
          backgroundColor: Colors.grey[50]!,
          borderColor: Colors.grey.withOpacity(0.4),
          accentColor: Colors.grey[700]!,
          statusColor: Colors.grey[600]!,
          statusText: 'Closed',
          statusIcon: Icons.event_busy,
          overlayColor: Colors.black.withOpacity(0.03),
        );
      case 'past':
        return _EventCardStyle(
          backgroundColor: Colors.blueGrey[50]!,
          borderColor: Colors.blueGrey.withOpacity(0.3),
          accentColor: Colors.blueGrey,
          statusColor: Colors.blueGrey[600]!,
          statusText: 'Past',
          statusIcon: Icons.history,
          overlayColor: Colors.black.withOpacity(0.05),
        );
      default:
        return _EventCardStyle(
          backgroundColor: Colors.white,
          borderColor: Colors.orange.withOpacity(0.3),
          accentColor: Colors.orange,
          statusColor: Colors.orange,
          statusText: 'Unknown',
          statusIcon: Icons.help_outline,
          overlayColor: Colors.transparent,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardStyle = _getCardStyle(event.status);
    final isSoldOut = checkSoldOut();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: event.status == 'active' ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: cardStyle.borderColor,
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Main content
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EventDetailsPage(event: event, userId: userId, role: role, refreshMethod: refreshMethod, useDNS: useDNS),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: cardStyle.backgroundColor,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image section with status overlay - height reduced
                  Stack(
                    children: [
                      Hero(
                        tag: 'event-image-${event.id}',
                        child: CachedNetworkImage(
                          imageUrl: useDNS ? '${backend_url}api/image/${event.imageUrl}' : '${backend_url_with_fallback_ip}image/${event.imageUrl}',
                          width: double.infinity,
                          height: 180, // Reduced from 180
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            height: 120,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  cardStyle.accentColor.withOpacity(0.1),
                                  cardStyle.accentColor.withOpacity(0.05),
                                ],
                              ),
                            ),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: cardStyle.accentColor,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            height: 120,
                            color: Colors.grey[200],
                            child: Icon(
                              Icons.event,
                              size: 40,
                              color: cardStyle.accentColor,
                            ),
                          ),
                        ),
                      ),
                      
                      // Status badge - made more compact
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: cardStyle.statusColor.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                cardStyle.statusIcon,
                                size: 12,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                cardStyle.statusText,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Sold out overlay for active events
                      if (event.status == 'active' && isSoldOut)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.95),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Text(
                              'SOLD OUT',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                  // Content section with reduced padding
                  Padding(
                    padding: const EdgeInsets.all(12), // Reduced from 20
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Event name and category - compact layout
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    event.name,
                                    style: TextStyle(
                                      fontSize: 16, // Reduced from 20
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[800],
                                      height: 1.2,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6), // Reduced from 8
                                  _buildCategoryChip(event.category),
                                ],
                              ),
                            ),
                            // Ticket count for user - made smaller
                            if (event.hasTicket)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.green.withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  '${event.tickets.length}',
                                  style: TextStyle(
                                    fontSize: 10, // Reduced from 12
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[700],
                                  ),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 8), // Reduced from 16

                        // Compact event details in a single row
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, size: 12, color: cardStyle.accentColor),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  event.daily_event == 'yes' ? 'Everyday' : _formatDate(event.date),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.access_time, size: 12, color: cardStyle.accentColor),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  event.time.contains(":") ? event.time : 'Anytime',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 8), // Reduced from 16

                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: event.ticketTypes.map((ticketType) =>

                            // Compact ticket info row
                            Row(
                              children: [
                                // Price

                                Text(
                                  '${ticketType.name}: ',
                                  style: TextStyle(
                                    fontSize: 14, // Reduced from 18
                                    fontWeight: FontWeight.bold,
                                    color: isSoldOut ? Colors.grey : Colors.black,
                                  ),
                                ),
                                
                                Text(
                                  (event.type == 'paid') ? 'TSH${NumberFormat('#,##0').format(ticketType.price.toInt())}' : 'Free',
                                  style: TextStyle(
                                    fontSize: 14, // Reduced from 18
                                    fontWeight: FontWeight.bold,
                                    color: isSoldOut ? Colors.grey : Colors.orange[800],
                                  ),
                                ),
                                
                                const Spacer(),
                                
                                // Tickets sold info - compact
                                if (event.daily_event == 'no')
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.confirmation_number, size: 10, color: Colors.orange[800]),
                                        const SizedBox(width: 2),
                                        Text(
                                          formatNumber(ticketType.soldTickets),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange[800],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ).toList(),
                        ),

                        const SizedBox(height: 8), // Reduced from 16

                        // Compact action button
                        _buildCompactActionButton(context, cardStyle, isSoldOut),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Overlay for non-active events
          if (event.status != 'active')
            IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  color: cardStyle.overlayColor,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
        ],
      ),
    );
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

  Widget _buildCompactActionButton(BuildContext context, _EventCardStyle cardStyle, bool isSoldOut) {
    if (event.hasTicket) {
      return _buildCompactButton(
        text: event.type == 'paid' ? 'Booked' : 'Confirmed',
        backgroundColor: Colors.green,
        isEnabled: false,
      );
    }

    if (event.status == "past" || event.status == "closed") {
      return _buildCompactButton(
        text: event.status == "past" ? 'Past' : 'Closed',
        backgroundColor: cardStyle.accentColor,
        isEnabled: false,
      );
    }

    if (event.userId == userId) {
      return const SizedBox();
    }

    final buttonText = isSoldOut
        ? (event.type == 'paid' ? 'Sold Out' : "Full")
        : (event.type == 'paid' ? 'Buy Tickets' : "Confirm");

    return _buildCompactButton(
      text: buttonText,
      backgroundColor: isSoldOut ? Colors.grey : Theme.of(context).primaryColor,
      isEnabled: !isSoldOut,
      onPressed: () => _handleBooking(context),
    );
  }

  Widget _buildCompactButton({
    required String text,
    required Color backgroundColor,
    required bool isEnabled,
    VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 32, // Reduced height
      child: ElevatedButton(
        onPressed: isEnabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          backgroundColor: backgroundColor,
          disabledBackgroundColor: backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 1,
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  void _handleBooking(BuildContext context) {
    if (!(userId > 0)) {
      final container = ProviderScope.containerOf(context);
      container.read(selectedEventProvider.notifier).state = event;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    } else if (event.type == 'paid') {
      if (event.category.toUpperCase() == "THEATER") {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TheaterCheckoutPage(
              event: event,
              theaterName: 'Checkout',
              refreshMethod: refreshMethod,
            ),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CheckoutPage(event: event, refreshMethod: refreshMethod,),
          ),
        );
      }
    } else {
      if (event.category.toUpperCase() == "THEATER") {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TheaterConfirmPage(
              event: event,
              theaterName: 'Confirm',
              refreshMethod: refreshMethod,
            ),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ConfirmPage(event: event, refreshMethod: refreshMethod,),
          ),
        );
      }
    }
  }
}

// Helper classes for styling
class _EventCardStyle {
  final Color backgroundColor;
  final Color borderColor;
  final Color accentColor;
  final Color statusColor;
  final String statusText;
  final IconData statusIcon;
  final Color overlayColor;

  _EventCardStyle({
    required this.backgroundColor,
    required this.borderColor,
    required this.accentColor,
    required this.statusColor,
    required this.statusText,
    required this.statusIcon,
    required this.overlayColor,
  });
}

class _CategoryStyle {
  final Color color;

  _CategoryStyle(this.color);
}