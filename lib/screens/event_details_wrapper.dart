import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/models/event.dart';
import 'package:tiketi_mkononi/screens/event_details_page.dart';

class EventDetailsWrapper extends StatefulWidget {
  final int eventId;

  const EventDetailsWrapper({super.key, required this.eventId});

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

  Future<void> fetchEvent() async {
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

    return EventDetailsPage(
      event: event!,
      userId: 0,
      refreshMethod: () {},
      useDNS: true,
    );
  }
}
