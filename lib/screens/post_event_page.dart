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
  bool _isLoading = false;
  bool _isPaidEvent = true;
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

  @override
  void initState() {
    super.initState();
    _initializeServices();
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
  
  Future<void> _submitEvent() async {
    if (!_formKey.currentState!.validate()) {
      _scrollToFirstError();
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
      'date': _selectedDate?.toIso8601String(),
      'time': '${_selectedTime!.hour}:${_selectedTime!.minute}',
      'venue': _venueController.text.trim(),
      'description': _descriptionController.text.trim(),
      'type': _isPaidEvent ? "paid" : "free",
      'ticket_types': _ticketTypes.map((ticket) => {
        'name': ticket.name.trim(),
        'price': ticket.price,
        'number_of_tickets': ticket.numberOfTickets,
        'ticket_information': ticket.ticketInformation,
        'is_custom': ticket.isCustom,
      }).toList(),
      'file_type': fileType,
      'event_image': base64Encode(await File(_eventImage!.path).readAsBytes()),
    };

    try {
      setState(() => _isLoading = true);
      final response = await http.post(
        Uri.parse('${backend_url}api/post_event'),
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
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request failed: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _venueController.dispose();
    _descriptionController.dispose();
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
          maxLength: 1000, // Added max length limit
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
            if (value == null || value.trim().isEmpty) {
              return 'Please enter ticket information';
            }
            if (value.length > 250) {
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
          maxLength: 1000, // Added max length limit
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
            if (value == null || value.trim().isEmpty) {
              return 'Please enter ticket information';
            }
            if (value.length > 250) {
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
      prefixIcon: Icon(
        prefixIcon,
        color: Colors.grey[600],
      ),
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
        Expanded(child: _buildDatePicker()),
        const SizedBox(width: 16),
        Expanded(child: _buildTimePicker()),
      ],
    );
    // return isLargeScreen
    // ? Row(
    //     children: [
    //       Expanded(child: _buildDatePicker()),
    //       const SizedBox(width: 16),
    //       Expanded(child: _buildTimePicker()),
    //     ],
    //   )
    // : Column(
    //     children: [
    //       _buildDatePicker(),
    //       const SizedBox(height: 16),
    //       _buildTimePicker(),
    //     ],
    //   );
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
                  TextFormField(
                    controller: _venueController,
                    maxLength: 100,
                    decoration: _buildInputDecoration('Location/Venue', prefixIcon: Icons.location_on),
                    style: const TextStyle(fontSize: 16),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please enter location';
                      if (value.length > 100) return 'Location must be 100 characters or less';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    maxLength: 1000,
                    decoration: _buildInputDecoration('Description'),
                    maxLines: 4,
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
                              style: TextStyle(fontSize: 18),
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