import 'package:flutter/material.dart';
import 'package:tiketi_mkononi/models/ticket.dart';
import 'package:tiketi_mkononi/screens/ticket_qr_page.dart';

class TicketCard extends StatelessWidget {
  final Ticket ticket;
  final Function fetchTickets;
  final bool isPast;

  const TicketCard({
    super.key,
    required this.ticket,
    this.isPast = false, required this.fetchTickets,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          // Navigate to ticket details
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Event name takes available space but not less than needed
                  Expanded(
                    child: Text(
                      ticket.eventName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 5, // Truncate instead of expanding
                    ),
                  ),
                  const SizedBox(width: 8), // Add some spacing between the two widgets
                  // Ticket type now has a max width and wraps if needed
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120), // or any reasonable max
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPast ? Colors.grey : Colors.orange[800],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        ticket.ticketType,
                        style: const TextStyle(color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1, // Truncate instead of expanding
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16),
                  const SizedBox(width: 4),
                  Text(ticket.date),
                  const SizedBox(width: 16),
                  const Icon(Icons.access_time, size: 16),
                  const SizedBox(width: 4),
                  Text(ticket.time),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16),
                  const SizedBox(width: 4),
                  Text(ticket.venue),
                ],
              ),
              if (!isPast) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        // Show QR code
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TicketQRPage(
                              ticketId: ticket.id, // Replace with actual ticket ID
                              userId: ticket.userId,
                              userName: ticket.userName,
                              eventId: ticket.eventId,
                              eventName: ticket.eventName,
                              date: ticket.date,
                              time: ticket.time,
                              venue: ticket.venue,
                              ticketType: ticket.ticketType,
                              price: ticket.price,
                              scanStatus: ticket.scanStatus,
                              createdAt: ticket.createdAt,
                            ),
                          ),
                        );
                        fetchTickets();
                      },
                      icon: const Icon(Icons.qr_code),
                      label: const Text('Show Ticket'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}