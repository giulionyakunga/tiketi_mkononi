import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:tiketi_mkononi/env.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;
import 'package:tiketi_mkononi/models/event.dart';

class TicketType2 {
  int id;
  String name;
  double price;
  int numberOfTickets;
  String ticketInformation;
  int soldTickets;
  bool isCustom;

  TicketType2({
    required this.id,
    required this.name,
    required this.price,
    required this.numberOfTickets,
    required this.ticketInformation,
    required this.soldTickets,
    required this.isCustom,
  });
}

class Venue {
  String name;
  int rows;
  int seats;

  Venue({
    required this.name,
    required this.rows,
    required this.seats,
  });
}

class EditEventPage extends StatefulWidget {
  final Event event;
  final int userId;
  final  Map<String, dynamic> ticketTypesTicketsCount;
  final Function refreshMethod;


  const EditEventPage({
    super.key,
    required this.event,
    required this.userId,
    required this.ticketTypesTicketsCount,
    required this.refreshMethod,
  });

  @override
  State<EditEventPage> createState() => _EditEventPageState();
}

class _EditEventPageState extends State<EditEventPage> {
  final _formKey = GlobalKey<FormState>();
  final GlobalKey _imagePickerKey = GlobalKey();
  final _nameController = TextEditingController();
  final _venueController = TextEditingController();
  final _descriptionController = TextEditingController();
  TextEditingController _rowsController = TextEditingController(text: '0');
  TextEditingController _seatsController = TextEditingController(text: '0');
  final _scrollController = ScrollController();
  DateTime? _selectedDate;
  DateTime _selectedDate2 = DateTime.now();
  TimeOfDay? _selectedTime;
  String? _selectedCategory;
  XFile? _eventImage;
  Uint8List? _webImageBytes;
  String? fileType;
  bool _isLoading = false;
  bool _isPaidEvent = true;
  bool _isDailyEvent = false;
  int eventTicketsCount = 0;
  Map<String, dynamic> ticketTypesTicketsCount = {};


  // Ticket type controllers
  final List<TicketType2> _ticketTypes = [];
  final List<String> _predefinedTicketTypes = ['Regular', 'VIP', 'VVIP'];

  final List<String> _categories = [
    'Music',
    'Comedy',
    'Fun',
    'Bars & Grills',
    'Concerts',
    'Theater',
    'Dance',
    'Sports',
    'Festivals',
    'Training',
  ];

  List<Venue> venueSuggestions = [];

  @override
  void initState() {
    super.initState();
    getVenues();
    getTicketsCountByDate();
    _addExistingTicketType(widget.event.ticketTypes);
    _nameController.text = widget.event.name;
    _venueController.text = widget.event.venue;
    _descriptionController.text = widget.event.description;

    DateFormat format = DateFormat("dd-MM-yyyy");
    _isPaidEvent = widget.event.type == 'paid';
    if(widget.event.daily_event == 'no') _selectedDate = format.parse(widget.event.date);
    if(widget.event.daily_event == 'yes') _isDailyEvent = true;
    if((widget.event.time.contains(":"))) _selectedTime = parseTime(widget.event.time);
    _selectedCategory = widget.event.category;
  }
  
  Future<void> getVenues({bool useDNS = true}) async {
    try {
      final Uri uri = useDNS ? Uri.parse('${backend_url}api/venues/${widget.userId}') // Original URL 
      : Uri.parse('${backend_url_with_fallback_ip}api/venues/${widget.userId}'); // Use IP

      final response = await http.get(uri);
    
      if (response.statusCode == 200) {
        final venues = jsonDecode(response.body);

        venues.forEach((venue) {
          setState(() {
            venueSuggestions.add(
              Venue(name: venue['name'], rows: venue['rows'], seats: venue['seats_per_row'])
            );
          });
          if(venue['name'] == widget.event.venue) {
            setState(() {
              _rowsController.text = '${venue['rows']}';
              _seatsController.text = '${venue['seats_per_row']}';
            });
          }
        });
      }
    } on SocketException catch (e) {
      debugPrint('Network error occurred:');
      debugPrint('- Exception type: ${e.runtimeType}');
      debugPrint('- Message: ${e.message}');
      
      if (e.osError != null) {
        debugPrint('  - Error number (errno): ${e.osError!.errorCode}');
        debugPrint('  - OS message: ${e.osError!.message}');

        // Retry with IP if DNS fails (errno = 7) and not already retrying
        if (e.osError!.errorCode == 7 && useDNS) {
          debugPrint('DNS failed! Retrying with IP: ${backend_url_with_fallback_ip}...');
          await getVenues(useDNS: false); // Recursive retry
          return;
        }
      }
    } catch (e) {
      debugPrint('Error getting notification preferences: $e');
    }
  }


