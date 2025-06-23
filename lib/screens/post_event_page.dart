import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:tiketi_mkononi/env.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;
import 'package:tiketi_mkononi/services/storage_service.dart';

class TicketType {
  String name;
  double price;
  int numberOfTickets;
  String ticketInformation;
  bool isCustom;

  TicketType({
    required this.name,
    required this.price,
    required this.numberOfTickets,
    required this.ticketInformation,
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

class PostEventPage extends StatefulWidget {
  final Function refreshMethod;

  const PostEventPage({super.key, required this.refreshMethod});

  @override
  State<PostEventPage> createState() => _PostEventPageState();
}

class _PostEventPageState extends State<PostEventPage> {
  int userId = 0;
  final _formKey = GlobalKey<FormState>();
  final GlobalKey _imagePickerKey = GlobalKey();
  final _nameController = TextEditingController();
  final _venueController = TextEditingController();
  final _descriptionController = TextEditingController();
  TextEditingController _rowsController = TextEditingController();
  TextEditingController _seatsController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String? _selectedCategory;
  XFile? _eventImage;
  String? fileType;
  bool _isLoading = false;
  bool _isPaidEvent = true;
  bool _isDailyEvent = false;
  late final StorageService _storageService;

  final List<TicketType> _ticketTypes = [];
  final List<String> _predefinedTicketTypes = ['Regular', 'VIP', 'VVIP'];
  final List<String> _categories = [
    'Comedy',
    'Fun',
    'Bars & Grills',
    'Concerts',
    'Theater',
    'Sports',
    'Training',
  ];

  List<Venue> venueSuggestions = [];

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _addTicketType();
    _rowsController = TextEditingController(text: '0');
    _seatsController = TextEditingController(text: '0');
  }

  Future<void> _initializeServices() async {
    final prefs = await SharedPreferences.getInstance();
    _storageService = StorageService(prefs);
    _loadUserProfile();
  }

  void _loadUserProfile() {
    final profile = _storageService.getUserProfile();
    if (profile != null) {
      setState(() {
        userId = profile.id;
      });

      getVenues();
    }
  }

  bool _isLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.width > 768;
  }

  void _addTicketType() {
    setState(() {
      _ticketTypes.add(TicketType(
        name: 'Regular', 
        price: 0, 
        numberOfTickets: 0,
        ticketInformation: "",
        isCustom: false
      ));
    });
  }

  void _removeTicketType(int index) {
    setState(() {
      _ticketTypes.removeAt(index);
    });
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final fileExtension = path.extension(image.path).toLowerCase();
        final mimeType = lookupMimeType(image.path);

        if (mimeType == null || (!mimeType.startsWith('image/'))) {
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
      });
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
    for (var i = 0; i < _ticketTypes.length; i++) {
      final ticketType = _ticketTypes[i];
      
      if (_isPaidEvent && ticketType.price <= 0) {
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

      if (ticketType.name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ticket names cannot be empty')),
        );
        return false;
      }

      if (ticketType.name.length > 100) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ticket names must be 100 characters or less')),
        );
        return false;
      }

