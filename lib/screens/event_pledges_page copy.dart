import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:tiketi_mkononi/models/event.dart';
import 'package:tiketi_mkononi/models/pledge.dart';
import 'package:tiketi_mkononi/screens/pledge_send_page.dart';
import 'package:url_launcher/url_launcher.dart';

class EventPledgesPage extends StatefulWidget {
  final Event event;

  const EventPledgesPage({super.key, required this.event});

  @override
  State<EventPledgesPage> createState() => _EventPledgesPageState();
}

class _EventPledgesPageState extends State<EventPledgesPage> {
  List<Pledge> pledgesList = [];
  List<Pledge> pledgesList2 = [];
  bool _isSearchBarVisible = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
    pledgesList = _filterPledges(pledgesList2);
  }

  List<Pledge> _filterPledges(List<Pledge> pledges) {
    if (_searchQuery.isEmpty) return pledges;
    
    return pledges.where((pledge) => 
        pledge.fullName.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  Future<void> loadExcelDocument() async {
    try {
      // Pick Excel file from device
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result == null) return;

      // Read the file
      final file = File(result.files.single.path!);
      final bytes = await file.readAsBytes();
      final excel = Excel.decodeBytes(bytes);

      // Get first sheet
      final sheet = excel.tables[excel.tables.keys.first];
      if (sheet == null) {
        _showSnackBar('No sheet found in the Excel file');
        return;
      }

      List<Pledge> pledges = [];
      
      // Find column indices for Full_Name and Phone_Number
      int nameColIndex = -1;
      int phoneColIndex = -1;
      
      // Check first row for headers
      if (sheet.rows.isNotEmpty) {
        final headerRow = sheet.rows.first;
        for (int i = 0; i < headerRow.length; i++) {
          final cellValue = headerRow[i]?.value?.toString().toLowerCase() ?? '';
          if (cellValue.contains('full_name') || cellValue == 'full name' || cellValue == 'name') {
            nameColIndex = i;
          } else if (cellValue.contains('phone_number') || cellValue == 'phone number' || cellValue == 'phone') {
            phoneColIndex = i;
          }
        }
      }

      // If headers not found, assume first column is name, second is phone
      if (nameColIndex == -1) nameColIndex = 0;
      if (phoneColIndex == -1) phoneColIndex = 1;

      // Parse data rows (skip header row)
      for (int i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        
        String fullName = '';
        String phoneNumber = '';
        
        if (nameColIndex < row.length) {
          fullName = row[nameColIndex]?.value?.toString() ?? '';
        }
        
        if (phoneColIndex < row.length) {
          phoneNumber = row[phoneColIndex]?.value?.toString() ?? '';
        }
        
        if (fullName.isNotEmpty && phoneNumber.isNotEmpty) {
          pledges.add(Pledge(
            fullName: fullName,
            phoneNumber: phoneNumber, id: 0, eventId: widget.event.id, amount: 0.0, createdAt: DateTime.now(), updatedAt: DateTime.now(),
          ));
        }
      }

      if (pledges.isEmpty) {
        _showSnackBar('No valid pledges found in the Excel file');
        return;
      }

      setState(() {
        pledgesList = pledges;
        pledgesList2 = List.from(pledges);
      });
      
      _showSnackBar('Loaded ${pledges.length} pledges successfully');
      
    } catch (e) {
      _showSnackBar('Error loading Excel file: $e');
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

  Widget _buildSearchBar(bool isDarkMode, bool isLargeScreen) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: 8,
        horizontal: isLargeScreen ? 200 : 0,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDarkMode
              ? colorScheme.surfaceContainerHighest.withOpacity(0.8)
              : colorScheme.surface.withOpacity(0.9),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.1),
              blurRadius: 12,
              spreadRadius: 1,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(
            color: isDarkMode
                ? colorScheme.outline.withOpacity(0.3)
                : colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search pledges...',
            hintStyle: TextStyle(
              fontSize: isLargeScreen ? 16 : 14,
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
            border: InputBorder.none,
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 16, right: 8),
              child: Icon(
                Icons.search_rounded,
                size: isLargeScreen ? 24 : 20,
                color: isDarkMode ? Colors.white70 : Colors.orange[800],
              ),
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        size: isLargeScreen ? 24 : 20,
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged();
                        FocusScope.of(context).unfocus();
                      },
                    ),
                  )
                : null,
            contentPadding: EdgeInsets.symmetric(
              vertical: isLargeScreen ? 18 : 14,
              horizontal: 16,
            ),
            isDense: true,
          ),
          style: TextStyle(
            fontSize: isLargeScreen ? 16 : 14,
            color: colorScheme.onSurface,
          ),
          cursorColor: colorScheme.primary,
          cursorWidth: 1.5,
          cursorHeight: isLargeScreen ? 20 : 18,
          onChanged: (value) => _onSearchChanged(),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(bool isDarkMode, bool isLargeScreen) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Pledges'),
        backgroundColor: const Color.fromARGB(255, 240, 244, 247),
      ),
      body: pledgesList.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 48,
                    color: colorScheme.primary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No pledges loaded',
                    style: TextStyle(
                      fontSize: 18,
                      color: colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the upload button to load an Excel file',
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: loadExcelDocument,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Load Excel File'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[800],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: pledgesList.length,
              itemBuilder: (context, index) {
                return PledgeCard(pledge: pledgesList[index], event: widget.event); 
              },
            ),
    );
  }

  Widget _buildDesktopLayout(bool isDarkMode, bool isLargeScreen) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: _isSearchBarVisible 
            ? _buildSearchBar(isDarkMode, isLargeScreen) 
            : const Text('Request Pledges'),
        backgroundColor: const Color.fromARGB(255, 240, 244, 247),
        actions: [
          IconButton(
            icon: Icon(
              Icons.search,
              color: Colors.orange[800],
            ),
            onPressed: () {
              setState(() {
                _isSearchBarVisible = !_isSearchBarVisible;
                _searchController.clear();
                _onSearchChanged();
              });
            },
          ),
          IconButton(
            icon: Icon(
              Icons.upload_file,
              color: Colors.orange[800],
            ),
            onPressed: loadExcelDocument,
            tooltip: 'Load Excel File',
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: pledgesList.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 48,
                    color: colorScheme.primary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No pledges loaded',
                    style: TextStyle(
                      fontSize: 18,
                      color: colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Click the upload button to load an Excel file',
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: loadExcelDocument,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Load Excel File'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[800],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pledges List',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: pledgesList.length,
                      itemBuilder: (context, index) {
                        return PledgeCard(pledge: pledgesList[index], event: widget.event);
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final isLargeScreen = MediaQuery.of(context).size.width > 768;
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    return isDesktop 
        ? _buildDesktopLayout(isDarkMode, isLargeScreen) 
        : _buildMobileLayout(isDarkMode, isLargeScreen);
  }
}

class PledgeCard extends StatelessWidget {
  final Pledge pledge;
  final Event event;

  const PledgeCard({
    super.key,
    required this.pledge,
    required this.event,
  });

  Future<void> _launchPhoneCall(BuildContext context, String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch phone app')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.orange.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      margin: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.orange[50]!,
              Colors.orange[50]!.withOpacity(0.7),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.person,
                      color: Colors.orange[800],
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      pledge.fullName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _launchPhoneCall(context, pledge.phoneNumber),
                child: Row(
                  children: [
                    Icon(
                      Icons.phone,
                      size: 16,
                      color: Colors.orange[700],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Phone: ',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        pledge.phoneNumber,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue[700],
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Send Pledge Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    debugPrint("PledgeSendPage : ${event.id} ${event.name}");
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PledgeSendPage(
                          pledge: pledge,
                          event: event,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.send, size: 20),
                  label: const Text('Send Pledge Request'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
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