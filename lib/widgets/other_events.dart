import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/models/event.dart';
import 'package:tiketi_mkononi/screens/theater_checkout_page.dart';

class OtherEvents extends StatelessWidget {
  final List<Event> events;
  final int userId;
  final Function refreshMethod;
  final bool useDNS;

  const OtherEvents({super.key, required this.events, required this.userId, required this.refreshMethod, required this.useDNS});

  double _getLowestPrice(Event event) {
    return event.ticketTypes.isNotEmpty 
      ? event.ticketTypes.map((t) => t.price).reduce((a, b) => a < b ? a : b) 
      : 0.0; // Return 0.0 if no tickets exist
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

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: events.isEmpty
      ? const Center(
          child: Text('No events found'),
        )
      : ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: events.length,
          itemBuilder: (context, index) {
            final event = events[index];
            return Container(
              width: 150,
              margin: const EdgeInsets.only(right: 16),
              child: Card(
                elevation: 0,
                color: Colors.transparent,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TheaterCheckoutPage(
                          event: event,
                          theaterName: 'Checkout',
                          refreshMethod: refreshMethod,
                        ),
                      ),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white,
                        backgroundImage: CachedNetworkImageProvider(
                          '${backend_url}api/image/${event.imageUrl}',
                          // useDNS ? '${backend_url}api/image/${event.imageUrl}' : '${backend_url_with_fallback_ip}api/image/${event.imageUrl}',
                        ),
                      ),
                      Text(
                        event.name,
                        overflow: TextOverflow.ellipsis, // Truncates with ellipsis
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
    );
  }
}