      for (var j = i + 1; j < _ticketTypes.length; j++) {
        if (ticketType.name.trim() == _ticketTypes[j].name.trim()) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ticket type names should be different')),
          );
          return false;
        }
      }
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Scrollable.ensureVisible(
        _formKey.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
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

    if (_eventImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select event poster')),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Scrollable.ensureVisible(
          _imagePickerKey.currentContext!,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      });
      return;
    }

    if (!_validateTicketTypes()) {
      return;
    }

    final Map<String, dynamic> requestBody = {
      'user_id': userId,
      'name': _nameController.text.trim(),
      'category': _selectedCategory,
      'date': _isDailyEvent ? '' : _selectedDate?.toIso8601String(),
      'time': '${_selectedTime!.hour}:${_selectedTime!.minute}',
      'venue': _venueController.text.trim(),
      'rows': (_selectedCategory == "Theater") ?    int.tryParse(_rowsController.text.trim()) ?? 0 : 0,
      'seats': (_selectedCategory == "Theater") ? int.tryParse(_seatsController.text.trim()) ?? 0 : 0,
      'description': _descriptionController.text.trim(),
      'type': _isPaidEvent ? "paid" : "free",
      'daily_event': _isDailyEvent ? "yes" : "no",
      'ticket_types': _ticketTypes.map((ticket) => {
        'name': ticket.name.trim(),
        'price': ticket.price,
        'number_of_tickets': ticket.numberOfTickets,
        'ticket_information': ticket.ticketInformation.trim(),
        'is_custom': ticket.isCustom,
      }).toList(),
      'file_type': fileType,
      'event_image': base64Encode(await File(_eventImage!.path).readAsBytes()),
    };

    try {
      setState(() => _isLoading = true);

      final Uri uri = useDNS ? Uri.parse('${backend_url}api/post_event') // Original URL 
      : Uri.parse('${backend_url_with_fallback_ip}api/post_event'); // Use IP

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        if (response.body == "Event posted successfully!") {
          widget.refreshMethod();
          Navigator.pop(context);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.body)),
        );
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
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
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

  
  Future<void> getVenues({bool useDNS = true}) async {
    try {
      final Uri uri = useDNS ? Uri.parse('${backend_url}api/venues/$userId') // Original URL 
      : Uri.parse('${backend_url_with_fallback_ip}api/venues/$userId'); // Use IP

      final response = await http.get(uri);
    
      if (response.statusCode == 200) {
        final venues = jsonDecode(response.body);

        venues.forEach((venue) {
          setState(() {
            venueSuggestions.add(
              Venue(name: venue['name'], rows: venue['rows'], seats: venue['seats_per_row'])
            );
          });
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
    _descriptionController.dispose();
    _rowsController.dispose();
    _seatsController.dispose();
    super.dispose();
  }

  Widget _buildTicketTypeField(int index, bool isLargeScreen) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            isLargeScreen 
                ? _buildDesktopTicketFields(index)
                : _buildMobileTicketFields(index),
            const SizedBox(height: 8),
            _buildTicketActions(index),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopTicketFields(int index) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _buildTicketTypeDropdown(index),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildPriceField(index),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildQuantityField(index),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          maxLength: 250, // Added max length limit
          decoration: InputDecoration(
            labelText: 'Ticket Information',
            labelStyle: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
            hintText: 'Enter ticket information...', // Optional hint text
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
              _ticketTypes[index].ticketInformation = value.trim();
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

  Widget _buildMobileTicketFields(int index) {
    return Column(
      children: [
        _buildTicketTypeDropdown(index),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildPriceField(index),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildQuantityField(index),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
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
              _ticketTypes[index].ticketInformation = value.trim();
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
  }

  Widget _buildTicketTypeDropdown(int index) {
    return _ticketTypes[index].isCustom
        ? TextFormField(
            initialValue: _ticketTypes[index].name,
            decoration: _buildInputDecoration('Custom Ticket Type'),
            style: const TextStyle(fontSize: 14),
            onChanged: (value) => setState(() => _ticketTypes[index].name = value),
          )
        : DropdownButtonFormField<String>(
            value: _ticketTypes[index].name,
            decoration: _buildInputDecoration('Ticket Type'),
            items: _predefinedTicketTypes.map((type) {
              return DropdownMenuItem<String>(
                value: type,
                child: Text(type, style: const TextStyle(fontSize: 14)),
              );
            }).toList(),
            onChanged: (value) => setState(() => _ticketTypes[index].name = value!),
          );
  }

  Widget _buildPriceField(int index) {
    return TextFormField(
      initialValue: _ticketTypes[index].price.toString(),
      decoration: _buildInputDecoration('Price', prefixText: 'TSH '),
      keyboardType: TextInputType.number,
      style: const TextStyle(fontSize: 14),
      enabled: _isPaidEvent,
      onChanged: (value) => setState(() {
        _ticketTypes[index].price = double.tryParse(value) ?? 0;
      }),
    );
  }

  Widget _buildQuantityField(int index) {
    return TextFormField(
      initialValue: _ticketTypes[index].numberOfTickets.toString(),
      decoration: _buildInputDecoration('Quantity'),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(fontSize: 14),
      onChanged: (value) => setState(() {
        _ticketTypes[index].numberOfTickets = int.tryParse(value) ?? 0;
      }),
    );
  }

  Widget _buildTicketActions(int index) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton.icon(
          onPressed: () => setState(() {
            _ticketTypes[index].isCustom = !_ticketTypes[index].isCustom;
            if (!_ticketTypes[index].isCustom) {
              _ticketTypes[index].name = _predefinedTicketTypes[0];
            }
          }),
          icon: Icon(_ticketTypes[index].isCustom ? Icons.list : Icons.edit),
          label: Text(_ticketTypes[index].isCustom ? 'Use Predefined' : 'Custom Type'),
        ),
        if (_ticketTypes.length > 1)
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _removeTicketType(index),
          ),
      ],
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

  Widget _buildImagePicker(bool isLargeScreen) {
    return GestureDetector(
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
                child: Image.file(
                  File(_eventImage!.path),
                  fit: BoxFit.cover,
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate, size: isLargeScreen ? 64 : 48),
                  const SizedBox(height: 8),
                  const Text('Add Event Poster'),
                ],
              ),
      ),
    );
  }

  Widget _buildDateTimePickers(bool isLargeScreen) {
    return
    Row(
      children: [
        if(!_isDailyEvent) Expanded(child: _buildDatePicker()),
        if(!_isDailyEvent) const SizedBox(width: 16),
        Expanded(child: _buildTimePicker()),
      ],
    );
  }

  Widget _buildDatePicker() {
    return TextButton.icon(
      onPressed: () => _selectDate(context),
      icon: Icon(Icons.calendar_today, color: Colors.orange[800]),
      label: Text(
        _selectedDate == null
            ? 'Select Date'
            : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
        style: TextStyle(
          color: _selectedDate == null ? Colors.grey[600] : Colors.black,
          fontWeight: FontWeight.w500,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        side: BorderSide(
          color: _selectedDate == null ? Colors.grey[400]! : Colors.orange[800]!,
          width: 1.5,
        ),
        backgroundColor: Colors.grey[200],
      ),
    );
  }

  Widget _buildTimePicker() {
    return TextButton.icon(
      onPressed: () => _selectTime(context),
      icon: Icon(Icons.access_time, color: Colors.orange[800]),
      label: Text(
        _selectedTime == null
            ? 'Select Time'
            : _selectedTime!.format(context),
        style: TextStyle(
          color: _selectedTime == null ? Colors.grey[600] : Colors.black,
          fontWeight: FontWeight.w500,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        side: BorderSide(
          color: _selectedTime == null ? Colors.grey[400]! : Colors.orange[800]!,
          width: 1.5,
        ),
        backgroundColor: Colors.grey[200],
      ),
    );
  }

  Widget _buildEventTypeToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Event Type',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
              onChanged: (value) => setState(() {
                _isPaidEvent = value;
                if (!_isPaidEvent) {
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
    );
  }

  Widget _buildDailyEventToggle() {
    return Row(
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

  // Helper method to calculate total seats
  String _calculateTotalSeats(String rows, String seatsPerRow) {
    final rowCount = int.tryParse(rows) ?? 0;
    final seatCount = int.tryParse(seatsPerRow) ?? 0;
    return (rowCount * seatCount).toString();
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
    final isLargeScreen = _isLargeScreen(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Post Event'),
        backgroundColor: const Color.fromARGB(255, 240, 244, 247),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isLargeScreen ? 1000 : double.infinity,
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isLargeScreen ? 32 : 16,
              vertical: 16,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isLargeScreen) ...[
                    const Text(
                      'Create New Event',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _buildEventTypeToggle(),
                  const SizedBox(height: 6),
                  _buildDailyEventToggle(),
                  const SizedBox(height: 16),
                  _buildImagePicker(isLargeScreen),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    maxLength: 100,
                    decoration: _buildInputDecoration('Event Name', prefixIcon: Icons.emoji_events),
                    style: const TextStyle(fontSize: 16),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please enter event name';
                      if (value.length > 100) return 'Name must be 100 characters or less';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: _buildInputDecoration('Category'),
                    style: const TextStyle(fontSize: 16),
                    icon: Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                    items: _categories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category, style: const TextStyle(color: Colors.black)),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedCategory = value),
                    validator: (value) => value == null ? 'Please select a category' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildDateTimePickers(isLargeScreen),
                  const SizedBox(height: 16),
                  Autocomplete<Venue>( 
                    optionsBuilder: (TextEditingValue textEditingValue) {
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
                    maxLength: 1000,
                    decoration: _buildInputDecoration('Description'),
                    maxLines: 6,
                    style: const TextStyle(fontSize: 16),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Please enter description';
                      if (value.length > 1000) return 'Description must be 1000 characters or less';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Ticket Types',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ..._ticketTypes.asMap().entries.map((entry) {
                    return _buildTicketTypeField(entry.key, isLargeScreen);
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
                    width: isLargeScreen ? 400 : double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitEvent,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.orange[800],
                      ),
                      child: _isLoading 
                          ? const CircularProgressIndicator()
                          : const Text(
                              'Post Event',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}