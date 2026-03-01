import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/screens/add_office_page.dart';
import 'package:tiketi_mkononi/screens/add_shop_page.dart';

class OfficesPage extends StatefulWidget {
  final int userId;

  const OfficesPage({super.key, required this.userId});

  @override
  State<OfficesPage> createState() => _OfficesPageState();
}

class _OfficesPageState extends State<OfficesPage> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _offices = [];

  @override
  void initState() {
    super.initState();
    _fetchOffices();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cargo Offices'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 3,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchOffices,
        child: _buildBody(),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.indigo,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddOfficePage(userId: widget.userId,),
          ));
        }, // future: add office
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
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
            Icon(Icons.location_city, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No offices registered yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Add offices to start managing cargo locations'),
          ],
        ),
      );
    }

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
              child: const Icon(Icons.apartment, color: Colors.indigo),
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
                const SizedBox(height: 4),
                Text(
                  'Phone: ${office['phone'] ?? 'N/A'}',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Navigate to office details page
            },
          ),
        );
      },
    );
  }
}