  @override
  void dispose() {
    _nameController.dispose();
    _venueController.dispose();
    _rowsController.dispose();
    _seatsController.dispose();
    _descriptionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  TimeOfDay parseTime(String timeString) {
    List<String> parts = timeString.split(":");
    int hour = int.parse(parts[0]);
    int minute = int.parse(parts[1]);
    return TimeOfDay(hour: hour, minute: minute);
  }

  void _addTicketType() {
    setState(() {
      _ticketTypes.add(TicketType2(
        id: 0,
        name: 'Regular',
        price: 0,
        numberOfTickets: 0,
        ticketInformation: "",
        soldTickets: 0,
        isCustom: false,
      ));
    });
  }

  Future<void> getTicketsCountByDate({bool useDNS = true}) async {

    final Uri uri = useDNS ? Uri.parse('${backend_url}api/event_tickets_count_by_date/${widget.event.id}/${DateFormat('d-M-yyyy').format(_selectedDate2)}') // Original URL 
    : Uri.parse('${backend_url_with_fallback_ip}api/event_tickets_count_by_date/${widget.event.id}/${DateFormat('d-M-yyyy').format(_selectedDate2)}'); // Use IP

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if((responseData['tickets_count']) != null){
          setState(() {
            eventTicketsCount = responseData['tickets_count'];
            ticketTypesTicketsCount = responseData['ticket_types'];
          });
        }
        
      }
    }on SocketException catch (e) {
      debugPrint('Network error occurred:');
      debugPrint('- Exception type: ${e.runtimeType}');
      debugPrint('- Message: ${e.message}');
      
      if (e.osError != null) {
        debugPrint('  - Error number (errno): ${e.osError!.errorCode}');
        debugPrint('  - OS message: ${e.osError!.message}');

        // Retry with IP if DNS fails (errno = 7) and not already retrying
        if (e.osError!.errorCode == 7 && useDNS) {
          debugPrint('DNS failed! Retrying with IP: ${backend_url_with_fallback_ip}...');
          await getTicketsCountByDate(useDNS: false); // Recursive retry
          return;
        }
      }
    } catch (e) {
      debugPrint('Error fetching check tickets scan status: $e');
    }
  }

  int getTicketTypesTicketsCount (Map<String, dynamic> ticketTypesTicketsCount, String name) {

    if (ticketTypesTicketsCount.isNotEmpty) {
      if(ticketTypesTicketsCount[name] != null) {
        return ticketTypesTicketsCount[name];
      }else {
        return 0;
      }
    }
    return 0;
  }

  void _addExistingTicketType(List<TicketType> ticketTypes) {
    ticketTypes.forEach((ticketType) {
      setState(() {
        _ticketTypes.add(TicketType2(
          id: ticketType.id,
          name: ticketType.name,
          price: ticketType.price,
          numberOfTickets: ticketType.numberOfTickets,
          ticketInformation: ticketType.ticketInformation,
          soldTickets: ticketType.soldTickets,
          isCustom: ticketType.isCustom,
        ));
      });
    });
  }

  void _removeTicketType(int index) {
    if (_ticketTypes[index].soldTickets == 0) {
      setState(() {
        _ticketTypes.removeAt(index);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'This Ticket Type can\'t be removed, it has ${_ticketTypes[index].soldTickets} booked tickets')),
      );
    }
  }

  // Future<void> _pickImage() async {
  //   final ImagePicker picker = ImagePicker();
  //   try {
  //     final XFile? image = await picker.pickImage(source: ImageSource.gallery);
  //     if (image != null) {
  //       final fileExtension = path.extension(image.path).toLowerCase();
  //       final mimeType = lookupMimeType(image.path);

  //       if (mimeType == null || (!mimeType.startsWith('image/'))) {
  //         print('Invalid file type. Please select a valid image.');
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           const SnackBar(
  //               content: Text('Invalid file type. Please select a valid image.')),
  //         );
  //         return;
  //       }

  //       if (fileExtension != '.png' &&
  //           fileExtension != '.jpg' &&
  //           fileExtension != '.jpeg') {
  //         print('Unsupported image format. Only PNG and JPEG are allowed.');
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           const SnackBar(
  //               content:
  //                   Text('Unsupported image format. Only PNG and JPEG are allowed.')),
  //         );
  //         return;
  //       }

  //       setState(() {
  //         _eventImage = image;
  //         fileType = fileExtension;
  //       });
  //     }
  //   } catch (e) {
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(content: Text('Failed to pick image')),
  //       );
  //     }
  //   }
  // }

  
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        String? mimeType;
        String fileExtension;

        if (kIsWeb) {
          // On web, use `image.name` instead of `image.path`
          fileExtension = path.extension(image.name).toLowerCase();
          mimeType = lookupMimeType(image.name);

          // Read image as bytes for web
          final bytes = await image.readAsBytes();
          _webImageBytes = bytes;
        } else {
          fileExtension = path.extension(image.path).toLowerCase();
          mimeType = lookupMimeType(image.path);
        }

        if (mimeType == null || !mimeType.startsWith('image/')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid file type. Please select a valid image.')),
          );
          return;
        }

        if (fileExtension != '.png' && fileExtension != '.jpg' && fileExtension != '.jpeg') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unsupported image format. Only PNG and JPEG are allowed.')),
          );
          return;
        }

        setState(() {
          _eventImage = image;
          fileType = fileExtension;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to pick image')),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _selectedDate2 = picked;
      });
      getTicketsCountByDate();
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  bool _validateTicketTypes() {
    if (_ticketTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one ticket type')),
      );
      return false;
    }

    int totalNumberOfTickets = 0;
    int index = 0;
    for (var ticketType in _ticketTypes) {
      if (ticketType.price <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ticket prices must be greater than 0')),
        );
        return false;
      }

      if (ticketType.numberOfTickets <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Number of tickets must be greater than 0')),
        );
        return false;
      }

      totalNumberOfTickets = totalNumberOfTickets +  ticketType.numberOfTickets;

      if (getTicketTypesTicketsCount(ticketTypesTicketsCount, ticketType.name) > ticketType.numberOfTickets) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Number of tickets for ${ticketType.name} must be greater than number of sold tickets, ${getTicketTypesTicketsCount(ticketTypesTicketsCount, ticketType.name)}')
          ),
        );
        return false;
      }

      if (ticketType.name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ticket names cannot be empty')),
        );
        return false;
      }

      if (ticketType.name.length > 100) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Ticket names must be 100 characters or less')),
        );
        return false;
      }

      int index_2 = 0;
      for (var ticketType2 in _ticketTypes) {
        if (index != index_2) {
          if (ticketType.name.trim() == ticketType2.name.trim()) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ticket type names should be different')),
            );
            return false;
          }
        }
        index_2++;
      }
      index++;
    }

    if (_selectedCategory == "Theater"){
      try {
        int rows = int.parse(_rowsController.text.trim());
        int seats = int.parse(_seatsController.text.trim());
        int totalNumberOfSeats = rows * seats;
        if(totalNumberOfSeats !=  totalNumberOfTickets) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Number of tickets should be equal to number of seats')
            ),
          );
          return false;
        }
      } catch (e) {
        debugPrint("$e");
      }
    }

    return true;
  }

  bool _validateTicketTypes2() {
    if (_ticketTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one ticket type')),
      );
      return false;
    }

    int totalNumberOfTickets = 0;
    int index = 0;
    for (var ticketType in _ticketTypes) {
      if ((ticketType.price < 0) || (ticketType.price > 0)) {
        ticketType.price = 0;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ticket prices should be 0')),
        );
        return false;
      }

      if (ticketType.numberOfTickets <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Number of tickets must be greater than 0')),
        );
        return false;
      }

      totalNumberOfTickets = totalNumberOfTickets +  ticketType.numberOfTickets;

      if (getTicketTypesTicketsCount(ticketTypesTicketsCount, ticketType.name) > ticketType.numberOfTickets) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Number of tickets for ${ticketType.name} must be greater than number of sold tickets, ${getTicketTypesTicketsCount(ticketTypesTicketsCount, ticketType.name)}')
          ),
        );
        return false;
      }

      if (ticketType.name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ticket names cannot be empty')),
        );
        return false;
      }

      if (ticketType.name.length > 100) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Ticket names must be 100 characters or less')),
        );
        return false;
      }

      int index_2 = 0;
      for (var ticket_2 in _ticketTypes) {
        if (index != index_2) {
          if (ticketType.name.trim() == ticket_2.name.trim()) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ticket type names should be different')),
            );
            return false;
          }
        }
        index_2++;
      }
      index++;
    }

    if (_selectedCategory == "Theater"){
      try {
        int rows = int.parse(_rowsController.text.trim());
        int seats = int.parse(_seatsController.text.trim());
        int totalNumberOfSeats = rows * seats;
        if(totalNumberOfSeats !=  totalNumberOfTickets) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Number of tickets should be equal to number of seats')
            ),
          );
          return false;
        }
      } catch (e) {
        debugPrint("$e");
      }
    }

    return true;
  }

  void _scrollToFirstError() {
    final focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Scrollable.ensureVisible(
        _formKey.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
      focusNode.requestFocus();
    });
  }

  Future<void> _submitEvent({bool useDNS = true}) async {
    if (!_formKey.currentState!.validate()) {
      _scrollToFirstError();
      return;
    }

    if (!_isDailyEvent && (_selectedDate == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select event date')),
      );
      return;
    }

    if (!_isDailyEvent && (_selectedTime == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select event time')),
      );
      return;
    }

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select event category')),
      );
      return;
    }

    if (_isPaidEvent) {
      if (!_validateTicketTypes()) {
        return;
      }
    } else {
      if (!_validateTicketTypes2()) {
        return;
      }
    }

    String eventName = _nameController.text.trim();
    String eventVenue = _venueController.text.trim();
    String eventDescription = _descriptionController.text.trim();

    for (var ticket in _ticketTypes) {
      ticket.name = ticket.name.trim();
    }

    final Map<String, dynamic> requestBody = {
      'user_id': widget.userId,
      'event_id': widget.event.id,
      'name': eventName,
      'category': _selectedCategory,
      'date': _isDailyEvent ? '' : _selectedDate?.toIso8601String(),
      'time': '${_selectedTime!.hour}:${_selectedTime!.minute}',
      'venue': eventVenue,
      'rows': (_selectedCategory == "Theater") ?    int.tryParse(_rowsController.text.trim()) ?? 0 : 0,
      'seats': (_selectedCategory == "Theater") ? int.tryParse(_seatsController.text.trim()) ?? 0 : 0,
      'description': eventDescription,
      if (_isPaidEvent) 'type': "paid",
      if (!_isPaidEvent) 'type': "free",
      'daily_event': _isDailyEvent ? "yes" : "no",
      'ticket_types': _ticketTypes
          .map((ticket) => {
                'id': ticket.id,
                'name': ticket.name,
                'price': ticket.price,
                'number_of_tickets': ticket.numberOfTickets,
                'ticket_information': ticket.ticketInformation,
                'is_custom': ticket.isCustom,
              })
          .toList(),
      'file_type': fileType,
      if (_eventImage != null)
        'event_image': kIsWeb ? _webImageBytes : base64Encode(await File(_eventImage!.path).readAsBytes()),
    };

    try {
      setState(() {
        _isLoading = true;
      });

      final Uri uri = useDNS ? Uri.parse('${backend_url}api/update_event') // Original URL 
      : Uri.parse('${backend_url_with_fallback_ip}api/update_event'); // Use IP
        

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        if (response.body == "Event updated successfully!") {
          widget.refreshMethod();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${response.body}')),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Response: ${response.body}')),
          );
        }
      } else if (response.statusCode == 302) {
        _handleHTTPRedirect();
      } else {
        _showSnackBar('Request failed: ${response.statusCode}');
      }
    } on SocketException catch (e) {
      debugPrint('Network error occurred:');
      debugPrint('- Exception type: ${e.runtimeType}');
      debugPrint('- Message: ${e.message}');
      
      if (e.osError != null) {
        debugPrint('  - Error number (errno): ${e.osError!.errorCode}');
        debugPrint('  - OS message: ${e.osError!.message}');

        // Retry with IP if DNS fails (errno = 7) and not already retrying
        if (e.osError!.errorCode == 7 && useDNS) {
          debugPrint('DNS failed! Retrying with IP: ${backend_url_with_fallback_ip}...');
          await _submitEvent(useDNS: false); // Recursive retry
          return;
        }
      }

      _handleSocketException(e);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> removeEvent({bool useDNS = true}) async {
    final Uri uri = useDNS ? Uri.parse('${backend_url}api/remove_event/${widget.event.id}/${widget.userId}') // Original URL 
    : Uri.parse('${backend_url_with_fallback_ip}api/remove_event/${widget.event.id}/${widget.userId}'); // Use IP

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        if (response.body == "Event removed successfully!") {
          widget.refreshMethod();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${response.body}')),
          );
          Navigator.pop(context);
        }
      }  else if (response.statusCode == 302) {
        _handleHTTPRedirect();
      } else {
        _showSnackBar('Request failed: ${response.statusCode}');
      }
    } on SocketException catch (e) {
      debugPrint('Network error occurred:');
      debugPrint('- Exception type: ${e.runtimeType}');
      debugPrint('- Message: ${e.message}');
      
      if (e.osError != null) {
        debugPrint('  - Error number (errno): ${e.osError!.errorCode}');
        debugPrint('  - OS message: ${e.osError!.message}');

        // Retry with IP if DNS fails (errno = 7) and not already retrying
        if (e.osError!.errorCode == 7 && useDNS) {
          debugPrint('DNS failed! Retrying with IP: ${backend_url_with_fallback_ip}...');
          await removeEvent(useDNS: false); // Recursive retry
          return;
        }
      }

      _handleSocketException(e);
    } catch (e) {
      debugPrint('Error removing event: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error removing event: $e')),
      );
    }
  }

  Future<void> closeEventBooking({bool useDNS = true}) async {
    final Uri uri = useDNS ? Uri.parse('${backend_url}api/close_event_booking/${widget.event.id}/${widget.userId}') // Original URL 
    : Uri.parse('${backend_url_with_fallback_ip}api/close_event_booking/${widget.event.id}/${widget.userId}'); // Use IP

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        if (response.body == "Event closed successfully!") {
          widget.refreshMethod();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${response.body}')),
          );
          Navigator.pop(context);
        }
      } else if (response.statusCode == 302) {
        _handleHTTPRedirect();
      } else {
        _showSnackBar('Request failed: ${response.statusCode}');
      }
    } on SocketException catch (e) {
      debugPrint('Network error occurred:');
      debugPrint('- Exception type: ${e.runtimeType}');
      debugPrint('- Message: ${e.message}');
      
      if (e.osError != null) {
        debugPrint('  - Error number (errno): ${e.osError!.errorCode}');
        debugPrint('  - OS message: ${e.osError!.message}');

        // Retry with IP if DNS fails (errno = 7) and not already retrying
        if (e.osError!.errorCode == 7 && useDNS) {
          debugPrint('DNS failed! Retrying with IP: ${backend_url_with_fallback_ip}...');
          await closeEventBooking(useDNS: false); // Recursive retry
          return;
        }
      }

      _handleSocketException(e);
    } catch (e) {
      debugPrint('Error closing event: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error closing event: $e')),
      );
    }
  }

  Future<void> openEventBooking({bool useDNS = true}) async {
    final Uri uri = useDNS ? Uri.parse('${backend_url}api/open_event_booking/${widget.event.id}/${widget.userId}') // Original URL 
    : Uri.parse('${backend_url_with_fallback_ip}api/open_event_booking/${widget.event.id}/${widget.userId}'); // Use IP

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        if (response.body == "Event opened successfully!") {
          widget.refreshMethod();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${response.body}')),
          );
          Navigator.pop(context);
        }
      } else if (response.statusCode == 302) {
        _handleHTTPRedirect();
      } else {
        _showSnackBar('Request failed: ${response.statusCode}');
      }
    } on SocketException catch (e) {
      debugPrint('Network error occurred:');
      debugPrint('- Exception type: ${e.runtimeType}');
      debugPrint('- Message: ${e.message}');
      
      if (e.osError != null) {
        debugPrint('  - Error number (errno): ${e.osError!.errorCode}');
        debugPrint('  - OS message: ${e.osError!.message}');

        // Retry with IP if DNS fails (errno = 7) and not already retrying
        if (e.osError!.errorCode == 7 && useDNS) {
          debugPrint('DNS failed! Retrying with IP: ${backend_url_with_fallback_ip}...');
          await openEventBooking(useDNS: false); // Recursive retry
          return;
        }
      }

      _handleSocketException(e);
    } catch (e) {
      debugPrint('Error opening event: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening event: $e')),
      );
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

    void _handleSocketException(SocketException e) {
    if (e.osError?.errorCode == 7 || e.osError?.errorCode == 101 || e.osError?.errorCode == 111) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Connection Error'),
          content: const Text('Could not connect to the server. Please check your internet connection.'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
    } else {
      _showSnackBar('Connection Error: ${e.message}');
    }
  }

  void _handleHTTPRedirect() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connection Error'),
        content: const Text('Could not connect to the server. Please check your internet connection.'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildTicketTypeField(int index) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 600) {
                  // Mobile layout
                  return 
                  Column(
                    children: [
                      _ticketTypes[index].isCustom
                          ? TextFormField(
                              initialValue: _ticketTypes[index].name,
                              decoration: InputDecoration(
                                labelText: 'Custom Ticket Type',
                                border: const OutlineInputBorder(),
                                filled: true,
                                fillColor: Colors.grey[200],
                              ),
                              style: const TextStyle(fontSize: 14.0),
                              onChanged: (value) {
                                setState(() {
                                  _ticketTypes[index].name = value;
                                });
                              },
                            )
                          : DropdownButtonFormField<String>(
                              value: _ticketTypes[index].name,
                              decoration: InputDecoration(
                                labelText: 'Ticket Type',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                      color: Colors.orange[800]!, width: 2),
                                ),
                                filled: true,
                                fillColor: Colors.grey[200],
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 8),
                              ),
                              items: _predefinedTicketTypes
                                  .map((type) => DropdownMenuItem(
                                        value: type,
                                        child: Text(
                                          type,
                                          style: const TextStyle(fontSize: 14.0),
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _ticketTypes[index].name = value!;
                                });
                              },
                            ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            flex: 1, // Gives more space to the price field
                            child: TextFormField(
                              initialValue: _isPaidEvent
                                  ? _ticketTypes[index].price.toString()
                                  : "0",
                              decoration: InputDecoration(
                                labelText: 'Price',
                                prefixText: 'TSH ',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                filled: true,
                                fillColor: Colors.grey[200],
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 8,
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontSize: 14.0),
                              enabled: _isPaidEvent,
                              onChanged: (value) {
                                setState(() {
                                  _ticketTypes[index].price =
                                      double.tryParse(value) ?? 0;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8), // Add some spacing between the fields
                          Expanded(
                            flex: 1, // Gives less space to the number field
                            child: TextFormField(
                              initialValue:
                                  _ticketTypes[index].numberOfTickets.toString(),
                              decoration: InputDecoration(
                                labelText: 'Number',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                      color: Colors.orange[800]!, width: 2),
                                ),
                                filled: true,
                                fillColor: Colors.grey[200],
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 8),
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              style: const TextStyle(fontSize: 14.0),
                              onChanged: (value) {
                                setState(() {
                                  _ticketTypes[index].numberOfTickets =
                                      int.tryParse(value) ?? 0;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: _ticketTypes[index].ticketInformation,
                        maxLength: 250, // Added max length limit
                        decoration: InputDecoration(
                          labelText: 'Ticket Information',
                          labelStyle: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                          hintText: 'Enter icket information...', // Optional hint text
                          hintStyle: TextStyle(
                            color: Colors.grey[500], // Lighter color for hint text
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8), // Rounded corners
                            borderSide: BorderSide(
                              color: Colors.grey[400]!, // Light border color
                              width: 1.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Colors.orange[800]!, // Border color on focus
                              width: 2,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Colors.grey[400]!, // Default border color
                              width: 1.5,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.grey[200], // Light background color
                          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12), // Padding for the content
                        ),
                        onChanged: (value) {
                          setState(() {
                            _ticketTypes[index].ticketInformation = value;
                          });
                        },
                        maxLines: 3,
                        style: const TextStyle(
                          fontSize: 16, // Input text font size
                          color: Colors.black, // Input text color
                        ),
                        validator: (value) {
                          if (value!.length > 250) {
                            return 'Ticket information must be 250 characters or less';
                          }
                          return null;
                        },
                      ),
                    ],
                  );
                } else {
                  // Tablet/Desktop layout
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: _ticketTypes[index].isCustom
                                ? TextFormField(
                                    initialValue: _ticketTypes[index].name,
                                    decoration: InputDecoration(
                                      labelText: 'Custom Ticket Type',
                                      border: const OutlineInputBorder(),
                                      filled: true,
                                      fillColor: Colors.grey[200],
                                    ),
                                    style: const TextStyle(fontSize: 14.0),
                                    onChanged: (value) {
                                      setState(() {
                                        _ticketTypes[index].name = value;
                                      });
                                    },
                                  )
                                : DropdownButtonFormField<String>(
                                    value: _ticketTypes[index].name,
                                    decoration: InputDecoration(
                                      labelText: 'Ticket Type',
                                      border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10)),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                            color: Colors.orange[800]!, width: 2),
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey[200],
                                      contentPadding: const EdgeInsets.symmetric(
                                          vertical: 8, horizontal: 8),
                                    ),
                                    items: _predefinedTicketTypes
                                        .map((type) => DropdownMenuItem(
                                              value: type,
                                              child: Text(
                                                type,
                                                style:
                                                    const TextStyle(fontSize: 14.0),
                                              ),
                                            ))
                                        .toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _ticketTypes[index].name = value!;
                                      });
                                    },
                                  ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              initialValue: _isPaidEvent
                                  ? _ticketTypes[index].price.toString()
                                  : "0",
                              decoration: InputDecoration(
                                labelText: 'Price',
                                prefixText: 'TSH ',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                filled: true,
                                fillColor: Colors.grey[200],
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 8,
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontSize: 14.0),
                              enabled: _isPaidEvent,
                              onChanged: (value) {
                                setState(() {
                                  _ticketTypes[index].price =
                                      double.tryParse(value) ?? 0;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              initialValue:
                                  _ticketTypes[index].numberOfTickets.toString(),
                              decoration: InputDecoration(
                                labelText: 'Number',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                      color: Colors.orange[800]!, width: 2),
                                ),
                                filled: true,
                                fillColor: Colors.grey[200],
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 8),
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              style: const TextStyle(fontSize: 14.0),
                              onChanged: (value) {
                                setState(() {
                                  _ticketTypes[index].numberOfTickets =
                                      int.tryParse(value) ?? 0;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: _ticketTypes[index].ticketInformation,
                        maxLength: 250, // Added max length limit
                        decoration: InputDecoration(
                          labelText: 'Ticket Information',
                          labelStyle: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                          hintText: 'Enter icket information...', // Optional hint text
                          hintStyle: TextStyle(
                            color: Colors.grey[500], // Lighter color for hint text
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8), // Rounded corners
                            borderSide: BorderSide(
                              color: Colors.grey[400]!, // Light border color
                              width: 1.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Colors.orange[800]!, // Border color on focus
                              width: 2,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Colors.grey[400]!, // Default border color
                              width: 1.5,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.grey[200], // Light background color
                          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12), // Padding for the content
                        ),
                        onChanged: (value) {
                          setState(() {
                            _ticketTypes[index].ticketInformation = value;
                          });
                        },
                        maxLines: 3,
                        style: const TextStyle(
                          fontSize: 16, // Input text font size
                          color: Colors.black, // Input text color
                        ),
                        validator: (value) {
                          if (value!.length > 250) {
                            return 'Ticket information must be 250 characters or less';
                          }
                          return null;
                        },
                      ),
                    ]
                  );
                }
              },
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _ticketTypes[index].isCustom =
                          !_ticketTypes[index].isCustom;
                      if (!_ticketTypes[index].isCustom) {
                        _ticketTypes[index].name = _predefinedTicketTypes[0];
                      }
                    });
                  },
                  icon: Icon(_ticketTypes[index].isCustom
                      ? Icons.list
                      : Icons.edit),
                  label: Text(_ticketTypes[index].isCustom
                      ? 'Use Predefined'
                      : 'Custom Type'),
                ),
                if (_ticketTypes.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _removeTicketType(index),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label, {String? prefixText, IconData? prefixIcon}) {
    return InputDecoration(
      labelText: label,
      prefixText: prefixText,
      prefixIcon: (prefixIcon != null) ? Icon(
        prefixIcon,
        color: Colors.grey[600],
      ) : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[400]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[400]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.orange[800]!, width: 2),
      ),
      filled: true,
      fillColor: Colors.grey[200],
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
    );
  }

  Widget _buildRowsAndSeatsField() {
   
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Theater Layout Configuration',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildRowsField(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSeatsField(),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Example: 8 rows × 12 seats = 96 total seats',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildRowsField() {
    return TextFormField(
      controller: _rowsController,
      decoration: _buildInputDecoration('Rows'),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(fontSize: 14),
    );
  }

  Widget _buildSeatsField() {
    return TextFormField(
      controller: _seatsController,
      decoration: _buildInputDecoration('Seats'),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(fontSize: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Event'),
        backgroundColor: const Color.fromARGB(255, 240, 244, 247),
        actions: [
          (widget.event.soldTickets < 1)
              ? IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    final shouldRemove = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        backgroundColor: Colors.white,
                        elevation: 24,
                        title: const Row(
                          children: [
                            Icon(Icons.delete_forever, color: Colors.red),
                            SizedBox(width: 10),
                            Text(
                              'Remove Event',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                        content: const Text(
                          'Are you sure you want to remove this event?',
                          style: TextStyle(fontSize: 16),
                        ),
                        actionsPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.grey[700],
                            ),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Ok'),
                          ),
                        ],
                      ),
                    );

                    if (shouldRemove ?? false) {
                      removeEvent();
                    }
                  },
                )
              : (widget.event.status == "closed")
                  ? IconButton(
                      icon: const Icon(Icons.check_circle_outline,
                          color: Colors.green, size: 30),
                      onPressed: () async {
                        final shouldOpen = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            backgroundColor: Colors.white,
                            elevation: 24,
                            title: const Row(
                              children: [
                                Icon(Icons.check_circle_outline,
                                    color: Colors.green),
                                SizedBox(width: 10),
                                Text(
                                  'Open Booking',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                            content: const Text(
                              'Are you sure you want to open ticket booking for this event?',
                              style: TextStyle(fontSize: 16),
                            ),
                            actionsPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.grey[700],
                                ),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text('Open Booking'),
                              ),
                            ],
                          ),
                        );

                        if (shouldOpen ?? false) {
                          openEventBooking();
                        }
                      },
                    )
                  : IconButton(
                      icon: const Icon(Icons.event_busy,
                          color: Colors.red, size: 30),
                      onPressed: () async {
                        final shouldClose = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            backgroundColor: Colors.white,
                            elevation: 24,
                            title: const Row(
                              children: [
                                Icon(Icons.event_busy, color: Colors.red),
                                SizedBox(width: 10),
                                Text(
                                  'Close Booking',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                            content: const Text(
                              'Are you sure you want to close ticket booking for this event?',
                              style: TextStyle(fontSize: 16),
                            ),
                            actionsPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.grey[700],
                                ),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text('Close Booking'),
                              ),
                            ],
                          ),
                        );

                        if (shouldClose ?? false) {
                          closeEventBooking();
                        }
                      },
                    ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isLargeScreen ? 800 : double.infinity,
          ),
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Event Type',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          Text(
                            _isPaidEvent ? 'Paid Event' : 'Free Event',
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(width: 8),
                          Switch(
                            value: _isPaidEvent,
                            onChanged: null,
                            activeColor: Colors.orange[800],
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Daily Event',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          Text(
                            _isDailyEvent ? 'Daily Event(Yes)' : 'Daily Event(No)',
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(width: 8),
                          Switch(
                            value: _isDailyEvent,
                            onChanged: (value) => setState(() {
                              _isDailyEvent = value;
                              if (!_isDailyEvent) {
                                for (var ticket in _ticketTypes) {
                                  ticket.price = 0;
                                }
                              }
                            }),
                            activeColor: Colors.orange[800],
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    key: _imagePickerKey,
                    onTap: _pickImage,
                    child: Container(
                      height: isLargeScreen ? 300 : 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _eventImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: kIsWeb ? 
                              Image.memory(
                                _webImageBytes!,
                                fit: BoxFit.cover,
                              ) :
                              Image.file(
                                File(_eventImage!.path),
                                fit: BoxFit.cover,
                              ),
                            )
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate, size: 48),
                                SizedBox(height: 8),
                                Text('Add Event Poster'),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    maxLength: 100,
                    decoration: InputDecoration(
                      labelText: 'Event Name',
                      labelStyle: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                      prefixIcon: Icon(
                        Icons.emoji_events,
                        color: Colors.grey[600],
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide(
                          color: Colors.grey[400]!,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide(
                          color: Colors.grey[400]!,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide(
                          color: Colors.orange[800]!,
                          width: 2.0,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 16.0, horizontal: 16.0),
                    ),
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter event name';
                      }
                      if (value.length > 100) {
                        return 'Name must be 100 characters or less';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Category',
                  labelStyle: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Colors.grey[400]!,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Colors.grey[400]!,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Colors.orange[800]!,
                      width: 2.0,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.grey[200], // Light background color
                  contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                ),
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                ),
                icon: Icon(
                  Icons.arrow_drop_down,
                  color: Colors.grey[600],
                ),
                iconSize: 24,
                items: _categories.map((String category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(
                      category,
                      style: const TextStyle(
                        fontSize: 16,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (String? value) {
                  setState(() {
                    _selectedCategory = value;
                  });
                },
                validator: (value) =>
                    value == null ? 'Please select a category' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if(!_isDailyEvent)
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _selectDate(context),
                      icon: Icon(
                        Icons.calendar_today,
                        color: Colors.orange[800],
                        size: 24,
                      ),
                      label: Text(
                        _selectedDate == null
                            ? 'Select Date'
                            : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                        style: TextStyle(
                          color: _selectedDate == null ? Colors.grey[600] : Colors.black,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        side: BorderSide(
                          // color: _selectedDate == null ? Colors.grey[400]! : Colors.orange[800]!,
                          color: Colors.grey[400]!,
                          width: 1.5,
                        ),
                        backgroundColor: Colors.grey[200], // Light background color
                      ),
                    ),
                  ),
                  if(!_isDailyEvent)
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _selectTime(context),
                      icon: Icon(
                        Icons.access_time,
                        color: Colors.orange[800],
                        size: 24,
                      ),
                      label: Text(
                        _selectedTime == null
                            ? 'Select Time'
                            : _selectedTime!.format(context),
                        style: TextStyle(
                          color: _selectedTime == null ? Colors.grey[600] : Colors.black,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        side: BorderSide(
                          // color: _selectedTime == null ? Colors.grey[400]! : Colors.orange[800]!,
                          color: Colors.grey[400]!,
                          width: 1.5,
                        ),
                        backgroundColor: Colors.grey[200], // Light background color
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Autocomplete<Venue>(
               

                optionsBuilder: (TextEditingValue textEditingValue) {
                  // Show initial options if text is empty and we have an initial value
                  if (textEditingValue.text.isEmpty && _venueController.text.isNotEmpty) {
                    return venueSuggestions.where((venue) => 
                      venue.name.toLowerCase().contains(_venueController.text.toLowerCase())
                    );
                  }
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<Venue>.empty();
                  }
                  return venueSuggestions.where((venue) => 
                    venue.name.toLowerCase().contains(textEditingValue.text.toLowerCase())
                  );
                },

                displayStringForOption: (Venue venue) => venue.name,
                onSelected: (Venue selection) {
                  _venueController.text = selection.name;
                  setState(() {
                    _rowsController.text = '${selection.rows}';
                    _seatsController.text = '${selection.seats}';
                  });
                },
                fieldViewBuilder: (
                  BuildContext context,
                  TextEditingController fieldController,
                  FocusNode fieldFocusNode,
                  VoidCallback onFieldSubmitted,
                ) {
                  // Sync the field controller with your main controller
                  if (_venueController.text != fieldController.text) {
                    fieldController.text = _venueController.text;
                  }
                  
                  return TextFormField(
                    controller: fieldController,
                    focusNode: fieldFocusNode,
                    maxLength: 100,
                    decoration: (_selectedCategory == "Theater") ? _buildInputDecoration('Theater', prefixIcon: Icons.location_on) : _buildInputDecoration('Location/Venue', prefixIcon: Icons.location_on),
                    style: const TextStyle(fontSize: 16),
                    validator: (value) {
                      if (value == null || value.isEmpty) return (_selectedCategory == "Theater") ? 'Please enter theater name' : 'Please enter location/venue name';
                      if (value.length > 100) return (_selectedCategory == "Theater") ? 'Theater name must be 100 characters or less' : 'Location/Venue name must be 100 characters or less';
                      _venueController.text = value;
                      return null;
                    },
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4.0,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (BuildContext context, int index) {
                            final option = options.elementAt(index);
                            return ListTile(
                              title: Text(option.name),
                              onTap: () {
                                onSelected(option);
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              if(_selectedCategory == "Theater")
              _buildRowsAndSeatsField(),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLength: 1000, // Added max length limit
                decoration: InputDecoration(
                  labelText: 'Description',
                  labelStyle: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                  hintText: 'Enter the description here...', // Optional hint text
                  hintStyle: TextStyle(
                    color: Colors.grey[500], // Lighter color for hint text
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8), // Rounded corners
                    borderSide: BorderSide(
                      color: Colors.grey[400]!, // Light border color
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Colors.orange[800]!, // Border color on focus
                      width: 2,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Colors.grey[400]!, // Default border color
                      width: 1.5,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.grey[200], // Light background color
                  contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12), // Padding for the content
                ),
                maxLines: 6, 
                style: const TextStyle(
                  fontSize: 16, // Input text font size
                  color: Colors.black, // Input text color
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter description';
                  }
                  if (value.length > 1000) {
                    return 'Description must be 1000 characters or less';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),
              const Text(
                'Ticket Types',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ..._ticketTypes.asMap().entries.map((entry) {
                return _buildTicketTypeField(entry.key);
              }),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: _addTicketType,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Ticket Type'),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitEvent,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading ? const CircularProgressIndicator() :
                    const Text(
                    'Save Event',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
          )
        ),
      ),
    );
  }
}
