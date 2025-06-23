import 'dart:convert';
import 'package:flutter/material.dart';
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
      return const Scaffold(body: Center(child: Text('Event not found')));
    }

    return EventDetailsPage(
      event: event!,
      userId: 0, // Replace with actual user ID
      refreshMethod: () {},
      useDNS: true, // or true depending on your logic
    );
  }
}
