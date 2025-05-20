import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/models/event.dart';
import 'package:tiketi_mkononi/screens/event_details_page.dart';

class FeaturedEvents extends StatelessWidget {
  final List<Event> events;
  final int userId;
  final Function refreshMethod;

  const FeaturedEvents({super.key, required this.events, required this.userId, required this.refreshMethod});

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

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 265,
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
                  width: 280,
                  margin: const EdgeInsets.only(right: 16),
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EventDetailsPage(event: event, userId: userId, refreshMethod: refreshMethod,),
                          ),
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Hero(
                            tag: 'featured-${event.id}',
                            child: Container(
                              height: 160,
                              decoration: BoxDecoration(
                                image: DecorationImage(
                                  image: CachedNetworkImageProvider('${backend_url}api/image/${event.imageUrl}'),

                                  // image: NetworkImage('${backend_url}api/image/${event.imageUrl}'),
                                  // fit: BoxFit.cover,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.7),
                                    ],
                                  ),
                                ),
                                padding: const EdgeInsets.all(16),
                                alignment: Alignment.bottomLeft,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      event.name,
                                      overflow: TextOverflow.ellipsis, // Truncates with ellipsis
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'TSH${_getLowestPrice(event).toInt()}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.confirmation_number,
                                                size: 14,
                                                color: Colors.white,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                (event.type == 'paid') ? '${event.soldTickets} sold' : '${event.soldTickets} confirmed',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
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
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '📅 ${_formatDate(event.date)}',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  '⏰ ${event.time}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  '📍 ${event.venue}',
                                  overflow: TextOverflow.ellipsis, // Truncates with ellipsis
                                  style: const TextStyle(
                                    fontSize: 13,
                                  ),
                                ),

                                // Row(
                                //   children: [
                                //     const Icon(Icons.calendar_today, size: 16),
                                //     const SizedBox(width: 4),
                                //     Text(event.date),
                                //   ],
                                // ),
                                // const SizedBox(height: 4),
                                // Row(
                                //   children: [
                                //     const Icon(Icons.location_on, size: 16),
                                //     const SizedBox(width: 4),
                                //     Text(event.venue),
                                //   ],
                                // ),
                              ],
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