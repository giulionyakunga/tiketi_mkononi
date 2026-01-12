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
    final DateFormat outputFormat = DateFormat('EEEE, MMMM d, yyyy');
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
              builder: (context) => EventDetailsPage(event: event, userId: userId, role: role, refreshMethod: refreshMethod, useDNS: useDNS),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: 'event-image-${event.id}',
              child: CachedNetworkImage(
                imageUrl: useDNS ? '${backend_url}api/image/${event.imageUrl}' : '${backend_url_with_fallback_ip}image/${event.imageUrl}',
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
                        backgroundColor: Colors.orange[800],
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

                      

                      const SizedBox(width: 4),



                      const Spacer(),

                      (event.hasTicket) ?
                      (event.tickets.length == 1) ?
                      Text(
                        (event.type == 'paid') ? "Bought ${event.tickets.length} Ticket" : "Confirmed ${event.tickets.length} Ticket",
                        style: TextStyle(
                          fontSize: 11, 
                          color: Colors.green
                        ),
                      ) :
                      Text(
                        (event.type == 'paid') ? "Bought ${event.tickets.length} Tickets" : "Confirmed ${event.tickets.length} Tickets",
                        style: TextStyle(
                          fontSize: 11, 
                          color: Colors.green
                        ),
                      )
                      : Text("") ,
                        
                      const SizedBox(width: 12),

                      Row( 
                        children: [
                          if (event.daily_event == 'no')
                          Text(
                            (event.type == 'paid') ? '🎟️ ${formatNumber(event.soldTickets)} Sold' : '🎟️ ${formatNumber(event.soldTickets)} Confirmed',
                            style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                          )
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  (event.daily_event == 'yes') ? Text('📅 Everyday') : Text('📅 ${_formatDate(event.date)}'),
                  (event.time.contains(":")) ? Text('⏰ ${event.time}') : Text('⏰ Everytime'),
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
                                          text: (event.type == 'paid') ? 'TSH${NumberFormat('#,##0').format(ticketType.price.toInt())} ' : 'Free ',
                                          style: TextStyle(
                                            fontSize: 18, 
                                            fontWeight: FontWeight.bold,                               
                                            color: ( (event.daily_event == 'no') && ((ticketType.numberOfTickets - ticketType.soldTickets) <= 0)) ? Colors.grey : Colors.orange,
                                          )
                                        ),

                                        if ((event.daily_event == 'no') && (event.status == "active") && ((ticketType.numberOfTickets - ticketType.soldTickets) <= 0))
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
                                        if ((event.daily_event == 'yes') || ((event.daily_event == 'no') && (event.status == "active") && !((ticketType.numberOfTickets - ticketType.soldTickets) <= 0)))
                                          WidgetSpan(
                                            alignment: PlaceholderAlignment.middle,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: Colors.orange[800],
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                (event.daily_event == 'yes') ? 'Tickets: ${NumberFormat('#,##0').format(ticketType.numberOfTickets)}' :
                                                'Tickets: ${NumberFormat('#,##0').format(ticketType.soldTickets)}/${NumberFormat('#,##0').format(ticketType.numberOfTickets)}',
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
                      ),
                    ).toList(),
                  ),
                  const SizedBox(height: 16),
                  event.hasTicket
                      ? SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: null,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              disabledBackgroundColor: Colors.orange[800], // Success color
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              (event.type == 'paid') ? 'Booked' : 'Confirmed',
                              style: const TextStyle(
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
                              disabledBackgroundColor: Colors.orange[800], // Success color
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
                              if(!(userId > 0)) {
                                final container = ProviderScope.containerOf(context);
                                container.read(selectedEventProvider.notifier).state = event;

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => LoginScreen(),
                                  ),
                                );
                              } else if(event.type == 'paid') {
                                if(event.category.toUpperCase() == "THEATER") {
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
                              }else {
                                if(event.category.toUpperCase() == "THEATER") {
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
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: checkSoldOut() ? Colors.orange[800] : Theme.of(context).primaryColor,
                              disabledBackgroundColor: checkSoldOut() ? Colors.orange[800] : Theme.of(context).primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: ((event.daily_event == 'no') && checkSoldOut()) ? Text(
                              (event.type == 'paid') ? 'Sold Out' : "Full",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ) : 
                            Text(
                              (event.type == 'paid') ? 'Buy Tickets' : "Confirm",
                              style: const TextStyle(
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