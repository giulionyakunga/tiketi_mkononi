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
  bool isCustom;

  TicketType({
    required this.name,
    required this.price,
    required this.numberOfTickets,
    required this.isCustom,
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
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String? _selectedCategory;
  XFile? _eventImage;
  String? fileType;
  bool _isLoading = false; // Track if request is in progress
  late final StorageService _storageService;

  // Ticket type controllers
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

  @override
  void initState() {
    super.initState();
    _initializeServices();
    // Add default ticket type
    _addTicketType();
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
    }
  }

  void _addTicketType() {
    setState(() {
      _ticketTypes.add(TicketType(name: 'Regular', price: 0, numberOfTickets: 0, isCustom: false));
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



        // Get file extension and MIME type
        final fileExtension = path.extension(image.path).toLowerCase(); // e.g., '.png', '.jpg'
        final mimeType = lookupMimeType(image.path); // e.g., 'image/png', 'image/jpeg'

        // Validate the file type
        if (mimeType == null || (!mimeType.startsWith('image/'))) {
          print('Invalid file type. Please select a valid image.');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid file type. Please select a valid image.')),
          );
          return;
        }

        if (fileExtension != '.png' && fileExtension != '.jpg' && fileExtension != '.jpeg') {
          print('Unsupported image format. Only PNG and JPEG are allowed.');
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

      int index_2 = 0;
      for (var ticket_2 in _ticketTypes) {
        if(index != index_2) {
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

    return true;
  }

  // Function to scroll to the first error field
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
  
  Future<void> _submitEvent() async {
    // Validate all form fields
    if (!_formKey.currentState!.validate()) {
      _scrollToFirstError(); // Scroll to the first error field
      return;
    }

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select event date')),
      );
      return;
    }

    if (_selectedTime == null) {
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
      // Scroll to the image picker
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

    // Trim text inputs before sending
    String eventName = _nameController.text.trim();
    String eventVenue = _venueController.text.trim();
    String eventDescription = _descriptionController.text.trim();

    for (var ticket in _ticketTypes) {
      ticket.name = ticket.name.trim();
    }

    final Map<String, dynamic> requestBody = {
        'user_id': userId,
        'name': eventName,
        'category': _selectedCategory,
        'date': _selectedDate?.toIso8601String(),
        'time': '${_selectedTime!.hour}:${_selectedTime!.minute}',
        'venue': eventVenue,
        'description': eventDescription,
        'ticket_types': _ticketTypes.map((ticket) => {
          'name': ticket.name,
          'price': ticket.price,
          'number_of_tickets': ticket.numberOfTickets,
          'is_custom': ticket.isCustom,
        }).toList(),
        'file_type': fileType,
        'event_image': base64Encode(await File(_eventImage!.path).readAsBytes()),
    };

    try {
      setState(() {
        _isLoading = true; // Disable button & show loader
      });

      String url = '${backend_url}api/post_event';

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        if(response.body == "Event not posted!" ){
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.body)),
          );
        }else if(response.body == "Event posted successfully!" ){
          widget.refreshMethod();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.body)),
          );
          Navigator.pop(context);
        }else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.body)),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request not successful, Status code: ${response.statusCode}')),
        );
      }
    } catch (e) {
      // Handle network errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      ); 
    } finally {
      setState(() {
        _isLoading = false; // Re-enable button after request completes
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _venueController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Widget _buildTicketTypeField(int index) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: _ticketTypes[index].isCustom
                      ? TextFormField(
                          initialValue: _ticketTypes[index].name,
                          decoration: InputDecoration(
                            labelText: 'Custom Ticket Type',
                            border: const OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.grey[200],
                          ),
                          style: const TextStyle(fontSize: 11.0), // Set font size here
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
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Colors.blue, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.grey[200],
                            contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8), // Reduced padding
                          ),
                          items: _predefinedTicketTypes
                              .map((type) => DropdownMenuItem(
                                    value: type,
                                    child: Text(
                                      type,
                                      style: const TextStyle(fontSize: 11.0), // Set font size for dropdown items
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
                const SizedBox(width: 2),
                Expanded(
                  child: 
                  TextFormField(
                    initialValue: _ticketTypes[index].price.toString(),
                    decoration: InputDecoration(
                      labelText: 'Price',
                      prefixText: 'TSH ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.blue, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8), // Reduced padding
                    ),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 11.0), // Set font size here
                    onChanged: (value) {
                      setState(() {
                        _ticketTypes[index].price = double.tryParse(value) ?? 0;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: 
                  TextFormField(
                    initialValue: _ticketTypes[index].numberOfTickets.toString(),
                    decoration: InputDecoration(
                      labelText: 'Number',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.blue, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8), // Reduced padding
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly], // Allow only digits
                    style: const TextStyle(fontSize: 11.0),
                    onChanged: (value) {
                      setState(() {
                        _ticketTypes[index].numberOfTickets = int.tryParse(value) ?? 0; // Store as integer
                      });
                    },
                  ),
                  
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _ticketTypes[index].isCustom = !_ticketTypes[index].isCustom;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post Event'),
        backgroundColor: const Color.fromARGB(255, 240, 244, 247),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                key: _imagePickerKey,
                onTap: _pickImage,
                child: Container(
                  height: 200,
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
                maxLength: 100, // Added max length limit
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
                    borderSide: const BorderSide(
                      color: Colors.blue, // Highlight color when focused
                      width: 2.0,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.grey[200], // Light background color
                  contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
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
                    borderSide: const BorderSide(
                      color: Colors.blueAccent,
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
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _selectDate(context),
                      icon: const Icon(
                        Icons.calendar_today,
                        color: Colors.blueAccent,
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
                        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        side: BorderSide(
                          color: _selectedDate == null ? Colors.grey[400]! : Colors.blueAccent,
                          width: 1.5,
                        ),
                        backgroundColor: Colors.grey[200], // Light background color
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _selectTime(context),
                      icon: const Icon(
                        Icons.access_time,
                        color: Colors.blueAccent,
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
                        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        side: BorderSide(
                          color: _selectedTime == null ? Colors.grey[400]! : Colors.blueAccent,
                          width: 1.5,
                        ),
                        backgroundColor: Colors.grey[200], // Light background color
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _venueController,
                maxLength: 100, // Added max length limit
                decoration: InputDecoration(
                  labelText: 'Location/Venue',
                  labelStyle: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                  prefixIcon: Icon(
                    Icons.location_on,
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
                    borderSide: const BorderSide(
                      color: Colors.blue, // Highlight color when focused
                      width: 2.0,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.grey[200], // Light background color
                  contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
                ),
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter location or venue';
                  }
                  if (value.length > 100) {
                    return 'Location or venue must be 100 characters or less';
                  }
                  return null;
                },
              ),
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
                    borderSide: const BorderSide(
                      color: Colors.blueAccent, // Border color on focus
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
                maxLines: 3,
                style: const TextStyle(
                  fontSize: 16, // Input text font size
                  color: Colors.black, // Input text color
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter description';
                  }
                  if (value.length > 1000) {
                    return 'Description must be 500 characters or less';
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
                    'Post Event',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

