// widgets/bus_ticket_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tiketi_mkononi/models/bus_ticket.dart';
import 'package:tiketi_mkononi/models/bus_route.dart';

class BusTicketCard extends StatelessWidget {
  final BusTicket ticket;
  final BusRoute busRoute;
  final Function(BusTicket) printTickets;
  final bool isCancelled;

  const BusTicketCard({
    super.key,
    required this.ticket,
    required this.busRoute,
    required this.printTickets,
    required this.isCancelled,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          // Show ticket details dialog
          _showTicketDetailsDialog(context);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.directions_bus, color: Colors.orange[800]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ticket.passengerName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ), 
                  ),
                  if (isCancelled)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCancelled ? Colors.grey[300] : Colors.green[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Cancelled',
                      style: TextStyle(
                        fontSize: 12,
                        color: isCancelled ? Colors.grey[700] : Colors.green[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(),
              // Departure and arrival times
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Departure', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(
                          busRoute.departureTime,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          busRoute.departureDate,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Arrival', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(
                          busRoute.arrivalTime,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          busRoute.arrivalDate,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Pickup and dropoff
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Pickup', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(
                        ticket.pickupLocation,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Dropoff', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(
                        ticket.dropoffLocation,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Seats and price
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Seats', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(
                        ticket.seatNumber,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Total Price', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(
                        'TSh ${NumberFormat('#,##0').format(ticket.ticketPrice.toInt())}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[800],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Passenger Name', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(
                        ticket.passengerName,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Phone Number', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(
                        ticket.phoneNumber,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Payment
              const SizedBox(height: 12),
              // Payment method
              Row(
                children: [
                  const Icon(Icons.payment, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    ticket.paymentMethod,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              // Booking date
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Booked: ${DateFormat('MMM dd, yyyy').format(ticket.createdAt)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTicketDetailsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ticket Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Route', '${busRoute.from} → ${busRoute.to}'),
              const Divider(),
              _buildDetailRow('Bus', busRoute.bus?.name ?? 'Standard Bus'),
              _buildDetailRow('Departure Date', busRoute.departureDate),
              _buildDetailRow('Departure Time', busRoute.departureTime),
              _buildDetailRow('Arrival Date', busRoute.arrivalDate),
              _buildDetailRow('Arrival Time', busRoute.arrivalTime),
              const Divider(),
              _buildDetailRow('Seats', ticket.seatNumber),
              _buildDetailRow('Passenger Name', ticket.passengerName),
              _buildDetailRow('Phone Number', ticket.phoneNumber),
              _buildDetailRow('Total Price', 'TSh ${NumberFormat('#,##0').format(busRoute.ticketPrice.toInt())}'),
              _buildDetailRow('Payment Method', ticket.paymentMethod),
              _buildDetailRow('Booking Date', DateFormat('MMM dd, yyyy - HH:mm').format(ticket.createdAt)),
              _buildDetailRow('Status', ticket.status), 
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => printTickets(ticket),
            child: const Text('Print'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}