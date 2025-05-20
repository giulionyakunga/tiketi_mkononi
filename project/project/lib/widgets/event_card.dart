import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/models/event.dart';
import 'package:tiketi_mkononi/screens/event_details_page.dart';
import 'package:tiketi_mkononi/screens/checkout_page.dart';
import 'package:cached_network_image/cached_network_image.dart';

class EventCard extends StatelessWidget {
  final Event event;
  final int userId;
  final Function refreshMethod;

  const EventCard({super.key, required this.event, required this.userId, required this.refreshMethod});

  String _formatDate(String date) {
    final DateFormat inputFormat = DateFormat('dd-MM-yyyy');
    final DateTime dateTime = inputFormat.parse(date);
    final DateFormat outputFormat = DateFormat('EEEE, MMMM d, yyyy');
    return outputFormat.format(dateTime);
  }

  bool checkSoldOut() {
    return !event.ticketTypes.any((ticketType) =>
      (ticketType.numberOfTickets - ticketType.soldTickets) > 0);
  }

  @override
  Widget build(BuildContext context) {

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4, // Add elevation for a modern look
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12), // Rounded corners
      ),
      clipBehavior: Clip.antiAlias,
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
              tag: 'event-image-${event.id}',
              child: CachedNetworkImage(
                imageUrl: '${backend_url}api/image/${event.imageUrl}',
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(),
                ),
                errorWidget: (context, url, error) => const Icon(Icons.error),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          event.name,
                          style: const TextStyle(
                            fontSize: 18, // Increased font size
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),


                  Row(
                    children: [

                      if (event.category.toUpperCase() == "CONCERTS")
                      Chip(
                        labelPadding: const EdgeInsets.symmetric(horizontal: 4), // ← Reduces side padding
                        padding: const EdgeInsets.all(0), // ← Reduces overall chip padding
                        label: Text(
                          event.category.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10, // Smaller text
                            color: Colors.white,
                          ),
                        ),
                        backgroundColor: Colors.blue,
                        labelStyle: const TextStyle(color: Colors.white),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, // ← Makes chip tighter
                      ),

                      if (event.category.toUpperCase() == "SPORTS")
                      Chip(
                        labelPadding: const EdgeInsets.symmetric(horizontal: 4), // ← Reduces side padding
                        padding: const EdgeInsets.all(0), // ← Reduces overall chip padding
                        label: Text(
                          event.category.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10, // Smaller text
                            color: Colors.white,
                          ),
                        ),
                        backgroundColor: Colors.red,
                        labelStyle: const TextStyle(color: Colors.white),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, // ← Makes chip tighter
                      ),

                      if (event.category.toUpperCase() == "COMEDY")
                      Chip(
                        labelPadding: const EdgeInsets.symmetric(horizontal: 4), // ← Reduces side padding
                        padding: const EdgeInsets.all(0), // ← Reduces overall chip padding
                        label: Text(
                          event.category.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10, // Smaller text
                            color: Colors.white,
                          ),
                        ),
                        backgroundColor: Colors.brown[600]!,
                        labelStyle: const TextStyle(color: Colors.white),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, // ← Makes chip tighter
                      ),

                      if (event.category.toUpperCase() == "FUN")
                      Chip(
                        labelPadding: const EdgeInsets.symmetric(horizontal: 4), // ← Reduces side padding
                        padding: const EdgeInsets.all(0), // ← Reduces overall chip padding
                        label: Text(
                          event.category.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10, // Smaller text
                            color: Colors.white,
                          ),
                        ),
                        backgroundColor: Colors.amber[500]!,
                        labelStyle: const TextStyle(color: Colors.white),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, // ← Makes chip tighter
                      ),

                      if (event.category.toUpperCase() == "BARS & GRILLS")
                      Chip(
                        labelPadding: const EdgeInsets.symmetric(horizontal: 4), // ← Reduces side padding
                        padding: const EdgeInsets.all(0), // ← Reduces overall chip padding
                        label: Text(
                          event.category.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10, // Smaller text
                            color: Colors.white,
                          ),
                        ),
                        backgroundColor: Colors.pink,
                        labelStyle: const TextStyle(color: Colors.white),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, // ← Makes chip tighter
                      ),

                      if (event.category.toUpperCase() == "TRAINING")
                      Chip(
                        labelPadding: const EdgeInsets.symmetric(horizontal: 4), // ← Reduces side padding
                        padding: const EdgeInsets.all(0), // ← Reduces overall chip padding
                        label: Text(
                          event.category.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10, // Smaller text
                            color: Colors.white,
                          ),
                        ),
                        backgroundColor: Colors.green,
                        labelStyle: const TextStyle(color: Colors.white),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, // ← Makes chip tighter
                      ),

                      if (event.category.toUpperCase() == "THEATER")
                      Chip(
                        labelPadding: const EdgeInsets.symmetric(horizontal: 4), // ← Reduces side padding
                        padding: const EdgeInsets.all(0), // ← Reduces overall chip padding
                        label: Text(
                          event.category.toUpperCase(),
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
                      Row(
                        children: [
                          Text(
                            '🎟️ ${event.soldTickets} Sold',
                            style: const TextStyle(fontSize: 12, color: Colors.blue),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),



                  Text('📅 ${_formatDate(event.date)}'),
                  Text('⏰ ${event.time}'),
                  Text(
                    '📍 ${event.venue}',
                  ),
                  const SizedBox(height: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: event.ticketTypes.map((ticketType) =>
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: 
                        Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: RichText(
                                    text: TextSpan(
                                      children: [
                                        TextSpan(
                                          text: '${ticketType.name}: ',
                                          style: const TextStyle(fontSize: 18, color: Colors.black),
                                        ),
                                        TextSpan(
                                          text: '${ticketType.price.toInt()} ',
                                          style: TextStyle(
                                            fontSize: 18, 
                                            fontWeight: FontWeight.bold,                               
                                            color: (ticketType.numberOfTickets - ticketType.soldTickets) <= 0 ? Colors.grey : Colors.orange,
                                          )
                                        ),

                                        if (event.status == "active" &&
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
                                        if (event.status == "active" &&
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
                              ],
                            ),

                        // Row(
                        //   children: [
                        //     Text(
                        //       '${ticketType.name} : ',
                        //       style: const TextStyle(
                        //         fontSize: 14,
                        //         color: Colors.black87,
                        //       ),
                        //     ),
                        //     Text(
                        //       'TSH ${ticketType.price.toInt()}',
                        //       style: const TextStyle(
                        //         fontSize: 14,
                        //         fontWeight: FontWeight.bold,
                        //         color: Colors.orange, // Highlight price
                        //       ),
                        //     ),

                        //     if ((ticketType.numberOfTickets - ticketType.soldTickets) <= 0)
                        //       Padding(
                        //         padding: const EdgeInsets.only(left: 8.0),
                        //         child: Container(
                        //           padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        //           decoration: BoxDecoration(
                        //             color: Colors.red,
                        //             borderRadius: BorderRadius.circular(8),
                        //           ),
                        //           child: Text(
                        //             'Sold Out (${ticketType.soldTickets})',
                        //             style: const TextStyle(
                        //               fontSize: 10,
                        //               color: Colors.white,
                        //               fontWeight: FontWeight.bold,
                        //             ),
                        //           ),
                        //         ),
                        //       ),

                        //     if ( !((ticketType.numberOfTickets - ticketType.soldTickets) <= 0) )
                        //       Padding(
                        //         padding: const EdgeInsets.only(left: 15.0),
                        //         child: Container(
                        //           padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        //           decoration: BoxDecoration(
                        //             color: Colors.blue,
                        //             borderRadius: BorderRadius.circular(8),
                        //           ),
                        //           child: Text(
                        //             '${ticketType.soldTickets}/${ticketType.numberOfTickets}',
                        //             style: const TextStyle(
                        //               fontSize: 10,
                        //               color: Colors.white,
                        //               fontWeight: FontWeight.bold,
                        //             ),
                        //           ),
                        //         ),
                        //       ),

                              


                        //   ],
                        // ),
                      ),
                    ).toList(),
                  ),
                  const SizedBox(height: 16),
                  event.has_ticket
                      ? SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: null,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              disabledBackgroundColor: Colors.blue, // Success color
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Booked',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        )
                      : ((event.status == "past") || (event.status == "closed")) ? 
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: null,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              disabledBackgroundColor: Colors.blue, // Success color
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              (event.status == "past") ? 'Past' : "Closed",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ) :
                        SizedBox(
                          width: double.infinity,
                          child: (event.userId == userId) ? null :
                          ElevatedButton(
                            onPressed: checkSoldOut() ? null : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CheckoutPage(event: event, refreshMethod: refreshMethod,),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: checkSoldOut() ? Colors.blue : Theme.of(context).primaryColor,
                              disabledBackgroundColor: checkSoldOut() ? Colors.blue : Theme.of(context).primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: checkSoldOut() ? const Text(
                              'Sold Out',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ) : 
                             const Text(
                              'Buy Tickets',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}