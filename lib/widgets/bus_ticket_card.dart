// widgets/bus_ticket_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tiketi_mkononi/models/bus_ticket.dart';
import 'package:tiketi_mkononi/models/bus_route.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';    // for PdfPageFormat
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:convert';

import 'package:tiketi_mkononi/services/SimpleCodec.dart';

class BusTicketCard extends StatelessWidget {
  final BusTicket ticket;
  final BusRoute busRoute;
  final String companyName;
  final Function(BusTicket, {bool isDuplicate}) printTickets;
  final bool isCancelled;

  const BusTicketCard({
    super.key,
    required this.ticket,
    required this.busRoute,
    required this.companyName,
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

  Future<void> _shareTicket(BusTicket ticket) async {
    final pdf = pw.Document();

    final themeColor = PdfColor.fromHex('#0F4C81'); // Deep blue
    final accentColor = PdfColor.fromHex('#F5A623'); // Amber accent
    final lightBg = PdfColor.fromHex('#F4F6F9');

    String formattedDate = DateFormat('EEE, d MMM y').format(ticket.createdAt);
    String formattedTime = DateFormat('hh:mm a').format(ticket.createdAt);

    final String data = SimpleCodec.encode(jsonEncode({
      "tid": ticket.id,
      "code": ticket.ticketCode,
      "uid": ticket.userId,
    }));

    pw.Widget dashedDivider({double dashWidth = 3, double space = 3, double thickness = 0.6}) {
      return pw.LayoutBuilder(
        builder: (context, constraints) {
          final count = (constraints!.maxWidth / (dashWidth + space)).floor();
          return pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: List.generate(
              count,
              (_) => pw.Container(
                width: dashWidth,
                height: thickness,
                color: PdfColors.grey400,
              ),
            ),
          );
        },
      );
    }

    pw.Widget sectionTitle(String text) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(top: 8, bottom: 4),
        child: pw.Row(
          children: [
            pw.Container(width: 3, height: 10, color: themeColor),
            pw.SizedBox(width: 5),
            pw.Text(
              text.toUpperCase(),
              style: pw.TextStyle(
                fontSize: 7.5,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 1.2,
                color: themeColor,
              ),
            ),
          ],
        ),
      );
    }

    pw.Widget infoRow(String label, String value, {bool bold = false}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 62,
              child: pw.Text(
                label,
                style: pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
              ),
            ),
            pw.Expanded(
              child: pw.Text(
                value,
                style: pw.TextStyle(
                  fontSize: 7.5,
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                  color: PdfColors.black,
                ),
              ),
            ),
          ],
        ),
      );
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(58 * PdfPageFormat.mm, double.infinity),
        margin: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // ── HEADER BAND ─────────────────────────────
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                decoration: pw.BoxDecoration(
                  color: themeColor,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      companyName.toUpperCase(),
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: pw.BoxDecoration(
                        color: accentColor,
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Text(
                        'BUS E-TICKET',
                        style: pw.TextStyle(
                          fontSize: 7,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 10),

              // ── ROUTE HERO ──────────────────────────────
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                decoration: pw.BoxDecoration(
                  color: lightBg,
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                ),
                child: pw.Column(
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('FROM',
                                  style: pw.TextStyle(
                                      fontSize: 6, color: PdfColors.grey600, letterSpacing: 0.8)),
                              pw.SizedBox(height: 1),
                              pw.Text(
                                ticket.pickupLocation,
                                style: pw.TextStyle(
                                    fontSize: 8, fontWeight: pw.FontWeight.bold),
                                maxLines: 2,
                              ),
                            ],
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                          child: pw.Text('->',
                              style: pw.TextStyle(
                                  fontSize: 11,
                                  color: themeColor,
                                  fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              pw.Text('TO',
                                  style: pw.TextStyle(
                                      fontSize: 6, color: PdfColors.grey600, letterSpacing: 0.8)),
                              pw.SizedBox(height: 1),
                              pw.Text(
                                ticket.dropoffLocation,
                                style: pw.TextStyle(
                                    fontSize: 8, fontWeight: pw.FontWeight.bold),
                                textAlign: pw.TextAlign.right,
                                maxLines: 2,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 6),
                    dashedDivider(),
                    pw.SizedBox(height: 6),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        _chip('DATE', ticket.departureDate, themeColor),
                        _chip('TIME', ticket.departureTime, themeColor),
                        _chip('SEAT', ticket.seatNumber, accentColor),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 8),

              // ── TICKET CODE ─────────────────────────────
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 6),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: themeColor, width: 0.8),
                  borderRadius: pw.BorderRadius.circular(3),
                ),
                child: pw.Column(
                  children: [
                    pw.Text('TICKET CODE',
                        style: pw.TextStyle(
                            fontSize: 6, color: PdfColors.grey600, letterSpacing: 1.2)),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      ticket.ticketCode,
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: themeColor,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 8),

              // ── PASSENGER ───────────────────────────────
              sectionTitle('Passenger'),
              infoRow('Name', ticket.passengerName, bold: true),
              infoRow('Phone', ticket.phoneNumber),
              infoRow('Payment', ticket.paymentMethod),
              infoRow(
                'Fare',
                'TZS ${NumberFormat('#,##0').format(ticket.ticketPrice.toInt())}',
                bold: true,
              ),
              infoRow('Status', ticket.status.toUpperCase(), bold: true),

              pw.SizedBox(height: 4),
              dashedDivider(),
              pw.SizedBox(height: 4),

              // ── ISSUED BY ───────────────────────────────
              sectionTitle('Issued By'),
              infoRow('Name', ticket.issuedBy),
              infoRow('Phone', ticket.issuerPhoneNumber),
              infoRow('Issued On', '$formattedDate · $formattedTime'),

              pw.SizedBox(height: 8),

              // ── QR ──────────────────────────────────────
              pw.Center(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: data,
                    width: 70,
                    height: 70,
                    color: PdfColors.black,
                  ),
                ),
              ),

              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  'Scan to verify ticket',
                  style: pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600),
                ),
              ),

              pw.SizedBox(height: 8),
              dashedDivider(),
              pw.SizedBox(height: 8),

              // ── FOOTER ──────────────────────────────────
              pw.Center(
                child: pw.Text(
                  'Thank you for choosing',
                  style: pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                ),
              ),
              pw.SizedBox(height: 1),
              pw.Center(
                child: pw.Text(
                  companyName,
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: themeColor,
                  ),
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text(
                  'Powered by Tiketi Mkononi',
                  style: pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600),
                ),
              ),
              pw.SizedBox(height: 1),
              pw.Center(
                child: pw.Text(
                  'tiketimkononi@telabs.co.tz',
                  style: pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600),
                ),
              ),
              pw.SizedBox(height: 10),
            ],
          );
        },
      ),
    );

    // Save PDF
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/ticket_${ticket.ticketCode}.pdf');
    await file.writeAsBytes(await pdf.save());

    // Share PDF
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Bus Ticket - ${ticket.ticketCode}',
    );
  }

  // ── Helper for the route chips ──────────────────
  pw.Widget _chip(String label, String value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: color, width: 0.6),
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Column(
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontSize: 5.5, color: PdfColors.grey700, letterSpacing: 0.8)),
          pw.SizedBox(height: 1),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: color)),
        ],
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
            onPressed: () => printTickets(ticket, isDuplicate: true),
            child: const Text('Print'),
          ),
          TextButton(
            onPressed: () => _shareTicket(ticket), 
            child: const Text('Share'),
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