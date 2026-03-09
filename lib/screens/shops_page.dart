import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tiketi_mkononi/screens/add_shop_attendant_page.dart';
import 'package:tiketi_mkononi/screens/add_shop_page.dart';
import 'package:tiketi_mkononi/screens/sales_book_page.dart';
import '../env.dart';

class ShopsPage extends StatefulWidget {
  final int userId;

  const ShopsPage({super.key, required this.userId});

  @override
  State<ShopsPage> createState() => _ShopsPageState();
}

class _ShopsPageState extends State<ShopsPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _shops = [];

  @override
  void initState() {
    super.initState();
    _fetchShops();
  }

  Future<void> _fetchShops() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final uri = Uri.parse('${backend_url}api/shops/${widget.userId}');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        setState(() {
          _shops = List<Map<String, dynamic>>.from(decoded);
        });
      } else {
        _error = 'Failed to load shops';
      }
    } catch (e) {
      _error = 'Network error. Please try again.';
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Shops'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchShops,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _errorState()
                : _shops.isEmpty
                    ? _emptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _shops.length,
                        itemBuilder: (_, index) {
                          final shop = _shops[index];
                          return _shopCard(shop);
                        },
                      ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.teal,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddShopPage(userId: widget.userId,),
          ));
        }, // future: add office
        child: const Icon(
          Icons.add,
          color: Colors.white
        ),
      ),
    );
  }

  Widget _shopCard(Map<String, dynamic> shop) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SalesBookPage(userId: widget.userId, shopId: shop['id']), 
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.indigo.withOpacity(0.1),
                    child: const Icon(
                      Icons.store,
                      color: Colors.teal,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shop['name'] ?? 'Unnamed Shop',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          shop['location'] ?? 'Location not specified',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _chip(
                              icon: Icons.people,
                              label: '${shop['wingas'] ?? 0} Wingas',
                            ),
                            const SizedBox(width: 10),
                            _chip(
                              icon: Icons.trending_up,
                              label: 'Sales: ${shop['total_sales'] ?? 0}',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),

             Padding(
                padding: const EdgeInsets.only(
                  top: 0,
                  left: 16,
                  right: 16,
                  bottom: 4,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: () {
                        // your action here
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddShopAttendantPage(
                              userId: widget.userId,
                              shopId: shop['id'],      // pass what you need
                            ),
                          ),
                        );
                      },
                      child: const Icon(
                        Icons.edit,
                        size: 14,
                        color: Colors.grey,
                      ),
                    )
                  ],
                )
              )
          ]
        )
      ),
    );
  }

  Widget _chip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.indigo.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.indigo),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return ListView(
      children: const [
        SizedBox(height: 120),
        Icon(Icons.store_mall_directory, size: 80, color: Colors.grey),
        SizedBox(height: 16),
        Center(
          child: Text(
            'No shops found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(height: 8),
        Center(
          child: Text(
            'Shops you own will appear here',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ],
    );
  }

  Widget _errorState() {
    return ListView(
      children: [
        const SizedBox(height: 120),
        const Icon(Icons.error_outline, size: 80, color: Colors.redAccent),
        const SizedBox(height: 16),
        Center(
          child: Text(
            _error!,
            style: const TextStyle(fontSize: 16),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: ElevatedButton.icon(
            onPressed: _fetchShops,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ),
      ],
    );
  }
}
