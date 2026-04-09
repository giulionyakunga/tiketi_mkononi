import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/models/bus.dart';

class BusesPage extends StatefulWidget {
  final int userId;
  final int officeId;
  final String officeName;
  final String companyName;
  final String userName;
  final String userPhoneNumber;
  final int companyId;
  final String role;

  const BusesPage({
    super.key,
    required this.userId,
    required this.officeId,
    required this.officeName,
    required this.companyName,
    required this.userName,
    required this.userPhoneNumber,
    required this.companyId,
    required this.role,
  });

  @override
  State<BusesPage> createState() => _BusesPageState();
}

class _BusesPageState extends State<BusesPage> {
  bool _isLoading = true;
  String? _error;
  List<Bus> _buses = [];
  Bus? _selectedBus;
  bool _showDetails = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchBarVisible = false;

  // Edit form controllers
  final _registrationController = TextEditingController();
  final _nameController = TextEditingController();
  final _numberOfSeatRowsController = TextEditingController();
  final _seatsPerRowController = TextEditingController();
  final _typeController = TextEditingController();
  bool _isEditing = false;
  Bus? _editingBus;

  @override
  void initState() {
    super.initState();
    _fetchBuses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _registrationController.dispose();
    _nameController.dispose();
    _numberOfSeatRowsController.dispose();
    _seatsPerRowController.dispose();
    _typeController.dispose();
    super.dispose();
  }

