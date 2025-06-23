import 'package:flutter/material.dart';
import 'package:tiketi_mkononi/models/event.dart';
import 'package:intl/intl.dart';

class PurchaseHistoryEventCard extends StatelessWidget {
  final Event event;
  final int userId;
  final DateFormat dateFormat = DateFormat('EEE, MMM d, y');
  final DateFormat timeFormat = DateFormat('h:mm a');

  PurchaseHistoryEventCard({
    super.key,
    required this.event,
    required this.userId,
  });

  int getTotalPrice(Event event) {
    int totalPrice = 0;
    for (int i = 0; i < event.tickets.length; i++) {
      totalPrice += event.tickets[i]['price'] as int;
    }
    return totalPrice;
  }

  String _formatDate(String dateString) {
    try {
      // Try parsing ISO format first
      return dateFormat.format(DateTime.parse(dateString));
    } catch (e) {
      try {
        // Try parsing common date formats
        if (dateString.contains('-')) {
          // Handle dd-MM-yyyy format
          final parts = dateString.split('-');
          if (parts.length == 3) {
            final day = int.parse(parts[0]);
            final month = int.parse(parts[1]);
            final year = int.parse(parts[2]);
            return dateFormat.format(DateTime(year, month, day));
          }
        }
        // Fallback to showing raw date if parsing fails
        return dateString;
      } catch (e) {
        return dateString; // Return raw string if all parsing fails
      }
    }
  }

  String _formatTime(String timeString) {
    try {
      if (timeString.contains(':')) {
        // Parse HH:mm format
        final time = DateFormat('HH:mm').parse(timeString);
        return timeFormat.format(time);
      }
      return timeString;
    } catch (e) {
      return timeString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLargeScreen = MediaQuery.of(context).size.width > 768;
    final totalPrice = getTotalPrice(event);
    final formattedDate = _formatDate(event.date);
    final formattedTime = _formatTime(event.time);

    return Card(
      margin: EdgeInsets.symmetric(
        vertical: 8,
        horizontal: isLargeScreen ? 8 : 4,
      ),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // Add tap functionality if needed
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: _getCategoryColor(event.category),
                width: 6,
              ),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(isLargeScreen ? 20 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Event Name and Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        event.name,
                        style: TextStyle(
                          fontSize: isLargeScreen ? 20 : 18,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Purchased',
                        style: TextStyle(
                          fontSize: isLargeScreen ? 14 : 12,
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Date and Time - Now with error-proof formatting
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        fontSize: isLargeScreen ? 16 : 14,
                        color: colorScheme.onSurface.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formattedTime,
                      style: TextStyle(
                        fontSize: isLargeScreen ? 16 : 14,
                        color: colorScheme.onSurface.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Venue
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        event.venue,
                        style: TextStyle(
                          fontSize: isLargeScreen ? 16 : 14,
                          color: colorScheme.onSurface.withOpacity(0.8),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Details Grid
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: isLargeScreen ? 3 : 2,
                  childAspectRatio: isLargeScreen ? 3 : 2.5,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  children: [
                    _buildDetailItem(
                      context,
                      title: 'Category',
                      value: event.category,
                      icon: Icons.category,
                      color: _getCategoryColor(event.category),
                    ),
                    _buildDetailItem(
                      context,
                      title: 'Tickets',
                      value: '${event.tickets.length}',
                      icon: Icons.confirmation_number,
                      color: Colors.blue,
                    ),
                    _buildDetailItem(
                      context,
                      title: 'Total Price',
                      value: (totalPrice != 0)
                          ? 'Tsh ${NumberFormat('#,##0').format(totalPrice)}'
                          : 'Free',
                      icon: Icons.payments,
                      color: Colors.green,
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

  Widget _buildDetailItem(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final isLargeScreen = MediaQuery.of(context).size.width > 768;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: isLargeScreen ? 20 : 18,
                color: color,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: isLargeScreen ? 14 : 12,
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: isLargeScreen ? 16 : 14,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'concerts':
        return Colors.blue.shade700;
      case 'sports':
        return Colors.red.shade700;
      case 'comedy':
        return Colors.brown.shade700;
      case 'fun':
        return Colors.amber.shade700;
      case 'bars & grills':
        return Colors.pink.shade600;
      case 'training':
        return Colors.green.shade700;
      case 'theater':
        return Colors.deepPurple.shade700;
      default:
        return Colors.grey.shade700;
    }
  }
}