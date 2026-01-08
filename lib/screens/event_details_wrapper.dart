import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/models/event.dart';
import 'package:tiketi_mkononi/screens/confirm_attendance_page.dart';
import 'package:tiketi_mkononi/screens/event_details_page.dart';

class EventDetailsWrapper extends StatefulWidget {
  final int eventId;
  final String? ticketCode;  // Make nullable

  const EventDetailsWrapper({super.key, required this.eventId, this.ticketCode});

  @override
  State<EventDetailsWrapper> createState() => _EventDetailsWrapperState();
}

class _EventDetailsWrapperState extends State<EventDetailsWrapper> {
  Event? event;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchEvent();
  }

  Future<void> fetchEvent({bool useDNS = true}) async {
    try {
      final url = Uri.parse('${backend_url}/api/get_event/${widget.eventId}/1');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() {
          event = Event.fromJson(json.decode(response.body));
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } on SocketException catch (e) {
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
          await fetchEvent(useDNS: false); // Recursive retry

          return;
        }
      }
    } catch (e) {
      debugPrint('Error fetching events: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (event == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Event not found'),
              ElevatedButton.icon(
                icon: const Icon(Icons.logout),
                label: Text('See Other Events', style: TextStyle(
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
              )
            ],
          ),
        )
      );
    }

    if(widget.ticketCode!.isNotEmpty){
      return ConfirmAttendancePage(
        event: event!,
        ticketCode: widget.ticketCode!,
      );
    }

    return EventDetailsPage(
      event: event!,
      userId: 0,
      refreshMethod: () {},
      useDNS: true,
    );
  }
}