  Future<void> _fetchBuses({bool useDNS = true}) async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
        _showDetails = false;
        _selectedBus = null;
      });

      final uri = useDNS 
          ? Uri.parse('$backend_url/api/buses/${widget.companyId}')
          : Uri.parse('${backend_url_with_fallback_ip}buses/${widget.companyId}');

      debugPrint('Fetching buses from: $uri');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        final newItems = jsonList.map((json) => Bus.fromJson(json)).toList();
        
        setState(() {
          _buses = newItems;
        });
        
        debugPrint('Loaded ${newItems.length} buses');
      } else {
        _error = 'Failed to load buses (${response.statusCode})';
        debugPrint(_error);
      }
    } on SocketException catch (e) {
      if ((e.osError?.errorCode == 7 || e.osError?.errorCode == 11001) && useDNS) {
        await _fetchBuses(useDNS: false);
        return;
      }
      _error = 'Network error. Please check your connection.';
    } catch (e) {
      _error = 'Unexpected error occurred: $e';
      debugPrint('Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteBus(int busId) async {
    try {
      final uri = Uri.parse('$backend_url/api/buses/$busId');
      final response = await http.delete(uri);
      
      if (response.statusCode == 200) {
        _fetchBuses();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bus deleted successfully')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete bus')),
          );
        }
      }
    } catch (e) {
      debugPrint('Delete error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error deleting bus')),
        );
      }
    }
  }

  Future<void> _updateBus(Bus bus) async {
    try {
      final uri = Uri.parse('$backend_url/api/buses/${bus.id}');
      final response = await http.put(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'registration_number': _registrationController.text,
          'name': _nameController.text,
          'number_of_seat_rows': int.tryParse(_numberOfSeatRowsController.text) ?? 0,
          'seats_per_row': int.tryParse(_seatsPerRowController.text) ?? 0,
          'type': _typeController.text,
          'company_id': widget.companyId,
        }),
      );
      
      if (response.statusCode == 200) {
        _fetchBuses();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bus updated successfully')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update bus')),
          );
        }
      }
    } catch (e) {
      debugPrint('Update error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error updating bus')),
        );
      }
    }
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
  }

  Widget _buildSearchBar(bool isDarkMode, bool isLargeScreen) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: 8,
        horizontal: isLargeScreen ? 200 : 16,
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
        ),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search bus by name or registration...',
            hintStyle: TextStyle(
              fontSize: isLargeScreen ? 16 : 14,
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
            border: InputBorder.none,
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 12, right: 6),
              child: Icon(
                Icons.search_rounded,
                size: isLargeScreen ? 24 : 20,
                color: isDarkMode ? Colors.white70 : Colors.teal[800],
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
              vertical: isLargeScreen ? 14 : 10,
              horizontal: 16,
            ),
          ),
          style: TextStyle(
            fontSize: isLargeScreen ? 16 : 14,
            color: colorScheme.onSurface,
          ),
          onChanged: (value) => _onSearchChanged(),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }

  bool _isLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.width > 768;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Company Buses',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 3,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchBuses,
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _fetchBuses,
            color: Colors.teal,
            child: _buildBody(),
          ),
          if (_showDetails && _selectedBus != null) ...[
            ModalBarrier(
              dismissible: true,
              onDismiss: () {
                setState(() {
                  _showDetails = false;
                  _selectedBus = null;
                });
              },
              color: Colors.black.withOpacity(0.2),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: _buildDetailsPanel(),
            ),
          ],
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: "addBtn",
            backgroundColor: Colors.teal,
            tooltip: "Add Bus",
            onPressed: () {
              // Navigate to add bus page
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Add bus functionality coming soon')),
              );
            },
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              "Add",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: "searchBtn",
            backgroundColor: Colors.grey.shade800,
            mini: true,
            tooltip: "Search",
            onPressed: () {
              setState(() {
                _isSearchBarVisible = !_isSearchBarVisible;
                _searchController.clear();
                _onSearchChanged();
              });
            },
            child: const Icon(Icons.search, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final isLargeScreen = _isLargeScreen(context);
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline,
                  size: 60,
                  color: Colors.red.shade300,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _fetchBuses,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_buses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.directions_bus,
                size: 80,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Buses Yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Buses you add will appear here',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    var filteredBuses = _buses.where((bus) {
      if (_searchQuery.isEmpty) return true;
      return bus.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          bus.registrationNumber.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Column(
      children: [
        if (_isSearchBarVisible) _buildSearchBar(isDarkMode, isLargeScreen),
        
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.teal[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.teal.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Text(
                '${filteredBuses.length}',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.teal[700],
                  fontSize: 28,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                filteredBuses.length > 1 ? 'Buses' : 'Bus',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.teal[600],
                  fontWeight: FontWeight.w500,
                  fontSize: 26,
                ),
              ),
            ],
          ),
        ),
        
        isLargeScreen
            ? Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 420,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: ListView.builder(
                        itemCount: filteredBuses.length,
                        itemBuilder: (context, index) {
                          final bus = filteredBuses[index];
                          final isSelected = _selectedBus == bus;
                          return _buildBusCard(bus, isSelected, isLargeScreen);
                        },
                      ),
                    ),
                    Expanded(
                      child: _selectedBus == null
                          ? Center(
                              child: Text(
                                "Select a bus to view details",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            )
                          : Padding(
                              padding: const EdgeInsets.all(24),
                              child: _buildBusDetails(_selectedBus!),
                            ),
                    ),
                  ],
                ),
              )
            : Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredBuses.length,
                  itemBuilder: (context, index) {
                    final bus = filteredBuses[index];
                    final isSelected = _selectedBus == bus;
                    return _buildBusCard(bus, isSelected, isLargeScreen);
                  },
                ),
              ),
      ],
    );
  }

  Widget _buildBusCard(Bus bus, bool isSelected, bool isLargeScreen) {
    return Card(
      elevation: isSelected ? 6 : 4,
      margin: const EdgeInsets.only(bottom: 12),
      shadowColor: isSelected ? Colors.teal.withOpacity(0.3) : Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: isSelected
            ? BorderSide(color: Colors.teal.shade400, width: 2.5)
            : BorderSide.none,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.white,
          child: InkWell(
            onTap: () {
              setState(() {
                _selectedBus = bus;
                _showDetails = true;
              });
            },
            splashColor: Colors.teal.withOpacity(0.1),
            highlightColor: Colors.teal.withOpacity(0.05),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.directions_bus,
                          color: Colors.teal.shade700,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bus.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A1A),
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              bus.registrationNumber,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.people, size: 18, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Text(
                          "Capacity: ${bus.numberOfSeatRows * bus.seatsPerRow} seats",
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [Colors.teal.shade50, Colors.teal.shade100],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.directions_bus, size: 18, color: Colors.teal.shade700),
                        const SizedBox(width: 8),
                        Text(
                          bus.type,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Colors.teal.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isEditing && _editingBus?.id == bus.id) ...[
                    const SizedBox(height: 24),
                    Divider(height: 1, color: Colors.grey.shade200),
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _buildTextField("Registration Number", _registrationController),
                            const SizedBox(height: 12),
                            _buildTextField("Bus Name", _nameController),
                            const SizedBox(height: 12),
                            _buildTextField("Number of Seat Rows", _numberOfSeatRowsController, isNumber: true),
                            const SizedBox(height: 12),
                            _buildTextField("Seats per Row", _seatsPerRowController, isNumber: true),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      setState(() {
                                        bus.registrationNumber = _registrationController.text;
                                        bus.name = _nameController.text;
                                        bus.numberOfSeatRows = int.tryParse(_numberOfSeatRowsController.text) ?? 0;
                                        bus.seatsPerRow = int.tryParse(_seatsPerRowController.text) ?? 0;
                                        bus.type = _typeController.text;
                                        _isEditing = false;
                                        _editingBus = null;
                                      });
                                      _updateBus(bus);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.teal.shade600,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: const Text("Save Changes"),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      setState(() {
                                        _isEditing = false;
                                        _editingBus = null;
                                      });
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.grey.shade700,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      side: BorderSide(color: Colors.grey.shade300),
                                    ),
                                    child: const Text("Cancel"),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.edit_outlined,
                            color: Colors.teal.shade700,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              _isEditing = true;
                              _editingBus = bus;
                              _registrationController.text = bus.registrationNumber;
                              _nameController.text = bus.name;
                              _typeController.text = bus.type;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: Colors.red.shade600,
                            size: 20,
                          ),
                          onPressed: () async {
                            final confirm = await showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text("Delete Bus"),
                                content: const Text(
                                  "Are you sure you want to delete this bus?"
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text("Cancel"),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text("Delete"),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              _deleteBus(bus.id);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBusDetails(Bus bus) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.directions_bus, color: Colors.teal.shade700),
                const SizedBox(width: 8),
                Text(
                  'Bus Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade700,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.directions_bus, color: Colors.teal, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bus.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        bus.registrationNumber,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildDetailSection(
              title: 'Specifications',
              icon: Icons.settings,
              children: [
                _buildDetailRow('Bus Type', bus.type),
                _buildDetailRow('Capacity', '${bus.numberOfSeatRows * bus.seatsPerRow} seats'),
                _buildDetailRow('Company', widget.companyName),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsPanel() {
    final bus = _selectedBus;
    if (bus == null) return const SizedBox();

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.directions_bus, color: Colors.teal.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bus Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailSection(
                    title: 'Bus Information',
                    icon: Icons.directions_bus,
                    children: [
                      _buildDetailRow('Name', bus.name),
                      _buildDetailRow('Registration Number', bus.registrationNumber),
                      _buildDetailRow('Type', bus.type),
                      _buildDetailRow('Capacity', '${bus.numberOfSeatRows * bus.seatsPerRow} seats'),
                      _buildDetailRow('Company', widget.companyName),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(icon, size: 18, color: Colors.teal.shade700),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade700,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 0),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    final displayValue = value ?? 'N/A';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              displayValue,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}