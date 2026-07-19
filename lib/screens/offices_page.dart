import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/l10n/app_localizations.dart';
import 'package:tiketi_mkononi/screens/add_bus_route_page.dart';
import 'package:tiketi_mkononi/screens/add_office_page.dart';
import 'package:tiketi_mkononi/screens/bus_routes_page.dart';
import 'package:tiketi_mkononi/screens/buses_page.dart';
import 'package:tiketi_mkononi/screens/consignments_page.dart';
import 'package:tiketi_mkononi/screens/edit_company_page.dart';
import 'package:tiketi_mkononi/screens/edit_office_page.dart';
import 'package:tiketi_mkononi/services/storage_service.dart';

class OfficesPage extends StatefulWidget {
  final int userId;
  final int companyId;
  String companyName;
  final String userName;
  final String userPhoneNumber;
  final String role;

  OfficesPage({super.key, required this.userId, required this.companyId, required this.companyName, required this.userName, required this.userPhoneNumber, required this.role});

  @override
  State<OfficesPage> createState() => _OfficesPageState();
}

class _OfficesPageState extends State<OfficesPage> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _offices = [];
  late final StorageService _storageService;

  @override
  void initState() {
    super.initState();
    _fetchOffices();
     _initializeServices();
  }

  Future<void> _initializeServices() async {
    final prefs = await SharedPreferences.getInstance();
    _storageService = StorageService(prefs);
  }

  Future<void> _fetchOffices({bool useDNS = true}) async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final uri = useDNS
      ? Uri.parse('${backend_url}api/offices/${widget.userId}')
      : Uri.parse('${backend_url_with_fallback_ip}offices/${widget.userId}');

      final response = await http.get(uri);

      debugPrint('URL : ${backend_url}api/offices/${widget.userId}');

      if (response.statusCode == 200) {
        debugPrint(response.body);

        setState(() {
          _offices = jsonDecode(response.body);
        });
      } else {
        _error = 'Failed to load offices (${response.statusCode})';
        debugPrint(_error);
      }
    } on SocketException catch (e) {
      if ((e.osError?.errorCode == 7 || e.osError?.errorCode == 11001) && useDNS) {
        await _fetchOffices(useDNS: false);
        return;
      }
      _error = 'Network error. Please check your connection.';
    } catch (e) {
      _error = 'Unexpected error occurred.';
    } finally {
      setState(() => _isLoading = false);
    }
  }

  PopupMenuItem<String> _buildMenuItem({
    required IconData icon,
    required String text,
    required String value,
  }) {
    return PopupMenuItem<String>(
      value: value,
      height: 44,
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: Colors.grey.shade800,
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.myOffices),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 3,
        actions: [
          IconButton(
            icon: const Icon(Icons.local_shipping),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ConsignmentsPage(userId: widget.userId, officeId: 0, officeName: '', companyId: widget.companyId, companyName: widget.companyName, userName: widget.userName, userPhoneNumber: widget.userPhoneNumber, role: widget.role),
                ),
              );
            },
          ),

          PopupMenuButton<String>(
            padding: EdgeInsets.zero,
            tooltip: 'More Options',
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            icon: Icon(
              Icons.more_vert,
              color: Colors.white,
              size: 22,
            ),
            onSelected: (value) async {
              if (value == 'company_name') {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditCompanyPage(userId: widget.userId, companyId: widget.companyId, companyName: widget.companyName),
                  ),
                );

                var profile = _storageService.getUserProfile();
                widget.companyName = profile!.companyName;

              } if (value == 'bus_routes') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BusRoutesPage(userId: widget.userId, officeId: 0, officeName: '', companyId: widget.companyId, companyName: widget.companyName, userName: widget.userName, userPhoneNumber: widget.userPhoneNumber, role: widget.role),
                  ),
                );
              } else if (value == 'company_buses') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BusesPage(userId: widget.userId, officeId: 0, officeName: '', companyId: widget.companyId, companyName: widget.companyName, userName: widget.userName, userPhoneNumber: widget.userPhoneNumber, role: widget.role),
                  ),
                );
              } else if (value == 'exit') {
                Navigator.pop(context);
              }
            },
            itemBuilder: (context) => [
    
              if((widget.role == "transporter") || (widget.role == "cargo_transporter"))
              _buildMenuItem(
                icon: Icons.location_city,
                text: widget.companyName,
                value: 'company_name',
              ),
              if((widget.role == "transporter") || (widget.role == "cargo_transporter"))
              const PopupMenuDivider(),
              if(widget.role == "transporter")
              _buildMenuItem(
                icon: Icons.directions_bus,
                text: "Bus Routes",
                value: 'bus_routes',
              ),
              if(widget.role == "transporter")
              const PopupMenuDivider(),
              if(widget.role == "transporter")
              _buildMenuItem(
                icon: Icons.directions_bus,
                text: "Company Buses",
                value: 'company_buses',
              ),
              if(widget.role == "transporter")
              const PopupMenuDivider(),
              _buildMenuItem(
                icon: Icons.exit_to_app,
                text: 'Exit',
                value: 'exit',
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchOffices,
        child: _buildBody(),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.teal,
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddOfficePage(userId: widget.userId, companyId: widget.companyId),
            )
          );
          
          _fetchOffices();
        }, // future: add office
        child: const Icon(
          Icons.add,
          color: Colors.white
        ),
      ),
    );
  }

  Widget _buildBody() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;

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
              const Icon(Icons.error_outline, size: 60, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchOffices,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_offices.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_city, size: 80, color: Colors.teal),
            SizedBox(height: 16),
            Text(
              'No offices registered yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Add offices to start managing transport services'),
          ],
        ),
      );
    }

    if(!isWideScreen) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _offices.length,
        itemBuilder: (context, index) {
          final office = _offices[index];
          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.indigo.withOpacity(0.1),
                child: const Icon(Icons.apartment, color: Colors.teal),
              ),
              title: Text(
                office['name'] ?? 'Office',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(office['location'] ?? 'Unknown location'),
                ],
              ),

              // 👇 two actions: edit + navigate
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.edit,
                      size: 12,
                      color: Colors.teal
                    ),
                    tooltip: 'Edit office',
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditOfficePage(
                            userId: widget.userId,
                            officeId: office['id'],
                            companyId: office['company_id'], 
                            officeName: office['name'], 
                            officeLocation: office['location'],
                          ),
                        ),
                      );
                      _fetchOffices();
                    },
                  ),
                ],
              ),

              // 👇 card tap remains unchanged
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ConsignmentsPage(
                      userId: widget.userId,
                      officeId: office['id'],
                      officeName: office['name'],
                      companyId: office['company_id'],
                      companyName: widget.companyName,
                      role: widget.role, 
                      userName: widget.userName, 
                      userPhoneNumber: widget.userPhoneNumber,
                    ),
                  ),
                );
              },
            ),
          );
        },
      );
    } else {
      // Responsive grid layout for offices
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            int crossAxisCount;
            
            // Determine number of columns based on screen width
            if (constraints.maxWidth >= 1200) {
              crossAxisCount = 4;
            } else if (constraints.maxWidth >= 800) {
              crossAxisCount = 3;
            } else if (constraints.maxWidth >= 600) {
              crossAxisCount = 2;
            } else {
              crossAxisCount = 1;
            }

            return GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.0, // Square cards
              ),
              padding: const EdgeInsets.all(8),
              itemCount: _offices.length,
              itemBuilder: (context, index) {
                final office = _offices[index];
                return _buildOfficeCard(office);
              },
            );
          },
        ),
      );
    }
  }

  Widget _buildOfficeCard(dynamic office) {
  return Card(
    elevation: 1,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    ),
    child: InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ConsignmentsPage(
              userId: widget.userId,
              officeId: office['id'],
              officeName: office['name'],
              companyId: office['company_id'],
              companyName: widget.companyName,
              role: widget.role,
              userName: widget.userName,
              userPhoneNumber: widget.userPhoneNumber,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        children: [
          // Main content
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Office Icon - even smaller
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.apartment,
                    color: Colors.teal.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 6),
                // Office Name - smaller font
                Text(
                  office['name'] ?? 'Office',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                // Office Location - more compact
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.location_on,
                      color: Colors.grey[500],
                      size: 12,
                    ),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(
                        office['location'] ?? 'Unknown location',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Edit Button - positioned in top-right corner with smaller size
          Positioned(
            top: 2,
            right: 2,
            child: IconButton(
              icon: Icon(
                Icons.edit,
                size: 14,
                color: Colors.grey[400],
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 24,
                minHeight: 24,
              ),
              tooltip: 'Edit office',
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditOfficePage(
                      userId: widget.userId,
                      officeId: office['id'],
                      companyId: office['company_id'],
                      officeName: office['name'],
                      officeLocation: office['location'],
                    ),
                  ),
                );
                _fetchOffices();
              },
            ),
          ),
        ],
      ),
    ),
  );
}




}